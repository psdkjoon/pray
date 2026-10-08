import 'package:flutter/material.dart' hide Text;
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/theme/app_theme.dart';

class PingPill extends StatelessWidget {
  const PingPill({required this.pingMs, super.key});

  final int? pingMs;

  static const int _slowMs = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = theme.extension<StatusColors>()!;
    final ms = pingMs;
    final color = switch (ms) {
      null => theme.colorScheme.outline,
      final value when value >= _slowMs => status.warning,
      _ => status.connected,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          ms == null ? '\u2014' : '$ms ms',
          style: theme.textTheme.labelMedium,
        ),
      ),
    );
  }
}
