import 'dart:async';

import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:flutter/services.dart';
import 'package:pray/core/free_sources.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/ping_pill.dart';

Future<void> showFreeConfigsDialog(
  BuildContext context,
  ServersController servers,
  AppSettings settings,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: _FreeConfigsPage(servers: servers, settings: settings),
    ),
  );
}

enum _Phase { start, sources, working, summary, pick }

class _FreeConfigsPage extends StatefulWidget {
  const _FreeConfigsPage({required this.servers, required this.settings});

  final ServersController servers;
  final AppSettings settings;

  @override
  State<_FreeConfigsPage> createState() => _FreeConfigsPageState();
}

class _FreeConfigsPageState extends State<_FreeConfigsPage> {
  static const _quickCount = 10;
  static const _rowHeight = 72.0;

  late List<ConfigSource> _sources = _load();
  late final Set<String> _enabled = {for (final s in _sources) s.url};
  var _phase = _Phase.start;
  var _status = '';
  double? _progress;
  var _found = <FoundServer>[];
  final _picked = <FoundServer>{};
  var _cancelled = false;
  String? _message;
  final _scroll = ScrollController();
  var _dragAnchor = 0;
  var _dragSelects = true;
  Set<FoundServer> _dragBase = {};

  List<ConfigSource> _load() {
    final saved = widget.settings.freeSources;
    if (saved == null) return List.of(defaultConfigSources);
    return saved.map(ConfigSource.decode).whereType<ConfigSource>().toList();
  }

  void _persist() {
    widget.settings.freeSources = [for (final s in _sources) s.encode()];
  }

