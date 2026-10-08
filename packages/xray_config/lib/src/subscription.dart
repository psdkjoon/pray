import 'dart:convert';

import 'package:xray_config/src/base64_utils.dart';
import 'package:xray_config/src/link_parser.dart';
import 'package:xray_config/src/models.dart';

class SubscriptionError {
  const SubscriptionError({required this.line, required this.message});

  final int line;
  final String message;
}

class SubscriptionResult {
  const SubscriptionResult({required this.servers, required this.errors});

  final List<ProxyServer> servers;
  final List<SubscriptionError> errors;
}

SubscriptionResult parseSubscription(String body) {
  var text = body.trim();
  if (!text.contains('://')) {
    text = tryDecodeBase64(text) ?? text;
  }

  final servers = <ProxyServer>[];
  final errors = <SubscriptionError>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('://')) {
      continue;
    }
    try {
      servers.add(parseLink(line));
    } on LinkFormatException catch (e) {
      errors.add(SubscriptionError(line: i + 1, message: e.message));
    }
  }
  return SubscriptionResult(servers: servers, errors: errors);
}
