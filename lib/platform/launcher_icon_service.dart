import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pray/settings/app_settings.dart';

abstract class LauncherIconService {
  static const _channel = MethodChannel('pray/launcher_icon');
  static final _observer = _LifecycleObserver();
  static AppSettings? _settings;
  static bool Function() _canApply = () => true;
  static bool _background = false;
  static bool? _desired;
  static bool? _applied;

  static void init(
    AppSettings settings, {
    Listenable? refreshOn,
    bool Function()? canApply,
  }) {
    if (!Platform.isAndroid || _settings != null) return;
    _settings = settings;
    _canApply = canApply ?? _canApply;
    settings.addListener(_update);
    refreshOn?.addListener(() {
      if (_background) _flush();
    });
    WidgetsBinding.instance.addObserver(_observer);
    _update();
  }

  static void _update() {
    final settings = _settings;
    if (settings == null) return;
    _desired = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  static Future<void> _flush() async {
    final dark = _desired;
    if (dark == null || dark == _applied) return;
    if (!_canApply()) return;
    try {
      await _channel.invokeMethod<void>('set', {'dark': dark});
      _applied = dark;
    } on PlatformException {
      return;
    }
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() => LauncherIconService._update();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        LauncherIconService._background = false;
        LauncherIconService._update();
      case AppLifecycleState.paused:
        LauncherIconService._background = true;
        LauncherIconService._update();
        LauncherIconService._flush();
      case AppLifecycleState.inactive ||
            AppLifecycleState.hidden ||
            AppLifecycleState.detached:
        break;
    }
  }
}
