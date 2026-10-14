import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

abstract class AndroidVpn {
  static const _channel = MethodChannel('pray/vpn');
  static final _events = StreamController<AndroidVpnEvent>.broadcast();
  static bool _listening = false;

  static Stream<AndroidVpnEvent> get events {
    _listen();
    return _events.stream;
  }

  static void _listen() {
    if (_listening || !Platform.isAndroid) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'revoked':
          _events.add(AndroidVpnEvent.revoked);
      }
    });
  }

  static Future<List<AndroidApp>> listApps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('listApps');
    return [
      for (final item in raw ?? const <Map<Object?, Object?>>[])
        AndroidApp(
          package: item['package']! as String,
          label: item['label']! as String,
        ),
    ];
  }

  static Future<int?> start({List<String> allowedApps = const []}) async {
    final fd = await _channel.invokeMethod<int>('start', {
      'allowed': allowedApps,
    });
    if (fd == null || fd < 0) return null;
    return fd;
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }
}

enum AndroidVpnEvent { revoked }

class AndroidApp {
  const AndroidApp({required this.package, required this.label});

  final String package;
  final String label;
}
