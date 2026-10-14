import 'package:flutter/material.dart' hide Icon, Text;
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/theme/app_text_style.dart';
import 'package:pray/theme/catppuccin.dart';

@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.heart,
  });

  final Color success;
  final Color warning;
  final Color heart;

  @override
  StatusColors copyWith({Color? success, Color? warning, Color? heart}) {
    return StatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      heart: heart ?? this.heart,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
    );
  }
}

abstract class AppTheme {
  static final Map<String, ThemeData> _cache = <String, ThemeData>{};

  static ThemeData light(String accent) => _cache.putIfAbsent(
        'light:${L10n.code}:$accent',
        () => _build(CatppuccinPalette.latte, Brightness.light, accent),
      );

  static ThemeData dark(String accent) => _cache.putIfAbsent(
        'dark:${L10n.code}:$accent',
        () => _build(CatppuccinPalette.mocha, Brightness.dark, accent),
      );

  static ThemeData _build(
    CatppuccinPalette c,
    Brightness brightness,
    String accentName,
  ) {
    final isDark = brightness == Brightness.dark;
    final accent = c.accent(accentName);
    final onAccent = isDark ? c.crust : c.base;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: c.surface0,
      onPrimaryContainer: accent,
      secondary: c.blue,
      onSecondary: onAccent,
      secondaryContainer: Color.alphaBlend(accent.withValues(alpha: 0.16), c.mantle),
      onSecondaryContainer: accent,
      tertiary: c.peach,
      onTertiary: onAccent,
      error: c.red,
      onError: onAccent,
      surface: c.base,
      onSurface: c.text,
      onSurfaceVariant: isDark ? c.subtext0 : c.subtext1,
      outline: c.overlay0,
      outlineVariant: c.surface1,
      surfaceContainerLowest: c.crust,
      surfaceContainerLow: c.mantle,
      surfaceContainer: c.mantle,
      surfaceContainerHigh: c.surface0,
      surfaceContainerHighest: c.surface1,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: AppTextStyle.fontFamily,
      fontFamilyFallback: AppTextStyle.fontFallback,
      textTheme: AppTextStyle.textTheme,
      extensions: [StatusColors(success: c.green, warning: c.peach, heart: c.pink)],
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: AppTextStyle.labelMedium.copyWith(color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: AppSpacing.lg,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.onSecondaryContainer,
        selectedTileColor: scheme.secondaryContainer,
        titleTextStyle: AppTextStyle.labelLarge,
        subtitleTextStyle: AppTextStyle.bodySmall
            .copyWith(color: scheme.onSurfaceVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(AppTextStyle.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant;
          }),
        ),
      ),
    );
  }
}
