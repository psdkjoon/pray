import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pray/core/crypto/x25519.dart';
import 'package:xray_config/xray_config.dart';

class WarpAccount {
  const WarpAccount({
    required this.secretKey,
    required this.publicKey,
    required this.address4,
    required this.address6,
    required this.reserved,
    required this.endpoint,
  });

  final String secretKey;
  final String publicKey;
  final String address4;
  final String address6;
  final List<int> reserved;
  final String endpoint;

  WarpConfig toConfig({String? endpointOverride}) => WarpConfig(
        secretKey: secretKey,
        publicKey: publicKey,
        address4: address4,
        address6: address6,
        reserved: reserved,
        endpoint: endpointOverride ?? endpoint,
      );

  Map<String, Object?> toJson() => {
        'secretKey': secretKey,
        'publicKey': publicKey,
        'address4': address4,
        'address6': address6,
        'reserved': reserved,
        'endpoint': endpoint,
      };

  static WarpAccount? fromJson(Map<String, Object?> json) {
    try {
      return WarpAccount(
        secretKey: json['secretKey']! as String,
        publicKey: json['publicKey']! as String,
        address4: json['address4']! as String,
        address6: json['address6'] as String? ?? '',
        reserved: (json['reserved'] as List?)?.cast<int>() ?? const [],
        endpoint: json['endpoint'] as String? ?? defaultEndpoint,
      );
    } on Object {
      return null;
    }
  }

  static const defaultEndpoint = '162.159.192.1:2408';
}

abstract class WarpService {
  static const _api = 'https://api.cloudflareclient.com/v0a1922/reg';

  static Future<WarpAccount> register() async {
    final pair = X25519KeyPair.generate();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(Uri.parse(_api));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, 'okhttp/3.12.1')
        ..set('CF-Client-Version', 'a-6.3-1922');
      request.add(
        utf8.encode(
          jsonEncode({
            'key': base64.encode(pair.publicKey),
            'install_id': '',
            'fcm_token': '',
            'tos': DateTime.now().toUtc().toIso8601String(),
            'type': 'Android',
            'model': 'PC',
            'locale': 'en_US',
          }),
        ),
      );
      final response = await request.close().timeout(
            const Duration(seconds: 25),
          );
      final body = await utf8.decodeStream(response);
      if (response.statusCode != 200) {
        throw HttpException('WARP registration failed (HTTP ${response.statusCode})');
      }
      final config = (jsonDecode(body) as Map<String, Object?>)['config']!
          as Map<String, Object?>;
      final peer = ((config['peers']! as List).first as Map)
          .cast<String, Object?>();
      final addresses =
          (config['interface']! as Map)['addresses']! as Map<String, Object?>;
      final clientId = config['client_id'] as String?;
      final reserved = clientId == null
          ? <int>[]
          : base64.decode(base64.normalize(clientId)).take(3).toList();
      return WarpAccount(
        secretKey: base64.encode(pair.privateKey),
        publicKey: peer['public_key']! as String,
        address4: addresses['v4']! as String,
        address6: addresses['v6'] as String? ?? '',
        reserved: reserved,
        endpoint: WarpAccount.defaultEndpoint,
      );
    } on TimeoutException {
      throw const HttpException('WARP registration timed out');
    } finally {
      client.close(force: true);
    }
  }
}