  @override
  void dispose() {
    _cancelled = true;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final result = await showDialog<ConfigSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: 'Name'.tr),
            ),
            TextField(
              controller: url,
              decoration: InputDecoration(
                labelText: 'Subscription URL'.tr,
                hintText: 'https://…'.tr,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final link = url.text.trim();
              if (!link.startsWith('http')) return;
              Navigator.of(dialogContext).pop(
                ConfigSource(
                  name: name.text.trim().isEmpty ? link : name.text.trim(),
                  url: link,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    name.dispose();
    url.dispose();
    if (result == null) return;
    setState(() {
      _sources = [..._sources, result];
      _enabled.add(result.url);
    });
    _persist();
  }

  Future<void> _run() async {
    final chosen = [
      for (final s in _sources)
        if (_enabled.contains(s.url)) s,
    ];
    if (chosen.isEmpty) return;
    setState(() {
      _phase = _Phase.working;
      _status = 'Looking for servers…';
      _progress = null;
      _message = null;
    });
    final found = await FreeSources.fetch(chosen);
    if (!mounted) return;
    if (found.isEmpty) {
      setState(() {
        _phase = _Phase.start;
        _message = 'Nothing could be downloaded. Check your internet '
            'connection and try again.';
      });
      return;
    }
    setState(() {
      _status = 'Checking which ones work…';
      _progress = 0;
    });
    await FreeSources.testAll(
      found,
      cancelled: () => _cancelled,
      onProgress: (done) {
        if (mounted && done % 8 == 0) {
          setState(() => _progress = done / found.length);
        }
      },
    );
    if (!mounted) return;
    final alive = found.where((s) => s.pingMs != null).toList()
      ..sort((a, b) => a.pingMs!.compareTo(b.pingMs!));
    if (alive.isEmpty) {
      setState(() {
        _phase = _Phase.start;
        _message = 'No working server was found right now. Try again later.';
      });
      return;
    }
    setState(() {
      _found = alive;
      _picked
        ..clear()
        ..addAll(alive.take(_quickCount));
      _phase = _Phase.summary;
    });
  }

  void _import() {
    final proxies = [for (final s in _picked) s.proxy];
    widget.servers.addProxies(proxies);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${proxies.length} server(s)')),
    );
  }

  int _indexAt(Offset position) {
    final raw = ((position.dy + _scroll.offset) / _rowHeight).floor();
    return raw.clamp(0, _found.length - 1);
  }

  void _applyDrag(int index) {
    final from = _dragAnchor < index ? _dragAnchor : index;
    final to = _dragAnchor < index ? index : _dragAnchor;
    final range = _found.sublist(from, to + 1);
    final next = {..._dragBase};
    if (_dragSelects) {
      next.addAll(range);
    } else {
      next.removeAll(range);
    }
    setState(() {
      _picked
        ..clear()
        ..addAll(next);
    });
  }

  void _autoScroll(Offset position, double height) {
    if (!_scroll.hasClients) return;
    const edge = 56.0;
    var delta = 0.0;
    if (position.dy < edge) {
      delta = -18;
    } else if (position.dy > height - edge) {
      delta = 18;
    }
    if (delta == 0) return;
    final target = (_scroll.offset + delta)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_phase) {
          _Phase.sources => 'Sources',
          _Phase.pick => 'Choose servers',
          _ => 'Free servers',
        },),
        leading: IconButton(
          icon: Icon(
            _phase == _Phase.sources || _phase == _Phase.pick
                ? Icons.arrow_back_rounded
                : Icons.close_rounded,
          ),
          onPressed: () {
            if (_phase == _Phase.sources) {
              setState(() => _phase = _Phase.start);
            } else if (_phase == _Phase.pick) {
              setState(() => _phase = _Phase.summary);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: switch (_phase) {
              _Phase.start => _buildStart(theme),
              _Phase.sources => _buildSources(theme),
              _Phase.working => _buildWorking(theme),
              _Phase.summary => _buildSummary(theme),
              _Phase.pick => _buildPick(theme),
            },
          ),
        ),
      ),
    );
  }

  Widget _centered(List<Widget> children) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: children,
        ),
      ),
    );
  }

  Widget _buildStart(ThemeData theme) {
    return _centered([
      Icon(Icons.public_rounded, size: 72, color: theme.colorScheme.primary),
      Text(
        'Find free servers',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      Text(
        'Pray looks for free servers shared by volunteers, checks which ones '
        'work and adds the fastest ones for you.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
      if (_message != null)
        Text(
          _message!,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      FilledButton.icon(
        onPressed: _run,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Find free servers'),
      ),
      TextButton(
        onPressed: () => setState(() => _phase = _Phase.sources),
        child: const Text('Change where to look'),
      ),
      Text(
        'Free servers are shared with many people. Do not use them for '
        'banking or private accounts.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    ]);
  }

  Widget _buildSources(ThemeData theme) {
    return ListView(
      children: [
        for (final source in _sources)
          CheckboxListTile(
            value: _enabled.contains(source.url),
            title: Text(source.name),
            subtitle: Text(
              source.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: IconButton(
              tooltip: 'Remove'.tr,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                setState(() {
                  _sources = [
                    for (final s in _sources)
                      if (s != source) s,
                  ];
                  _enabled.remove(source.url);
                });
                _persist();
              },
            ),
            onChanged: (value) => setState(() {
              if (value ?? false) {
                _enabled.add(source.url);
              } else {
                _enabled.remove(source.url);
              }
            }),
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded),
          title: const Text('Add a source'),
          onTap: _addSource,
        ),
        ListTile(
          leading: const Icon(Icons.restore_rounded),
          title: const Text('Restore the default sources'),
          onTap: () {
            setState(() {
              _sources = List.of(defaultConfigSources);
              _enabled
                ..clear()
                ..addAll(_sources.map((s) => s.url));
            });
            _persist();
          },
        ),
      ],
    );
  }

  Widget _buildWorking(ThemeData theme) {
    return _centered([
      Center(
        child: SizedBox.square(
          dimension: 72,
          child: CircularProgressIndicator(value: _progress, strokeWidth: 6),
        ),
      ),
      Text(
        _status,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      Text(
        'This can take a minute.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    ]);
  }

  Widget _buildSummary(ThemeData theme) {
    final count = _found.length < _quickCount ? _found.length : _quickCount;
    return _centered([
      Icon(
        Icons.check_circle_rounded,
        size: 72,
        color: theme.colorScheme.primary,
      ),
      Text(
        '${_found.length} working servers found',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      FilledButton.icon(
        onPressed: () {
          _picked
            ..clear()
            ..addAll(_found.take(count));
          _import();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text('Add the best $count'),
      ),
      TextButton(
        onPressed: () => setState(() => _phase = _Phase.pick),
        child: const Text('Let me choose'),
      ),
    ]);
  }

  Widget _buildPick(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: Text(
                  '${_picked.length} of ${_found.length} selected',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _picked.addAll(_found)),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => setState(_picked.clear),
                child: const Text('Deselect all'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tip: press and hold a row, then drag to select many.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onLongPressStart: (details) {
                  HapticFeedback.selectionClick();
                  _dragAnchor = _indexAt(details.localPosition);
                  _dragBase = {..._picked};
                  _dragSelects = !_picked.contains(_found[_dragAnchor]);
                  _applyDrag(_dragAnchor);
                },
                onLongPressMoveUpdate: (details) {
                  _autoScroll(details.localPosition, constraints.maxHeight);
                  _applyDrag(_indexAt(details.localPosition));
                },
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: _rowHeight,
                  itemCount: _found.length,
                  itemBuilder: (context, index) {
                    final server = _found[index];
                    return CheckboxListTile(
                      value: _picked.contains(server),
                      title: Text(
                        server.proxy.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${server.proxy.summary}, ${server.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: PingPill(pingMs: server.pingMs),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _picked.add(server);
                        } else {
                          _picked.remove(server);
                        }
                      }),
                    );
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _picked.isEmpty ? null : _import,
              child: Text('Add ${_picked.length}'),
            ),
          ),
        ),
      ],
    );
  }
}
