import 'package:flutter/material.dart';
import 'package:pray/localization/localization.dart';

abstract class AppTextStyle {
  static const List<String> fontFallback = [
    'NotoSans',
    'NotoSansArabic',
    'NotoSansSC',
    'NotoSansJP',
  ];

  static String get fontFamily => switch (L10n.code) {
        'fa' => 'NotoSansArabic',
        'ru' => 'NotoSans',
        'zh' => 'NotoSansSC',
        'ja' => 'NotoSansJP',
        _ => 'SpaceGrotesk',
      };

  static const double scale = 1.2;

  static TextStyle _style(double size, int weight, {double letterSpacing = 0}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size * scale - 2,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation.weight(weight.toDouble())],
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle get headlineSmall => _style(22, 600, letterSpacing: -0.4);
  static TextStyle get titleLarge => _style(20, 600);
  static TextStyle get titleMedium => _style(15, 600);
  static TextStyle get bodyMedium => _style(14, 400);
  static TextStyle get bodySmall => _style(12, 400);
  static TextStyle get labelLarge => _style(14, 600);
  static TextStyle get labelMedium => _style(12, 600);

  static TextTheme get textTheme => TextTheme(
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
      );
}
