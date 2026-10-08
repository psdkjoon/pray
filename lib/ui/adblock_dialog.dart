import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/core/adblock_lists.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/theme/app_spacing.dart';

Future<void> showAdBlockLists(BuildContext context, AppSettings settings) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AdListsDialog(settings: settings),
  );
}

class _AdListsDialog extends StatefulWidget {
  const _AdListsDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_AdListsDialog> createState() => _AdListsDialogState();
}

class _AdListsDialogState extends State<_AdListsDialog> {
  late List<AdList> _lists = List.of(widget.settings.adLists);
  var _busy = false;
  double? _progress;
  String? _message;
  int? _count;
  DateTime? _updated;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final domains = await AdBlockLists.load();
    final updated = await AdBlockLists.lastUpdated();
    if (!mounted) return;
    setState(() {
      _count = domains.length;
      _updated = updated;
    });
  }

  void _commit(List<AdList> lists) {
    setState(() => _lists = lists);
    widget.settings.adLists = lists;
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _progress = null;
      _message = null;
    });
    String message;
    try {
      final result = await AdBlockLists.update(
        _lists,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      message = '${result.count} domains ready.';
      if (result.failed.isNotEmpty) {
        message += ' Failed: ${result.failed.join(', ')}.';
      }
    } on Object catch (e) {
      message = "Couldn't update: $e";
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
    await _refresh();
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final result = await showDialog<AdList>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add filter list'),
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
                labelText: 'List URL'.tr,
                helperText: 'Hosts, plain domain or AdGuard-style list'.tr,
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
                AdList(
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
    if (result != null) _commit([..._lists, result]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _updated;
    return AlertDialog(
      title: const Text('Filter lists'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Turn on the lists you want, then download them. Every domain '
                'in an enabled list is blocked while Pray is connected. '
                'More lists block more, but can break some sites and apps.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final list in _lists)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: list.enabled,
                  title: Text(list.name),
                  subtitle: Text(
                    list.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: IconButton(
                    tooltip: 'Remove'.tr,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _commit([
                      for (final l in _lists)
                        if (l != list) l,
                    ]),
                  ),
                  onChanged: (value) => _commit([
                    for (final l in _lists)
                      if (l == list) l.copyWith(enabled: value) else l,
                  ]),
                ),
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a list'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _busy
                    ? SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.system_update_alt_rounded),
                title: const Text('Download enabled lists'),
                subtitle: Text(
                  _busy
                      ? (_progress == null
                          ? 'Downloading…'
                          : 'Downloading ${(_progress! * 100).round()}%')
                      : '${_count ?? 0} domains'
                          '${date == null ? '' : ', updated ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'}',
                ),
                onTap: _busy ? null : _update,
              ),
              if (_message != null)
                Text(_message!, style: theme.textTheme.bodySmall),
              Text(
                'Reconnect after updating to apply the new lists.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
