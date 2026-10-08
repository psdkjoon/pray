import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:flutter/services.dart';
import 'package:pray/core/http_fetch.dart';
import 'package:pray/core/pray_file.dart';
import 'package:pray/platform/system_service.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/ui/free_configs_dialog.dart';
import 'package:pray/ui/share_dialog.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:xray_config/xray_config.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/coming_soon.dart';
import 'package:pray/ui/widgets/page_frame.dart';
import 'package:pray/ui/widgets/server_tile.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({
    required this.servers,
    required this.settings,
    super.key,
  });

  final ServersController servers;
  final AppSettings settings;

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  ServersController get servers => widget.servers;
  AppSettings get settings => widget.settings;

  static const double _spinnerSize = 22;

  final Set<String> _picked = {};

  void _toggle(String id) {
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
  }

  void _clear() => setState(_picked.clear);

  Future<void> _deletePicked(BuildContext context) async {
    final count = _picked.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Delete server?' : 'Delete $count servers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      servers.removeMany(Set.of(_picked));
      _clear();
    }
  }

  void _showSortSheet(BuildContext context) {
    const icons = {
      ServerSort.added: Icons.history_rounded,
      ServerSort.newest: Icons.schedule_rounded,
      ServerSort.ping: Icons.speed_rounded,
      ServerSort.name: Icons.sort_by_alpha_rounded,
      ServerSort.protocol: Icons.hub_rounded,
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'Sort servers',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final option in ServerSort.values)
                ListTile(
                  selected: option == servers.sort,
                  leading: Icon(icons[option]),
                  title: Text(option.label),
                  trailing: option == servers.sort
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    servers.sort = option;
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _selectionActions(BuildContext context, List<StoredServer> all) {
    final picked = [for (final s in all) if (_picked.contains(s.id)) s];
    final allPinned = picked.isNotEmpty && picked.every((s) => s.pinned);
    const compact = VisualDensity.compact;
    return [
      IconButton(
        visualDensity: compact,
        tooltip: 'Cancel'.tr,
        onPressed: _clear,
        icon: const Icon(Icons.close_rounded),
      ),
      Expanded(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${picked.length} selected',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
      IconButton(
        visualDensity: compact,
        tooltip: 'Share'.tr,
        onPressed: () => showShareDialog(context, picked),
        icon: const Icon(Icons.ios_share_rounded),
      ),
      IconButton(
        visualDensity: compact,
        tooltip: 'Delete'.tr,
        onPressed: () => _deletePicked(context),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
      PopupMenuButton<String>(
        tooltip: 'More'.tr,
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          switch (value) {
            case 'all':
              setState(() => _picked.addAll(all.map((s) => s.id)));
            case 'none':
              _clear();
            case 'pin':
              servers.pinMany(Set.of(_picked), pinned: !allPinned);
              _clear();
            case 'test':
              unawaited(servers.testSome(Set.of(_picked)));
              _clear();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'all',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.select_all_rounded),
              title: const Text('Select all'),
            ),
          ),
          const PopupMenuItem(
            value: 'none',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.deselect_rounded),
              title: const Text('Deselect all'),
            ),
          ),
          PopupMenuItem(
            value: 'pin',
            child: ListTile(
              dense: true,
              leading: Icon(
                allPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              ),
              title: Text(allPinned ? 'Unpin' : 'Pin to top'),
            ),
          ),
          const PopupMenuItem(
            value: 'test',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.speed_rounded),
              title: const Text('Test latency'),
            ),
          ),
        ],
      ),
    ];
  }

  static const double _rowHeight = 88;
  final _scroll = ScrollController();
  var _dragAnchor = 0;
  var _dragSelects = true;
  Set<String> _dragBase = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indexAt(Offset position, int length) {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final raw = ((position.dy + offset) / _rowHeight).floor();
    return raw.clamp(0, length - 1);
  }

  void _applyDrag(List<StoredServer> all, int index) {
    final from = _dragAnchor < index ? _dragAnchor : index;
    final to = _dragAnchor < index ? index : _dragAnchor;
    final range = all.sublist(from, to + 1).map((s) => s.id);
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
    final target =
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _picked.isNotEmpty) {
      _clear();
      return KeyEventResult.handled;
    }
    if (event.physicalKey == PhysicalKeyboardKey.keyV &&
        HardwareKeyboard.instance.isControlPressed) {
      unawaited(_pasteFromClipboard(context));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: _page(context),
    );
  }

  Widget _page(BuildContext context) {
    return ListenableBuilder(
      listenable: servers,
      builder: (context, _) {
        final all = servers.servers;
        _picked.removeWhere((id) => !all.any((s) => s.id == id));
        final selecting = _picked.isNotEmpty;
        return PageFrame(
          actions: selecting
              ? _selectionActions(context, all)
              : [
                  IconButton(
                    tooltip: 'Sort servers'.tr,
                    onPressed: () => _showSortSheet(context),
                    icon: const Icon(Icons.sort_rounded),
                  ),
                  IconButton(
                    tooltip: 'Test latency'.tr,
                    onPressed: servers.testing ? null : servers.testAll,
                    icon: servers.testing
                        ? const SizedBox.square(
                            dimension: _spinnerSize,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.speed_rounded),
                  ),
                  IconButton(
                    tooltip: 'Free configs'.tr,
                    onPressed: () =>
                        showFreeConfigsDialog(context, servers, settings),
                    icon: const Icon(Icons.public_rounded),
                  ),
                  IconButton(
                    tooltip: 'Share all servers'.tr,
                    onPressed: all.isEmpty
                        ? null
                        : () => showShareDialog(context, all),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  IconButton(
                    tooltip: 'Add server'.tr,
                    onPressed: () => _showAddSheet(context),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
          child: all.isEmpty
              ? const Center(child: Text('No servers yet. Tap + to add one.'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onLongPressStart: (details) {
                        unawaited(HapticFeedback.selectionClick());
                        _dragAnchor = _indexAt(details.localPosition, all.length);
                        _dragBase = {..._picked};
                        _dragSelects = !_picked.contains(all[_dragAnchor].id);
                        _applyDrag(all, _dragAnchor);
                      },
                      onLongPressMoveUpdate: (details) {
                        _autoScroll(details.localPosition, constraints.maxHeight);
                        _applyDrag(
                          all,
                          _indexAt(details.localPosition, all.length),
                        );
                      },
                      child: ListView.builder(
                        controller: _scroll,
                        itemExtent: _rowHeight,
                        itemCount: all.length,
                        itemBuilder: (context, index) {
                          final server = all[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: ServerTile(
                              server: server,
                              selected: server.id == servers.selectedId,
                              selecting: selecting,
                              checked: _picked.contains(server.id),
                              onTap: () {
                                if (selecting) {
                                  _toggle(server.id);
                                } else {
                                  servers.select(server.id);
                                }
                              },
                              onEdit: () => _edit(context, server),
                              onDelete: () => _delete(context, server),
                              onPin: () => servers.togglePin(server.id),
                              onShare: () =>
                                  showShareDialog(context, [server]),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, StoredServer server) async {
    final result = await showDialog<ProxyServer>(
      context: context,
      builder: (_) => _EditServerDialog(proxy: server.proxy),
    );
    if (result != null) servers.update(server.id, result);
  }

  Future<void> _delete(BuildContext context, StoredServer server) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete server?'),
        content: Text(server.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) servers.remove(server.id);
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!context.mounted) return;

    if (text.isEmpty) {
      _snack(context, 'Clipboard is empty');
      return;
    }

    final result = servers.addFromSubscription(text);
    final added = result.servers.length;
    final failed = result.errors.length;

    if (added == 0 && failed == 0) {
      _snack(context, 'No share links found in the clipboard');
    } else if (added == 0) {
      _snack(context, result.errors.first.message);
    } else if (failed == 0) {
      _snack(context, added == 1 ? 'Added 1 server' : 'Added $added servers');
    } else {
      _snack(context, 'Added $added server(s), $failed line(s) had errors');
    }
  }

  void _report(BuildContext context, SubscriptionResult result) {
    final added = result.servers.length;
    final failed = result.errors.length;
    if (added == 0) {
      _snack(
        context,
        failed == 0 ? 'No servers found' : result.errors.first.message,
      );
    } else if (failed == 0) {
      _snack(context, added == 1 ? 'Added 1 server' : 'Added $added servers');
    } else {
      _snack(context, 'Added $added server(s), $failed line(s) had errors');
    }
  }

  Future<void> _importFile(BuildContext context) async {
    try {
      final bytes = await SystemService.pickFile();
      if (bytes == null || !context.mounted) return;
      String? password;
      if (PrayFile.needsPassword(bytes)) {
        password = await _askPassword(context);
        if (password == null || !context.mounted) return;
      }
      final links = await PrayFile.decode(bytes, password: password);
      if (!context.mounted) return;
      _report(context, servers.addFromSubscription(links.join('\n')));
    } on Object catch (e) {
      if (context.mounted) _snack(context, '$e');
    }
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: 'File password'.tr),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _importSubscription(BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Subscription URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'https://…'.tr),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty || !context.mounted) return;
    try {
      final body = await fetchText(url.trim());
      if (!context.mounted) return;
      _report(context, servers.addFromSubscription(body));
    } on Object catch (e) {
      if (context.mounted) _snack(context, "Couldn't download: $e");
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddSheet(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void comingSoon(String what) {
          Navigator.of(sheetContext).pop();
          showComingSoon(context, what);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    'Add server',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.content_paste_rounded),
                  title: const Text('Paste from clipboard'),
                  subtitle: const Text(
                    'One or more vless, vmess, trojan or ss links',
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pasteFromClipboard(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Subscription URL'),
                  subtitle: const Text('Download a whole list of servers'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _importSubscription(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('Import .pray file'),
                  subtitle: const Text('Servers shared by another Pray app'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _importFile(context);
                  },
                ),
                if (isAndroid)
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner_rounded),
                    title: const Text('Scan QR code'),
                    subtitle: const Text('Use the camera'),
                    onTap: () => comingSoon('QR scanning'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditServerDialog extends StatefulWidget {
  const _EditServerDialog({required this.proxy});

  final ProxyServer proxy;

  @override
  State<_EditServerDialog> createState() => _EditServerDialogState();
}

class _EditServerDialogState extends State<_EditServerDialog> {
  late final _name = TextEditingController(text: widget.proxy.name);
  late final _address = TextEditingController(text: widget.proxy.address);
  late final _port = TextEditingController(text: '${widget.proxy.port}');
  late final _secret = TextEditingController(
    text: _usesId ? widget.proxy.id : widget.proxy.password,
  );
  String? _error;

  bool get _usesId =>
      widget.proxy.protocol == ProxyProtocol.vless ||
      widget.proxy.protocol == ProxyProtocol.vmess;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _port.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _save() {
    final address = _address.text.trim();
    final port = int.tryParse(_port.text.trim());
    final secret = _secret.text.trim();
    if (address.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Enter a valid address and port (1-65535).');
      return;
    }
    Navigator.of(context).pop(
      widget.proxy.copyWith(
        name: _name.text.trim(),
        address: address,
        port: port,
        id: _usesId ? secret : null,
        password: _usesId ? null : secret,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: 'Name'.tr),
            ),
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: 'Address'.tr),
            ),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Port'.tr),
            ),
            TextField(
              controller: _secret,
              decoration: InputDecoration(
                labelText: (_usesId ? 'UUID' : 'Password').tr,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
