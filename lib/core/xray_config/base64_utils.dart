import 'dart:convert';

String? tryDecodeBase64(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  if (cleaned.isEmpty) return null;
  final padding = (4 - cleaned.length % 4) % 4;
  try {
    return utf8.decode(base64.decode(cleaned + '=' * padding));
  } on FormatException {
    return null;
  }
}
