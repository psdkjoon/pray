import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pray/settings/app_settings.dart';

abstract class ThemeSyncService {
  static const _channel = MethodChannel('pray/theme_sync');
  static AppSettings? _settings;
  static Future<void> _queue = Future.value();
  static String? _sent;
  static bool _wasEnabled = false;

  static Future<void> init(AppSettings settings) {
    if (!Platform.isAndroid || _settings != null) return Future.value();
    _settings = settings;
    _wasEnabled = settings.syncAppearance;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'refresh') await _run(pull: true);
      return null;
    });
    settings.addListener(_onSettings);
    return _run(pull: true);
  }

  static String _key(AppSettings s) =>
      '${s.syncAppearance}|${s.accent}|${s.themeMode.name}|${s.appearanceUpdatedAt}';

  static void _onSettings() {
    final settings = _settings;
    if (settings == null) return;
    final key = _key(settings);
    if (key == _sent) return;
    final turnedOn = settings.syncAppearance && !_wasEnabled;
    _wasEnabled = settings.syncAppearance;
    unawaited(_run(pull: turnedOn));
  }

  static Future<void> _run({required bool pull}) {
    return _queue = _queue.then((_) => _sync(pull: pull));
  }

  static Future<void> _sync({required bool pull}) async {
    final settings = _settings;
    if (settings == null) return;
    try {
      _sent = _key(settings);
      var state = await _channel.invokeMapMethod<String, Object?>('publish', {
        'enabled': settings.syncAppearance,
        'accent': settings.accent,
        'mode': settings.themeMode.name,
        'updatedAt': settings.appearanceUpdatedAt,
      });
      if (pull && settings.syncAppearance) {
        state = await _channel.invokeMapMethod<String, Object?>('pull') ?? state;
      }
      _adopt(settings, state);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static void _adopt(AppSettings settings, Map<String, Object?>? state) {
    if (state == null || !settings.syncAppearance) return;
    final accent = state['accent'];
    final updatedAt = state['updatedAt'];
    if (accent is! String || updatedAt is! num) return;
    final mode = state['mode'];
    if (updatedAt.toInt() > settings.appearanceUpdatedAt) {
      settings.adoptAppearance(
        accent,
        mode is String ? mode : null,
        updatedAt.toInt(),
      );
    }
  }
}
