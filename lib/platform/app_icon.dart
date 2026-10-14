import 'package:flutter/material.dart';

abstract class AppIcon {
  static const String logoMocha = 'assets/icons/logo_mocha.png';
  static const String logoLatte = 'assets/icons/logo_latte.png';

  static const String trayMocha = 'assets/icons/tray_mocha.png';
  static const String trayLatte = 'assets/icons/tray_latte.png';

  static String logo(Brightness brightness) =>
      brightness == Brightness.dark ? logoMocha : logoLatte;

  static String tray(Brightness brightness) =>
      brightness == Brightness.dark ? trayMocha : trayLatte;
}
