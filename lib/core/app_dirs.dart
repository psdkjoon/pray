import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;

abstract class AppDirs {
  static const _channel = MethodChannel('pray/android_paths');
  static String? _data;

  static Future<String> data() async {
    final cached = _data;
    if (cached != null) return cached;
    final String path;
    if (Platform.isAndroid) {
      final paths = await _channel.invokeMapMethod<String, String>('resolve');
      path = paths?['filesDir'] ?? Directory.systemTemp.path;
    } else {
      final base = Platform.environment['XDG_DATA_HOME'] ??
          '${Platform.environment['HOME']}/.local/share';
      path = '$base/pray';
    }
    await Directory(path).create(recursive: true);
    return _data = path;
  }

  static Future<String> downloads() async {
    if (Platform.isAndroid) return data();
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final dir = Directory('$home/Downloads');
    return await dir.exists() ? dir.path : home;
  }
}
