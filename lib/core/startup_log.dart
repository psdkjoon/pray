import 'dart:io';

import 'package:pray/app_info.dart';
import 'package:pray/core/app_dirs.dart';

abstract class StartupLog {
  static String? lastPath;

  static Future<void> write(Object error, StackTrace? stack) async {
    final text = '[${DateTime.now().toIso8601String()}] '
        'Pray ${AppInfo.version} on ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}\n$error\n${stack ?? ''}\n\n';
    for (final dir in [
      AppDirs.data,
      () async => Directory.systemTemp.path,
    ]) {
      try {
        final file = File('${await dir()}/startup.log');
        await file.writeAsString(text, mode: FileMode.append, flush: true);
        lastPath = file.path;
        return;
      } on Object {
        continue;
      }
    }
  }
}
