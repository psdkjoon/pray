import 'package:flutter/material.dart';

abstract class AppIcon {
  static const String trayMocha = 'assets/icons/tray_mocha.png';
  static const String trayLatte = 'assets/icons/tray_latte.png';

  static String tray(Brightness brightness) =>
      brightness == Brightness.dark ? trayMocha : trayLatte;
}
