import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:pray/core/kv_store.dart';
import 'package:pray/core/real_ping.dart';
import 'package:xray_config/xray_config.dart';

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
  ServersController._(this._prefs, this._servers, this._selectedId);

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
            ),
          );
        }
      }
    } on Object {
      servers.clear();
    }
    final controller = ServersController._(
      prefs,
      servers,
      prefs.getString('selectedServer') ?? '',
    );
    final saved = prefs.getString('serverSort');
    for (final option in ServerSort.values) {
      if (option.name == saved) controller._sort = option;
    }
    return controller;
  }

  final _random = Random();
  List<StoredServer> _servers;
  String _selectedId;
  bool _testing = false;
  bool _disposed = false;

  ServerSort _sort = ServerSort.added;

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
        },
      ]),
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
        if (s.id == id)
          StoredServer(
            id: id,
            proxy: proxy,
            pingMs: s.pingMs,
            pinned: s.pinned,
          )
        else
          s,
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

  String _newId() {
    return 'server-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
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

  Future<void> testAll() async {
    if (_testing) return;
    _testing = true;
    notifyListeners();
    await _run([..._servers]);
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
    await RealPing.measureMany<StoredServer>(
      snapshot,
      (s) => s.proxy,
      (s, ms) {
        results[s.id] = ms;
        if (!_disposed && results.length % 4 == 0) _applyPings({...results});
      },
    );
    if (_disposed) return;
    _applyPings(results);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
