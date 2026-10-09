import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pray/app_info.dart';

abstract class AutostartService {
  static const _system = MethodChannel('pray/system');

  static bool get supported => Platform.isLinux || Platform.isWindows;

  static String get _file {
    final home = Platform.environment['HOME'] ?? '';
    final configured = Platform.environment['XDG_CONFIG_HOME'];
    final base =
        configured != null && configured.isNotEmpty ? configured : '$home/.config';
    return '$base/autostart/${AppInfo.linuxPackageName}.desktop';
  }

  static String get _executable {
    final appImage = Platform.environment['APPIMAGE'];
    return appImage != null && appImage.isNotEmpty
        ? appImage
        : Platform.resolvedExecutable;
  }

  /// Quotes [path] for the Exec key of a desktop entry. The spec applies two
  /// escaping layers (Exec quoting, then the generic string escape), so a
  /// literal backslash needs four backslashes and `"`, `$` and a backtick need
  /// two. A literal `%` is written `%%`.
  static String _quoteExec(String path) {
    final out = StringBuffer('"');
    for (final rune in path.replaceAll('\n', ' ').runes) {
      final ch = String.fromCharCode(rune);
      switch (ch) {
        case r'\':
          out.write(r'\\\\');
        case '"':
        case r'$':
        case '`':
          out
            ..write(r'\\')
            ..write(ch);
        case '%':
          out.write('%%');
        default:
          out.write(ch);
      }
    }
    out.write('"');
    return out.toString();
  }

  /// Returns whether the setting now matches [enabled].
  static Future<bool> setEnabled(bool enabled) async {
    try {
      if (Platform.isWindows) {
        await _system.invokeMethod<void>('setAutostart', {'enabled': enabled});
        return true;
      }
      if (!Platform.isLinux) return false;
      final file = File(_file);
      if (!enabled) {
        if (await file.exists()) await file.delete();
        return true;
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=${AppInfo.name}\n'
        'Comment=Start ${AppInfo.name} with your session\n'
        'Exec=${_quoteExec(_executable)} --tray\n'
        'Icon=${AppInfo.linuxPackageName}\n'
        'Terminal=false\n'
        'StartupNotify=false\n'
        'Hidden=false\n'
        'X-GNOME-Autostart-enabled=true\n'
        'X-KDE-autostart-after=panel\n',
        flush: true,
      );
      return true;
    } on Object {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      if (Platform.isWindows) {
        return await _system.invokeMethod<bool>('getAutostart') ?? false;
      }
      if (!Platform.isLinux) return false;
      return await File(_file).exists();
    } on Object {
      return false;
    }
  }
}
