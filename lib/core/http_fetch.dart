import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pray/app_info.dart';

class FetchResult {
  const FetchResult({required this.body, this.title});

  final String body;

  final String? title;
}

final _hasScheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://');

String normalizeWebLink(String text) {
  var link = text.trim();
  if (link.isEmpty || _hasScheme.hasMatch(link)) return link;
  while (link.startsWith('/')) {
    link = link.substring(1);
  }
  return link.isEmpty ? link : 'https://$link';
}

Future<String> fetchText(
  String url, {
  Duration timeout = const Duration(seconds: 25),
  int maxBytes = 20 * 1024 * 1024,
  void Function(double?)? onProgress,
}) async {
  final result = await fetchResponse(
    url,
    timeout: timeout,
    maxBytes: maxBytes,
    onProgress: onProgress,
  );
  return result.body;
}

Future<FetchResult> fetchResponse(
  String url, {
  Duration timeout = const Duration(seconds: 25),
  int maxBytes = 20 * 1024 * 1024,
  void Function(double?)? onProgress,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, AppInfo.packageName);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final total = response.contentLength;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(timeout)) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) {
        throw const HttpException('The file is too large');
      }
      if (total > 0) onProgress?.call(bytes.length / total);
    }
    return FetchResult(
      body: utf8.decode(bytes.takeBytes(), allowMalformed: true),
      title: _profileTitle(response.headers.value('profile-title')),
    );
  } finally {
    client.close(force: true);
  }
}

String? _profileTitle(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  try {
    if (value.toLowerCase().startsWith('base64:')) {
      final text = utf8
          .decode(base64.decode(base64.normalize(value.substring(7))))
          .trim();
      return text.isEmpty ? null : text;
    }
    final text = Uri.decodeComponent(value).trim();
    return text.isEmpty ? null : text;
  } on Object {
    return value;
  }
}
