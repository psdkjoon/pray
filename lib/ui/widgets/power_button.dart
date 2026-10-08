import 'package:flutter/material.dart' hide Icon;
import 'package:pray/localization/localization.dart' show Icon, TrString;
import 'package:pray/connection/connection_controller.dart';

class PowerButton extends StatelessWidget {
  const PowerButton({
    required this.status,
    required this.onPressed,
    super.key,
  });

  final ConnectionStatus status;
  final VoidCallback onPressed;

  static const double _diameter = 168;
  static const double _iconSize = 72;
  static const double _spinnerSize = 52;
  static const double _innerRing = 12;
  static const double _outerRing = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = status != ConnectionStatus.disconnected;
    final glow = scheme.primary;

    return RepaintBoundary(
      child: Semantics(
      button: true,
      label: (active ? 'Disconnect' : 'Connect').tr,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? scheme.primary : scheme.surfaceContainerHigh,
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: active ? 0.24 : 0.10),
              spreadRadius: _innerRing,
            ),
            BoxShadow(
              color: glow.withValues(alpha: active ? 0.10 : 0),
              spreadRadius: _outerRing,
            ),
            BoxShadow(
              color: glow.withValues(alpha: active ? 0.45 : 0),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipOval(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: status == ConnectionStatus.connecting
                    ? SizedBox.square(
                        dimension: _spinnerSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        size: _iconSize,
                        color: active ? scheme.onPrimary : scheme.primary,
                      ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
