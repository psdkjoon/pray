import 'dart:async';
import 'dart:io';

import 'package:pray/core/app_dirs.dart';

class UpdateCancelled implements Exception {
  const UpdateCancelled();

  @override
  String toString() => 'Update download cancelled.';
}

/// Downloads an update APK into the app's private storage.
class UpdateDownload {
  HttpClient? _client;
  bool _cancelled = false;

  static Future<Directory> _dir() async =>
      Directory('${await AppDirs.data()}/updates');

  /// Removes any APK left over from a previous download.
  static Future<void> cleanup() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      return;
    }
  }

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  /// Returns the path of the downloaded APK. [onProgress] gets 0..1, or null
  /// when the server did not say how big the file is.
  Future<String> run(String url, {required void Function(double?) onProgress}) async {
    await cleanup();
    final dir = await _dir();
    await dir.create(recursive: true);
    final part = File('${dir.path}/pray-update.apk.part');
    final target = File('${dir.path}/pray-update.apk');
    final client = _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'pray-update-download';
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('status ${response.statusCode}');
      }
      final total = response.contentLength > 0 ? response.contentLength : null;
      var received = 0;
      onProgress(total == null ? null : 0);
      sink = part.openWrite();
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (total != null && received != total) {
        throw const HttpException('incomplete download');
      }
      await part.rename(target.path);
      return target.path;
    } on Object {
      if (_cancelled) throw const UpdateCancelled();
      rethrow;
    } finally {
      client.close(force: true);
      _client = null;
      try {
        await sink?.close();
        if (await part.exists()) await part.delete();
      } on Object {
        // best effort
      }
    }
  }
}
