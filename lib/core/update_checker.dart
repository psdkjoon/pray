import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pray/app_info.dart';
import 'package:pray/platform/system_service.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});

  final String version;
  final String url;
}

abstract class UpdateChecker {
  static const _versionUrl =
      'https://raw.githubusercontent.com/${AppInfo.githubHandle}/pray/main/VERSION';
  static String _releaseApi(String version) =>
      'https://api.github.com/repos/${AppInfo.githubHandle}/pray/releases/tags/v$version';
  static String _releasePage(String version) =>
      'https://github.com/${AppInfo.githubHandle}/pray/releases/tag/v$version';

  static Future<UpdateInfo?> check() async {
    try {
      final raw = (await _get(_versionUrl)).trim().split(RegExp(r'\s')).first;
      final remote = raw.replaceFirst(RegExp('^[vV]'), '');
      if (!_newer(remote, AppInfo.version)) return null;
      return UpdateInfo(version: remote, url: await _downloadUrl(remote));
    } on Object {
      return null;
    }
  }

  static Future<String> _get(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'pray-update-check';
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      request.headers.set('Accept', 'application/vnd.github+json, text/plain');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('status ${response.statusCode}');
      }
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  static bool _newer(String remote, String local) {
    List<int> parts(String v) => [
          for (final p in v.replaceFirst(RegExp('^[vV]'), '').split(RegExp(r'[+-]')).first.split('.'))
            int.tryParse(p) ?? 0,
        ];
    final a = parts(remote);
    final b = parts(local);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<String> _downloadUrl(String version) async {
    try {
      final key = await _deviceKey();
      final extension = Platform.isAndroid ? '.apk' : '.appimage';
      if (key == null) return _releasePage(version);
      final release = jsonDecode(await _get(_releaseApi(version)));
      final assets = (release as Map)['assets'] as List;
      for (final wanted in [key, if (Platform.isAndroid) 'universal']) {
        for (final asset in assets) {
          final name = '${(asset as Map)['name']}'.toLowerCase();
          if (name.endsWith(extension) && name.contains(wanted)) {
            return '${asset['browser_download_url']}';
          }
        }
      }
    } on Object {
      return _releasePage(version);
    }
    return _releasePage(version);
  }

  static Future<String?> _deviceKey() async {
    if (Platform.isAndroid) {
      final abi = await SystemService.androidAbi();
      return abi?.toLowerCase();
    }
    if (Platform.isLinux) {
      final result = await Process.run('uname', ['-m']);
      final machine = '${result.stdout}'.trim().toLowerCase();
      if (machine == 'arm64' || machine == 'aarch64') return 'aarch64';
      if (machine == 'x86_64' || machine == 'amd64') return 'x86_64';
      return machine.isEmpty ? null : machine;
    }
    return null;
  }
}
