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
        case 'toggleRequested':
          _events.add(AndroidVpnEvent.toggleRequested);
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

  static Future<void> reportState(String state) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setConnected', {
        'state': state,
      });
    } on PlatformException {
      return;
    }
  }

  static Future<bool> consumeToggle() async {
    if (!Platform.isAndroid) return false;
    _listen();
    return await _channel.invokeMethod<bool>('consumeToggle') ?? false;
  }
}

enum AndroidVpnEvent { revoked, toggleRequested }

class AndroidApp {
  const AndroidApp({required this.package, required this.label});

  final String package;
  final String label;
}
