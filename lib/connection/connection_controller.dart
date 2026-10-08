import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:pray/core/adblock_lists.dart';
import 'package:pray/core/xray_binary.dart';
import 'package:pray/core/xray_runtime.dart';
import 'package:pray/platform/android_vpn.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:xray_config/xray_config.dart';

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
    if (Platform.isAndroid) {
      addListener(() {
        if (_reported == _status) return;
        _reported = _status;
        AndroidVpn.reportState(_status.name);
      });
      AndroidVpn.events.listen(_onVpnEvent);
      AndroidVpn.consumeToggle().then((requested) {
        if (requested) toggle();
      });
    }
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
  ConnectionStatus? _reported;

  ConnectionStatus get status => _status;
  Duration get elapsed => _elapsed;
  bool get isConnected => _status == ConnectionStatus.connected;
  ConnectionMode get mode => Platform.isAndroid ? ConnectionMode.tun : _mode;
  bool get canChangeMode =>
      !Platform.isAndroid && _status == ConnectionStatus.disconnected;

  String? get lastError => _lastError;

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

  Future<void> _connect() async {
    _status = ConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    final failure = await _attemptConnect();

    if (_disposed) return;

    if (failure == null) {
      _status = ConnectionStatus.connected;
      _elapsed = Duration.zero;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed += const Duration(seconds: 1);
        notifyListeners();
      });
    } else {
      _status = ConnectionStatus.disconnected;
      _lastError = failure;
    }
    notifyListeners();
  }

  Future<String?> _attemptConnect() async {
    final tun = mode == ConnectionMode.tun;
    final selected = _servers.selected;
    final warpMode = _settings.warpMode;
    final warp = _settings.warpAccount;
    if (warpMode != WarpMode.off && warp == null) {
      return 'Register a WARP account first (Routing, WARP).';
    }
    final standalone = warpMode == WarpMode.standalone;
    if (selected == null && !standalone) {
      return 'Add a server first.';
    }
    if (selected != null) {
      await _servers.ping(selected.id);
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

    final options = XrayConfigOptions(
      mixedPort: _settings.proxyPort,
      routing: _toRoutingProfile(_settings.routingPreset),
      blockAds: _settings.blockAds,
      allowLan: _settings.allowLan,
      geoDataAvailable: install.assetDir != null,
      tunMode: tun,
      tunSystemRoutes: tun && Platform.isLinux,
      socketMark: tun && Platform.isLinux ? 255 : null,
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
      return null;
    } on XrayStartFailure catch (e) {
      if (tun && Platform.isAndroid) await AndroidVpn.stop();
      return e.message;
    }
  }

  Future<void> _disconnect() async {
    _ticker?.cancel();
    _elapsed = Duration.zero;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
    await Future.wait([
      _runtime.stop(),
      if (Platform.isAndroid && mode == ConnectionMode.tun) AndroidVpn.stop(),
    ]);
  }

  void _onVpnEvent(AndroidVpnEvent event) {
    switch (event) {
      case AndroidVpnEvent.revoked:
        if (!isConnected) return;
        _lastError = 'The VPN was turned off by Android.';
        unawaited(_disconnect());
      case AndroidVpnEvent.toggleRequested:
        AndroidVpn.consumeToggle();
        toggle();
    }
  }

  void _onUnexpectedExit() {
    if (_disposed || !isConnected) return;
    _ticker?.cancel();
    _elapsed = Duration.zero;
    _status = ConnectionStatus.disconnected;
    _lastError = 'xray stopped unexpectedly. Check the log for details.';
    notifyListeners();
    if (Platform.isAndroid && mode == ConnectionMode.tun) {
      unawaited(AndroidVpn.stop());
    }
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
    _ticker?.cancel();
    unawaited(_runtime.stop());
    super.dispose();
  }
}
