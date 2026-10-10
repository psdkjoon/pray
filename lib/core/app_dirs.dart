import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;

abstract class AppDirs {
  static const _channel = MethodChannel('pray/android_paths');
  static String? _data;

  static Future<String> data() async {
    final cached = _data;
    if (cached != null) return cached;
    for (final candidate in await _candidates()) {
      try {
        await Directory(candidate).create(recursive: true);
        return _data = candidate;
      } on Object {
        continue;
      }
    }
    return _data = Directory.systemTemp.path;
  }

  static Future<List<String>> _candidates() async {
    final env = Platform.environment;
    String? set(String? value) =>
        value == null || value.trim().isEmpty ? null : value;
    if (Platform.isAndroid) {
      try {
        final paths = await _channel.invokeMapMethod<String, String>('resolve');
        final dir = set(paths?['filesDir']);
        if (dir != null) return [dir];
      } on Object {}
      return [];
    }
    if (Platform.isWindows) {
      return [
        for (final base in [
          set(env['APPDATA']),
          set(env['LOCALAPPDATA']),
          set(env['USERPROFILE']),
        ])
          if (base != null) '$base\\pray',
      ];
    }
    final xdg = set(env['XDG_DATA_HOME']);
    final home = set(env['HOME']);
    return [
      if (xdg != null) '$xdg/pray',
      if (home != null) '$home/.local/share/pray',
    ];
  }

  static Future<String> downloads() async {
    if (Platform.isAndroid) return data();
    final home =
        (Platform.isWindows
            ? Platform.environment['USERPROFILE']
            : Platform.environment['HOME']) ??
        Directory.systemTemp.path;
    final dir = Directory('$home/Downloads');
    return await dir.exists() ? dir.path : home;
  }
}
