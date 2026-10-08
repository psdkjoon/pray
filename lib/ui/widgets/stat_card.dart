import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.inline = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool inline;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final caption = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _iconSize, color: muted),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
    final number = Text(value, style: theme.textTheme.titleMedium);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: inline
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [caption, number],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: caption,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: number,
                  ),
                ],
              ),
      ),
    );
  }
}
