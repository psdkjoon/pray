import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    this.help,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            spacing: AppSpacing.xxs,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (help != null)
                IconButton(
                  tooltip: 'What does this do?'.tr,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(title),
                      content: SingleChildScrollView(
                        child: SelectableText(L10n.wrap(help!.tr)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
