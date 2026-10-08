import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pray/core/app_dirs.dart';

class FileDialogUnavailable implements Exception {
  const FileDialogUnavailable();

  @override
  String toString() => 'Install zenity or kdialog to choose files.';
}

abstract class SystemService {
  static const _channel = MethodChannel('pray/system');
  static const _window = MethodChannel('pray/window');

  static Future<void> openUrl(String url) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openUrl', {'url': url});
      return;
    }
    await Process.start(
      'xdg-open',
      [url],
      mode: ProcessStartMode.detached,
    );
  }

  static Future<String?> androidAbi() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('abi');
    } on PlatformException {
      return null;
    }
  }

  static Future<void> notify(String title, String body) async {
    if (!Platform.isLinux) return;
    try {
      await _window.invokeMethod<void>('notify', {'title': title, 'body': body});
    } on PlatformException {
      return;
    }
  }

  static Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestNotifications');
    } on PlatformException {
      return;
    }
  }

  static Future<String?> saveFile(String name, Uint8List bytes) async {
    if (Platform.isAndroid) {
      final ok = await _channel.invokeMethod<bool>('saveFile', {
        'name': name,
        'bytes': bytes,
      });
      return (ok ?? false) ? name : null;
    }
    final downloads = await AppDirs.downloads();
    final chosen = await _linuxDialog(
      zenity: [
        '--file-selection',
        '--save',
        '--confirm-overwrite',
        '--filename=$downloads/$name',
      ],
      kdialog: ['--getsavefilename', '$downloads/$name'],
    );
    final path = chosen.available ? chosen.path : '$downloads/$name';
    if (path == null) return null;
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<Uint8List?> pickFile() async {
    if (Platform.isAndroid) {
      return _channel.invokeMethod<Uint8List>('pickFile');
    }
    final chosen = await _linuxDialog(
      zenity: ['--file-selection'],
      kdialog: ['--getopenfilename', await AppDirs.downloads()],
    );
    if (!chosen.available) throw const FileDialogUnavailable();
    final path = chosen.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }

  static Future<({bool available, String? path})> _linuxDialog({
    required List<String> zenity,
    required List<String> kdialog,
  }) async {
    for (final (tool, args) in [('zenity', zenity), ('kdialog', kdialog)]) {
      try {
        final result = await Process.run(tool, args);
        final path = (result.stdout as String).trim();
        return (
          available: true,
          path: result.exitCode == 0 && path.isNotEmpty ? path : null,
        );
      } on ProcessException {
        continue;
      }
    }
    return (available: false, path: null);
  }
}
