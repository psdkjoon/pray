import 'dart:io';

import 'package:flutter/services.dart';

enum TileState { off, busy, on }

abstract class QuickTileService {
  static const _channel = MethodChannel('pray/tile');

  static Future<void> Function()? _onToggle;

  static Future<void> init(Future<void> Function() onToggle) async {
    if (!Platform.isAndroid) return;
    _onToggle = onToggle;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'toggleRequested') return;
      await _onToggle?.call();
    });
    await _consume();
  }

  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } on PlatformException {
      return;
    }
  }

  static Future<void> setState(TileState state) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setState', {'state': state.name});
    } on PlatformException {
      return;
    }
  }

  static Future<void> toast(String message) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('toast', {'message': message});
    } on PlatformException {
      return;
    }
  }

  static Future<void> _consume() async {
    try {
      final pending = await _channel.invokeMethod<bool>('consumeToggle');
      if (pending ?? false) await _onToggle?.call();
    } on PlatformException {
      return;
    }
  }
}
