import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pray/app_info.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/platform/app_icon.dart';
import 'package:pray/platform/window_service.dart';
import 'package:pray/settings/app_settings.dart';

class TrayService with WidgetsBindingObserver {
  TrayService(this._connection, this._settings);

  final ConnectionController _connection;
  final AppSettings _settings;
  bool? _dark;
  String? _iconKey;
  ConnectionStatus? _menuStatus;
  static const _channel = MethodChannel('pray/tray');
  bool _initialized = false;

  Future<void> init() async {
    if ((!Platform.isLinux && !Platform.isWindows) || _initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_onCall);
    _dark = _isDark;
    _iconKey = _stateKey(_dark!);
    await _channel.invokeMethod<void>('create', {
      ...await _iconArgs(_dark!),
      'title': AppInfo.name,
    });
    await _rebuildMenu();

    _menuStatus = _connection.status;
    _connection.addListener(() {
      unawaited(_syncIcon());
      if (_connection.status == _menuStatus) return;
      _menuStatus = _connection.status;
      unawaited(_rebuildMenu());
    });
    _settings.addListener(_syncIcon);
    _settings.addListener(_syncLanguage);
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _isDark => switch (_settings.themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  bool _quitting = false;

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (_quitting) return AppExitResponse.exit;
    unawaited(WindowService.instance.hide());
    return AppExitResponse.cancel;
  }

  String? _menuLanguage;

  void _syncLanguage() {
    if (_menuLanguage == L10n.code) return;
    _menuLanguage = L10n.code;
    unawaited(_rebuildMenu());
  }

  @override
  void didChangePlatformBrightness() => _syncIcon();

  String _stateKey(bool dark) => '${dark ? 'd' : 'l'}-$_dotState';

  String get _dotState {
    if (_connection.status != ConnectionStatus.connected) return 'off';
    return _connection.mode == ConnectionMode.tun ? 'tun' : 'proxy';
  }

  bool _syncing = false;

  Future<void> _syncIcon() async {
    final dark = _isDark;
    final key = _stateKey(dark);
    if (key == _iconKey || _syncing) return;
    _syncing = true;
    try {
      _dark = dark;
      _iconKey = key;
      await _channel.invokeMethod<void>('setIcon', await _iconArgs(dark));
    } finally {
      _syncing = false;
    }
    if (_stateKey(_isDark) != _iconKey) unawaited(_syncIcon());
  }

  Color _dotColor(bool dark) => switch (_dotState) {
        'tun' => dark ? const Color(0xFFA6E3A1) : const Color(0xFF40A02B),
        'proxy' => dark ? const Color(0xFFF9E2AF) : const Color(0xFFDF8E1D),
        _ => dark ? const Color(0xFFF38BA8) : const Color(0xFFD20F39),
      };

  Future<ui.Image> _renderDot(Uint8List png, bool dark, {int? size}) async {
    final codec = await ui.instantiateImageCodec(
      png,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    final radius = w * 0.2;
    final center = Offset(w - radius - w * 0.02, h - radius - h * 0.02);
    canvas.drawCircle(
      center,
      radius + w * 0.045,
      Paint()
        ..color = dark ? const Color(0xFF11111B) : const Color(0xFFFFFFFF)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _dotColor(dark)
        ..isAntiAlias = true,
    );
    return recorder.endRecording().toImage(image.width, image.height);
  }

  Future<Uint8List> _withDot(Uint8List png, bool dark) async {
    final out = await _renderDot(png, dark);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Arguments describing the icon for the native side: a PNG file on Linux,
  /// raw pixels on Windows.
  Future<Map<String, Object>> _iconArgs(bool dark) async {
    if (Platform.isWindows) {
      final bytes = await rootBundle.load(
        dark ? AppIcon.trayMocha : AppIcon.trayLatte,
      );
      const size = 32;
      final image = await _renderDot(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        dark,
        size: size,
      );
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return {
        'width': image.width,
        'height': image.height,
        'rgba': data!.buffer.asUint8List(),
      };
    }
    return {'icon': await _iconFilePath(dark)};
  }

  Future<String> _iconFilePath(bool dark) async {
    final bytes = await rootBundle.load(
      dark ? AppIcon.trayMocha : AppIcon.trayLatte,
    );
    final png = await _withDot(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      dark,
    );
    final file = File(
      '${Directory.systemTemp.path}/${AppInfo.name.toLowerCase()}-tray-${dark ? 'dark' : 'light'}-$_dotState.png',
    );
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

  Future<void> _rebuildMenu() async {
    final connected = _connection.isConnected;
    final connecting = _connection.status == ConnectionStatus.connecting;
    await _channel.invokeMethod<void>('setMenu', [
      {'key': 'show', 'label': 'Show ${AppInfo.name}'.tr, 'enabled': true},
      {'separator': true},
      {
        'key': 'status',
        'label': switch (_connection.status) {
          ConnectionStatus.disconnected => 'Disconnected'.tr,
          ConnectionStatus.connecting => 'Connecting…'.tr,
          ConnectionStatus.connected => 'Connected'.tr,
        },
        'enabled': false,
      },
      {'separator': true},
      {
        'key': 'toggle',
        'label': (connected ? 'Disconnect' : 'Connect').tr,
        'enabled': !connecting,
      },
      {'separator': true},
      {'key': 'quit', 'label': 'Quit'.tr, 'enabled': true},
    ]);
  }

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'activate':
        unawaited(WindowService.instance.toggleVisible());
      case 'menuClick':
        switch (call.arguments as String) {
          case 'toggle':
            unawaited(_connection.toggle());
          case 'show':
            unawaited(WindowService.instance.show());
          case 'quit':
            _quitting = true;
            unawaited(WindowService.instance.quit());
        }
    }
  }
}
