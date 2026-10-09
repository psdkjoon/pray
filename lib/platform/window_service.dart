import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class WindowService {
  static final WindowService instance = WindowService._();

  WindowService._();

  static const _channel = MethodChannel('pray/window');

  Future<void> _call(String method) async {
    if (!Platform.isLinux && !Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      return;
    }
  }

  Future<void> show() => _call('show');

  Future<void> hide() => _call('hide');

  Future<void> toggleVisible() => _call('toggle');

  Future<void> quit() => _call('quit');
}
