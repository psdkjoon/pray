import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pray/core/http_fetch.dart';
import 'package:pray/core/kv_store.dart';
import 'package:pray/core/real_ping.dart';
import 'package:pray/core/xray_config/xray_config.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:pray/servers/subscription_group.dart';

enum ServerSort {
  added('Oldest first'),
  newest('Newest first'),
  ping('Lowest ping'),
  name('Name'),
  protocol('Protocol');

  const ServerSort(this.label);

  final String label;
}

class ServersController extends ChangeNotifier {
  ServersController._(
    this._prefs,
    this._servers,
    this._selectedId,
    this._groups,
  );

  final KvStore _prefs;

  static ServersController load(KvStore prefs) {
    final servers = <StoredServer>[];
    try {
      final raw = prefs.getString('servers');
      if (raw != null) {
        for (final item in jsonDecode(raw) as List) {
          final map = Map<String, Object?>.from(item as Map);
          servers.add(
            StoredServer(
              id: map['id'] as String,
              proxy: ProxyServer.fromJson(
                Map<String, Object?>.from(map['proxy'] as Map),
              ),
              pinned: map['pinned'] as bool? ?? false,
              pingMs: map['ping'] as int?,
              groupId: map['group'] as String?,
            ),
          );
        }
      }
    } on Object {
      servers.clear();
    }
    final groups = <SubscriptionGroup>[];
    try {
      final raw = prefs.getString('groups');
      if (raw != null) {
        for (final item in jsonDecode(raw) as List) {
          groups.add(
            SubscriptionGroup.fromJson(Map<String, Object?>.from(item as Map)),
          );
        }
      }
    } on Object {
      groups.clear();
    }
    final known = {for (final g in groups) g.id};
    final cleaned = [
      for (final s in servers)
        if (s.groupId != null && !known.contains(s.groupId))
          StoredServer(
            id: s.id,
            proxy: s.proxy,
            pingMs: s.pingMs,
            pinned: s.pinned,
          )
        else
          s,
    ];
    final controller = ServersController._(
      prefs,
      cleaned,
      prefs.getString('selectedServer') ?? '',
      groups,
    );
    final saved = prefs.getString('serverSort');
    for (final option in ServerSort.values) {
      if (option.name == saved) controller._sort = option;
    }
    return controller;
  }

  final _random = Random();
  List<StoredServer> _servers;
  List<SubscriptionGroup> _groups;
  String _selectedId;
  bool _testing = false;
  bool _disposed = false;
  final Set<String> _updating = {};

  ServerSort _sort = ServerSort.ping;

  ServerSort get sort => _sort;

  set sort(ServerSort value) {
    if (value == _sort) return;
    _sort = value;
    _prefs.setString('serverSort', value.name);
    notifyListeners();
  }

  List<StoredServer> _ordered(Iterable<StoredServer> items) {
    final list = items.toList();
    switch (_sort) {
      case ServerSort.added:
        break;
      case ServerSort.newest:
        return list.reversed.toList();
      case ServerSort.ping:
        list.sort((a, b) {
          final x = a.pingMs;
          final y = b.pingMs;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return x.compareTo(y);
        });
      case ServerSort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case ServerSort.protocol:
        list.sort(
          (a, b) => a.proxy.protocol.name.compareTo(b.proxy.protocol.name),
        );
    }
    return list;
  }

  List<StoredServer> get servers => [
        ..._ordered(_servers.where((s) => s.pinned)),
        ..._ordered(_servers.where((s) => !s.pinned)),
      ];

  void togglePin(String id) {
    _servers = [
      for (final s in _servers)
        if (s.id == id) s.withPinned(pinned: !s.pinned) else s,
    ];
    _save();
    notifyListeners();
  }
  void removeMany(Set<String> ids) {
    _servers = [
      for (final s in _servers)
        if (!ids.contains(s.id)) s,
    ];
    if (ids.contains(_selectedId)) {
      _selectedId = _servers.isEmpty ? '' : _servers.first.id;
    }
    _save();
    notifyListeners();
  }

  void pinMany(Set<String> ids, {required bool pinned}) {
    _servers = [
      for (final s in _servers)
        if (ids.contains(s.id)) s.withPinned(pinned: pinned) else s,
    ];
    _save();
    notifyListeners();
  }

  String get selectedId => _selectedId;
  bool get testing => _testing;

  StoredServer? get selected {
    if (_servers.isEmpty) return null;
    return _servers.firstWhere(
      (server) => server.id == _selectedId,
      orElse: () => _servers.first,
    );
  }

