import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:pray/core/adblock_lists.dart';
import 'package:pray/core/terminal_proxy.dart';
import 'package:pray/core/traffic_meter.dart';
import 'package:pray/core/xray_binary.dart';
import 'package:pray/core/xray_config/xray_config.dart';
import 'package:pray/core/xray_runtime.dart';
import 'package:pray/platform/android_vpn.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';

enum ConnectionStatus { disconnected, connecting, connected }

enum ConnectionMode { proxy, tun }

class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required ServersController servers,
    required AppSettings settings,
  })  : _servers = servers,
        _settings = settings,
        _mode = settings.tunMode ? ConnectionMode.tun : ConnectionMode.proxy {
    _runtime.onUnexpectedExit.listen((_) => _onUnexpectedExit());
    if (Platform.isAndroid) AndroidVpn.events.listen(_onVpnEvent);
    _servers.addListener(_onServersChanged);
  }

  final ServersController _servers;
  final AppSettings _settings;
  final _runtime = XrayRuntime();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionMode _mode;
  Duration _elapsed = Duration.zero;
  String? _lastError;
  Timer? _ticker;
  bool _disposed = false;
  Future<void> _pendingStop = Future.value();
  bool _revokedWhileConnecting = false;

  TrafficMeter? _meter;
  var _polling = false;
  TrafficSpeed _speed = (down: 0, up: 0);

  String? _activeServerKey;
  bool _restartQueued = false;

  ConnectionStatus get status => _status;
  Duration get elapsed => _elapsed;
  bool get isConnected => _status == ConnectionStatus.connected;
  ConnectionMode get mode {
    if (Platform.isAndroid) return ConnectionMode.tun;
    if (Platform.isWindows) return ConnectionMode.proxy;
    return _mode;
  }
  bool get canChangeMode =>
      !Platform.isAndroid &&
      !Platform.isWindows &&
      _status == ConnectionStatus.disconnected;

  String? get lastError => _lastError;

  TrafficSpeed get speed => _speed;

  void setMode(ConnectionMode mode) {
    if (!canChangeMode || mode == _mode) return;
    _mode = mode;
    _settings.tunMode = mode == ConnectionMode.tun;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_status == ConnectionStatus.connecting) return;
    if (isConnected) {
      await _disconnect();
      return;
    }
    await _connect();
  }

  String? _serverKey() {
    final server = _servers.selected;
    if (server == null) return null;
    return '${server.id}|${jsonEncode(server.proxy.toJson())}';
  }

  void _onServersChanged() {
    if (_disposed || _status == ConnectionStatus.disconnected) return;
    if (_serverKey() == _activeServerKey) return;
    if (_status == ConnectionStatus.connecting) {
      _restartQueued = true;
      return;
    }
    unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    if (_status != ConnectionStatus.connected) return;
    _ticker?.cancel();
    _stopMeter();
    _elapsed = Duration.zero;
    _status = ConnectionStatus.connecting;
    notifyListeners();
    await (_pendingStop = _stopEverything());
    await _connect();
  }

  Future<void> _connect() async {
    _restartQueued = false;
    _status = ConnectionStatus.connecting;
    _lastError = null;
    _revokedWhileConnecting = false;
    notifyListeners();

    String? failure;
    try {
      await _pendingStop;
      failure = await _attemptConnect();
      if (failure == null && _revokedWhileConnecting) {
        failure = 'The VPN was turned off by Android.';
      }
    } on Object catch (e) {
      failure = "Couldn't connect: $e";
    }

    if (failure != null) {
      _stopMeter();
      await _stopEverything();
    }

    if (_disposed) return;

    if (failure == null) {
      unawaited(TerminalProxy.write(_settings.proxyPort));
      _status = ConnectionStatus.connected;
      _elapsed = Duration.zero;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed += const Duration(seconds: 1);
        notifyListeners();
        unawaited(_pollSpeed());
      });
    } else {
      _status = ConnectionStatus.disconnected;
      _lastError = failure;
    }
    notifyListeners();

    if (failure == null && (_restartQueued || _serverKey() != _activeServerKey)) {
      unawaited(_reconnect());
    }
  }

  void _stopMeter() {
    _meter?.close();
    _meter = null;
    _speed = (down: 0, up: 0);
  }

  Future<void> _pollSpeed() async {
    final meter = _meter;
    if (meter == null || _polling) return;
    _polling = true;
    try {
      final next = await meter.poll();
      if (next == null || _disposed || !identical(meter, _meter)) return;
      _speed = next;
      notifyListeners();
    } finally {
      _polling = false;
    }
  }

  Future<int?> _freePort() async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    } on Object {
      return null;
    }
  }

  Future<String?> _attemptConnect() async {
    final tun = mode == ConnectionMode.tun;
    final selected = _servers.selected;
    _activeServerKey = _serverKey();
    final warpMode = _settings.warpMode;
    final warp = _settings.warpAccount;
    if (warpMode != WarpMode.off && warp == null) {
      return 'Register a WARP account first (Routing, WARP).';
    }
    final standalone = warpMode == WarpMode.standalone;
    if (selected == null && !standalone) {
      return 'Add a server first.';
    }
    final XrayInstall install;
    try {
      install = await resolveXrayInstall();
    } on Exception catch (e) {
      return "Couldn't prepare the xray binary: $e";
    }

    final blockDomains = <String>{};
    if (_settings.blockAds) {
      if (_settings.adBlock == AdBlockLevel.strict) {
        blockDomains.addAll(strictBuiltinDomains);
      }
      blockDomains.addAll(await AdBlockLists.load());
    }
    if (_settings.blockYoutubeAds) blockDomains.addAll(youtubeAdDomains);

    final metricsPort = await _freePort();
    final options = XrayConfigOptions(
      mixedPort: _settings.proxyPort,
      routing: _toRoutingProfile(_settings.routingPreset),
      blockAds: _settings.blockAds,
      allowLan: _settings.allowLan,
      geoDataAvailable: install.assetDir != null,
      tunMode: tun,
      tunSystemRoutes: tun && Platform.isLinux,
      socketMark: tun && Platform.isLinux ? 255 : null,
      metricsPort: metricsPort,
      customRules: _settings.customRules,
      blockDomains: blockDomains.toList(),
      remoteDns: _settings.dnsServerList,
      fakeDns: tun && _settings.fakeDns,
      warp: warp?.toConfig(endpointOverride: _settings.warpEndpoint),
      warpMode: warpMode,
      warpDomains: _settings.warpDomains,
    );
    final configJson = buildXrayConfigJson(selected?.proxy, options);

    int? tunFd;
    if (tun && Platform.isAndroid) {
      try {
        final perApp = _settings.perAppProxy;
        if (perApp && _settings.perAppPackages.isEmpty) {
          return 'Per-app proxy is on, but no apps are selected.';
        }
        tunFd = await AndroidVpn.start(
          allowedApps: perApp ? _settings.perAppPackages : const [],
        );
      } on PlatformException catch (e) {
        return e.message ?? "Couldn't start the VPN.";
      }
      if (tunFd == null) {
        return 'VPN permission was not granted.';
      }
    }

    final environment = <String, String>{
      if (install.assetDir != null) 'XRAY_LOCATION_ASSET': install.assetDir!,
      if (tunFd != null) 'XRAY_TUN_FD': '$tunFd',
    };

    try {
      await _runtime.start(
        binaryName: install.binaryPath,
        configJson: configJson,
        configPath: '${install.writableDir}/config.json',
        logPath: '${install.writableDir}/xray.log',
        environment: environment.isEmpty ? null : environment,
        elevated: tun && Platform.isLinux,
      );
      if (metricsPort != null) {
        _meter = TrafficMeter(
          port: metricsPort,
          ignoredOutbounds: {
            'block',
            if (warpMode == WarpMode.afterProxy) 'proxy',
          },
        );
      }
      return null;
    } on XrayStartFailure catch (e) {
      if (e.message.contains('vless without TLS')) {
        return 'This server has no encryption (VLESS without TLS) and your '
            'xray refuses it. Choose another server.';
      }
      return e.message;
    }
  }

  Future<void> _disconnect() {
    _ticker?.cancel();
    _stopMeter();
    _elapsed = Duration.zero;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
    return _pendingStop = _stopEverything();
  }

  Future<void> _stopEverything() async {
    final stopRuntime = _runtime.stop().catchError((Object _) {});
    final stopVpn = Platform.isAndroid
        ? AndroidVpn.stop().catchError((Object _) {})
        : Future<void>.value();
    await Future.wait([stopRuntime, stopVpn]);
  }

  void _onVpnEvent(AndroidVpnEvent event) {
    switch (event) {
      case AndroidVpnEvent.revoked:
        if (_status == ConnectionStatus.connecting) {
          _revokedWhileConnecting = true;
          return;
        }
        if (!isConnected) return;
        _lastError = 'The VPN was turned off by Android.';
        unawaited(_disconnect());
    }
  }

  void _onUnexpectedExit() {
    if (_disposed || !isConnected) return;
    _ticker?.cancel();
    _stopMeter();
    _elapsed = Duration.zero;
    _status = ConnectionStatus.disconnected;
    _lastError = 'xray stopped unexpectedly. Check the log for details.';
    notifyListeners();
    _pendingStop = _stopEverything();
  }

  RoutingProfile _toRoutingProfile(RoutingPreset preset) {
    return switch (preset) {
      RoutingPreset.global => RoutingProfile.global,
      RoutingPreset.bypassLan => RoutingProfile.bypassLan,
      RoutingPreset.bypassIran => RoutingProfile.bypassIran,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _servers.removeListener(_onServersChanged);
    _ticker?.cancel();
    _meter?.close();
    unawaited(_runtime.stop());
    super.dispose();
  }
}
