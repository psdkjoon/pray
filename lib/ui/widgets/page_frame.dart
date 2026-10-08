import 'package:flutter/material.dart';
import 'package:pray/theme/app_spacing.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.child,
    this.actions = const [],
    super.key,
  });

  final Widget child;
  final List<Widget> actions;

  static const double maxWidth = 36 * AppSpacing.spaceUnit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            spacing: AppSpacing.md,
            children: [
              if (actions.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