  void _save() {
    _prefs.setString(
      'servers',
      jsonEncode([
        for (final s in _servers) {
          'id': s.id,
          'proxy': s.proxy.toJson(),
          'pinned': s.pinned,
          'ping': s.pingMs,
          'group': s.groupId,
        },
      ]),
    );
    _prefs.setString(
      'groups',
      jsonEncode([for (final g in _groups) g.toJson()]),
    );
    _prefs.setString('selectedServer', _selectedId);
  }

  void select(String id) {
    if (id == _selectedId) return;
    _selectedId = id;
    _save();
    notifyListeners();
  }

  void update(String id, ProxyServer proxy) {
    _servers = [
      for (final s in _servers)
        if (s.id == id) s.withProxy(proxy) else s,
    ];
    _save();
    notifyListeners();
  }

  void remove(String id) {
    _servers = [
      for (final s in _servers)
        if (s.id != id) s,
    ];
    if (_selectedId == id) {
      _selectedId = _servers.isEmpty ? '' : _servers.first.id;
    }
    _save();
    notifyListeners();
  }

  void addFromLink(String link) {
    final proxy = parseLink(link);
    final stored = StoredServer(id: _newId(), proxy: proxy);
    _servers = [..._servers, stored];
    _selectedId = stored.id;
    _save();
    notifyListeners();
  }

  void addProxies(List<ProxyServer> proxies) {
    if (proxies.isEmpty) return;
    final added = [
      for (final proxy in proxies) StoredServer(id: _newId(), proxy: proxy),
    ];
    _servers = [..._servers, ...added];
    if (_selectedId.isEmpty) _selectedId = added.first.id;
    _save();
    notifyListeners();
  }

  SubscriptionResult addFromSubscription(String body) {
    final result = parseSubscription(body);
    if (result.servers.isNotEmpty) {
      final added = [
        for (final proxy in result.servers)
          StoredServer(id: _newId(), proxy: proxy),
      ];
      _servers = [..._servers, ...added];
      if (_selectedId.isEmpty) _selectedId = added.first.id;
      _save();
      notifyListeners();
    }
    return result;
  }


  List<SubscriptionGroup> get groups => List.unmodifiable(_groups);

