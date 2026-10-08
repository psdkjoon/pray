import 'dart:io';

import 'package:pray/core/xray_binary.dart';

abstract class GeoUpdater {
  static const _files = ['geoip.dat', 'geosite.dat'];
  static const _sources = [
    'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download',
    'https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release',
  ];

  static Future<DateTime?> lastUpdated() async {
    try {
      final dir = (await resolveXrayInstall()).assetDir;
      if (dir == null) return null;
      final file = File('$dir/geoip.dat');
      return await file.exists() ? await file.lastModified() : null;
    } on Object {
      return null;
    }
  }

  static Future<void> update({void Function(double?)? onProgress}) async {
    final dir = (await resolveXrayInstall()).assetDir;
    if (dir == null) throw const FileSystemException('No geo data folder.');

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      for (var index = 0; index < _files.length; index++) {
        final name = _files[index];
        Exception? lastError;
        var done = false;
        for (final source in _sources) {
          try {
            await _download(
              client,
              '$source/$name',
              '$dir/$name',
              (fraction) => onProgress?.call(
                fraction == null ? null : (index + fraction) / _files.length,
              ),
            );
            done = true;
            break;
          } on Exception catch (e) {
            lastError = e;
          }
        }
        if (!done) throw lastError ?? const HttpException('Download failed');
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _download(
    HttpClient client,
    String url,
    String destination,
    void Function(double?) onFraction,
  ) async {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final temp = File('$destination.part');
    final sink = temp.openWrite();
    final total = response.contentLength;
    var received = 0;
    onFraction(total > 0 ? 0 : null);
    try {
      await sink.addStream(
        response.map((chunk) {
          received += chunk.length;
          if (total > 0) onFraction(received / total);
          return chunk;
        }),
      );
      await sink.close();
    } on Object {
      await temp.delete().catchError((Object _) => temp);
      rethrow;
    }
    if (await temp.length() < 100 * 1024) {
      await temp.delete();
      throw const HttpException('Downloaded file is too small');
    }
    await temp.rename(destination);
  }
}
