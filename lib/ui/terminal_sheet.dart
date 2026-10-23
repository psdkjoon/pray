import 'package:flutter/material.dart' hide Text, Icon;
import 'package:flutter/services.dart';
import 'package:pray/core/terminal_proxy.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';

Future<void> showTerminalSheet(BuildContext context, int port) async {
  await TerminalProxy.write(port);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TerminalSheet(port: port),
  );
}

class _TerminalSheet extends StatelessWidget {
  const _TerminalSheet({required this.port});

  final int port;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                Text('Terminal', style: theme.textTheme.titleLarge),
                Text(
                  'Run a program through Pray. Connect first.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                _CommandCard(
                  title: 'proxychains4',
                  command: TerminalProxy.proxychainsCommand(),
                  hint: 'Put the program after it, for example curl ifconfig.me',
                ),
                _CommandCard(
                  title: 'bash, zsh',
                  command: TerminalProxy.shellCommand(),
                  hint: 'Sets ALL_PROXY, HTTP_PROXY and HTTPS_PROXY for this shell',
                ),
                _CommandCard(
                  title: 'fish',
                  command: TerminalProxy.fishCommand(),
                  hint: 'The same for fish',
                ),
                Text(
                  'proxychains cannot reach programs that are statically linked, '
                  'such as many Go programs. Use the variables, or TUN mode, for those.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.title,
    required this.command,
    required this.hint,
  });

  final String title;
  final String command;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xxs,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Copy command'.tr,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: command));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Command copied'.tr)),
                    );
                  },
                ),
              ],
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                command,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
