import 'dart:io';

import 'package:pray/app_info.dart';

abstract class AutostartService {
  static String get _file {
    final base = Platform.environment['XDG_CONFIG_HOME'] ??
        '${Platform.environment['HOME']}/.config';
    return '$base/autostart/${AppInfo.linuxPackageName}.desktop';
  }

  static String get _executable =>
      Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isLinux) return;
    final file = File(_file);
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final exec = _executable.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    await file.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=${AppInfo.name}\n'
      'Comment=Start ${AppInfo.name} with your session\n'
      'Exec="$exec" --tray\n'
      'Icon=${AppInfo.linuxPackageName}\n'
      'Terminal=false\n'
      'X-GNOME-Autostart-enabled=true\n',
      flush: true,
    );
  }

  static Future<bool> isEnabled() async {
    if (!Platform.isLinux) return false;
    return File(_file).exists();
  }
}
