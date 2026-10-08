import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:flutter/services.dart';
import 'package:pray/core/pray_file.dart';
import 'package:pray/platform/system_service.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/qr_view.dart';
import 'package:xray_config/xray_config.dart';

enum _ShareTab { link, qr, file }

Future<void> showShareDialog(
  BuildContext context,
  List<StoredServer> servers,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(servers: servers),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.servers});

  final List<StoredServer> servers;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  var _tab = _ShareTab.link;
  var _protect = false;
  var _busy = false;
  final _password = TextEditingController();
  String? _message;

  late final List<String> _links = [
    for (final s in widget.servers) buildLink(s.proxy),
  ];

  bool get _single => widget.servers.length == 1;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String get _fileName {
    final base = _single
        ? widget.servers.first.name.replaceAll(RegExp(r'[^\w\-. ]+'), '_').trim()
        : 'pray-servers';
    return '${base.isEmpty ? 'pray-server' : base}.${PrayFile.extension}';
  }

  Future<void> _save() async {
    if (_protect && _password.text.isEmpty) {
      setState(() => _message = 'Enter a password or turn protection off.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      final bytes = await PrayFile.encode(
        _links,
        password: _protect ? _password.text : null,
      );
      final saved = await SystemService.saveFile(_fileName, bytes);
      message = saved == null ? null : 'Saved $saved';
    } on Object catch (e) {
      message = "Couldn't save the file: $e";
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _links.join('\n')));
    if (!mounted) return;
    setState(() => _message = _single ? 'Link copied' : 'Links copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_single ? widget.servers.first.name : 'Share all servers'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              SegmentedButton<_ShareTab>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: _ShareTab.link,
                    label: Text('Link'),
                    icon: Icon(Icons.link_rounded),
                  ),
                  ButtonSegment(
                    value: _ShareTab.qr,
                    label: const Text('QR'),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    enabled: _single,
                  ),
                  const ButtonSegment(
                    value: _ShareTab.file,
                    label: Text('File'),
                    icon: Icon(Icons.insert_drive_file_outlined),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (value) => setState(() {
                  _tab = value.first;
                  _message = null;
                }),
              ),
              switch (_tab) {
                _ShareTab.link => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.sm,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _links.join('\n\n'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                _ShareTab.qr => Center(child: QrView(data: _links.first)),
                _ShareTab.file => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.sm,
                    children: [
                      SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        title: const Text('Protect with a password'),
                        subtitle: Text(
                          _protect
                              ? 'Only people with the password can open it'
                              : 'Any Pray app can open it',
                        ),
                        value: _protect,
                        onChanged: (value) => setState(() => _protect = value),
                      ),
                      if (_protect)
                        TextField(
                          controller: _password,
                          obscureText: true,
                          decoration:
                              InputDecoration(labelText: 'Password'.tr),
                        ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_alt_rounded),
                        label: Text('Save $_fileName'),
                      ),
                    ],
                  ),
              },
              if (_message != null)
                Text(_message!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