  SubscriptionGroup? groupById(String? id) {
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  bool isUpdating(String groupId) => _updating.contains(groupId);

  bool get updatingAny => _updating.isNotEmpty;

  int countIn(String? groupId) =>
      _servers.where((s) => s.groupId == groupId).length;

  Future<SubscriptionResult> addSubscription({
    required String url,
    String? name,
  }) async {
    final link = url.trim();
    final fetched = await fetchResponse(link);
    final result = parseSubscription(fetched.body);
    if (result.servers.isEmpty) {
      throw FormatException(
        result.errors.isEmpty
            ? 'No servers found'
            : result.errors.first.message,
      );
    }
    final given = name?.trim() ?? '';
    final group = SubscriptionGroup(
      id: _newId('group'),
      name: given.isNotEmpty
          ? given
          : (fetched.title ?? Uri.tryParse(link)?.host ?? link),
      url: link,
      updatedAt: DateTime.now(),
    );
    final added = [
      for (final proxy in result.servers)
        StoredServer(id: _newId(), proxy: proxy, groupId: group.id),
    ];
    _groups = [..._groups, group];
    _servers = [..._servers, ...added];
    if (_selectedId.isEmpty) _selectedId = added.first.id;
    _save();
    notifyListeners();
    return result;
  }

  Future<SubscriptionResult> updateGroup(String groupId) async {
    final group = groupById(groupId);
    if (group == null) return const SubscriptionResult(servers: [], errors: []);
    if (!_updating.add(groupId)) {
      return const SubscriptionResult(servers: [], errors: []);
    }
    notifyListeners();
    try {
      final fetched = await fetchResponse(group.url);
      final result = parseSubscription(fetched.body);
      if (_disposed) return result;
      if (result.servers.isEmpty) {
        throw FormatException(
          result.errors.isEmpty
              ? 'No servers found'
              : result.errors.first.message,
        );
      }
      _mergeGroup(groupId, result.servers);
      _groups = [
        for (final g in _groups)
          if (g.id == groupId) g.copyWith(updatedAt: DateTime.now()) else g,
      ];
      _save();
      return result;
    } finally {
      _updating.remove(groupId);
      if (!_disposed) notifyListeners();
    }
  }

  Future<int> updateAllGroups() async {
    var failed = 0;
    for (final group in List.of(_groups)) {
      try {
        await updateGroup(group.id);
      } on Object {
        failed++;
      }
    }
    return failed;
  }

  void _mergeGroup(String groupId, List<ProxyServer> fresh) {
    final old = [for (final s in _servers) if (s.groupId == groupId) s];
    final waiting = <String, List<StoredServer>>{};
    for (final server in old) {
      waiting.putIfAbsent(_identity(server.proxy), () => []).add(server);
    }
    final merged = <StoredServer>[];
    for (final proxy in fresh) {
      final candidates = waiting[_identity(proxy)];
      final match = candidates != null && candidates.isNotEmpty
          ? candidates.removeAt(0)
          : null;
      if (match != null) {
        merged.add(match.withProxy(proxy));
      } else {
        merged.add(StoredServer(id: _newId(), proxy: proxy, groupId: groupId));
      }
    }
    final firstOld = _servers.indexWhere((s) => s.groupId == groupId);
    final rest = [for (final s in _servers) if (s.groupId != groupId) s];
    final at = firstOld < 0
        ? rest.length
        : _servers.take(firstOld).where((s) => s.groupId != groupId).length;
    _servers = [...rest.take(at), ...merged, ...rest.skip(at)];
    if (!_servers.any((s) => s.id == _selectedId)) {
      _selectedId = merged.isNotEmpty
          ? merged.first.id
          : (_servers.isEmpty ? '' : _servers.first.id);
    }
  }

  static String _identity(ProxyServer p) =>
      '${p.protocol.name}|${p.address}|${p.port}|${p.id ?? ''}|${p.password ?? ''}';

  void renameGroup(String groupId, {required String name, String? url}) {
    final cleanName = name.trim();
    _groups = [
      for (final g in _groups)
        if (g.id == groupId)
          g.copyWith(
            name: cleanName.isEmpty ? g.name : cleanName,
            url: (url?.trim().isEmpty ?? true) ? g.url : url!.trim(),
          )
        else
          g,
    ];
    _save();
    notifyListeners();
  }

  void removeGroup(String groupId, {bool keepServers = false}) {
    _groups = [for (final g in _groups) if (g.id != groupId) g];
    if (keepServers) {
      _servers = [
        for (final s in _servers)
          if (s.groupId == groupId)
            StoredServer(
              id: s.id,
              proxy: s.proxy,
              pingMs: s.pingMs,
              pinned: s.pinned,
            )
          else
            s,
      ];
    } else {
      _servers = [for (final s in _servers) if (s.groupId != groupId) s];
      if (!_servers.any((s) => s.id == _selectedId)) {
        _selectedId = _servers.isEmpty ? '' : _servers.first.id;
      }
    }
    _save();
    notifyListeners();
  }

  String _newId([String kind = 'server']) {
    return '$kind-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  }

  void _applyPings(Map<String, int?> pings) {
    _servers = [
      for (final s in _servers)
        if (pings.containsKey(s.id)) s.withPing(pings[s.id]) else s,
    ];
    _save();
    notifyListeners();
  }

  Future<void> ping(String id) async {
    final server = _servers.where((s) => s.id == id).firstOrNull;
    if (server == null) return;
    await testSome({id});
  }

  Future<void> testAll({Set<String>? only}) async {
    if (_testing) return;
    _testing = true;
    notifyListeners();
    await _run([
      for (final s in _servers)
        if (only == null || only.contains(s.id)) s,
    ]);
    if (_disposed) return;
    _testing = false;
    notifyListeners();
  }

  Future<void> testSome(Set<String> ids) async {
    await _run([
      for (final s in _servers)
        if (ids.contains(s.id)) s,
    ]);
  }

  Future<void> _run(List<StoredServer> snapshot) async {
    final results = <String, int?>{};
    final clock = Stopwatch()..start();
    var lastApplied = Duration.zero;
    await RealPing.measureMany<StoredServer>(
      snapshot,
      (s) => s.proxy,
      (s, ms) {
        results[s.id] = ms;
        if (_disposed || clock.elapsed - lastApplied < _applyEvery) return;
        lastApplied = clock.elapsed;
        _applyPings({...results});
      },
      cancelled: () => _disposed,
    );
    if (_disposed) return;
    _applyPings(results);
  }

  static const _applyEvery = Duration(milliseconds: 300);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
