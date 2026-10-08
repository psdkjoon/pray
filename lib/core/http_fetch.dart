import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<String> fetchText(
  String url, {
  Duration timeout = const Duration(seconds: 25),
  int maxBytes = 20 * 1024 * 1024,
  void Function(double?)? onProgress,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, 'pray');
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
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  } finally {
    client.close(force: true);
  }
}
