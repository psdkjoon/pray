import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pray/app.dart';
import 'package:pray/app_info.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/core/kv_store.dart';
import 'package:pray/core/startup_log.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/platform/autostart_service.dart';
import 'package:pray/platform/launcher_icon_service.dart';
import 'package:pray/platform/notification_service.dart';
import 'package:pray/platform/quick_tile_service.dart';
import 'package:pray/platform/tray_service.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/ui/startup_failure_screen.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(_start, (error, stack) {
    unawaited(StartupLog.write(error, stack));
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(StartupLog.write(details.exception, details.stack));
    previousOnError?.call(details);
  };

  final KvStore store;
  final AppSettings settings;
  final ServersController servers;
  final ConnectionController connection;
  try {
    store = await KvStore.open();
    (settings, servers) = _loadState(store);
    connection = ConnectionController(servers: servers, settings: settings);
  } on Object catch (error, stack) {
    await StartupLog.write(error, stack);
    runApp(StartupFailureScreen(error: error, logPath: StartupLog.lastPath));
    return;
  }

  runApp(PrayApp(settings: settings, servers: servers, connection: connection));

  unawaited(_initPlatform(settings, servers, connection));
}

(AppSettings, ServersController) _loadState(KvStore store) {
  try {
    return (AppSettings.load(store), ServersController.load(store));
  } on Object catch (error, stack) {
    unawaited(StartupLog.write(error, stack));
    final fresh = KvStore.memory();
    return (AppSettings.load(fresh), ServersController.load(fresh));
  }
}

Future<void> _initPlatform(
  AppSettings settings,
  ServersController servers,
  ConnectionController connection,
) async {
  try {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } on Object {
      debugPrint('edge-to-edge unavailable');
    }

    LauncherIconService.init(
      settings,
      refreshOn: connection,
      canApply: () => connection.status == ConnectionStatus.disconnected,
    );

    NotificationService.follow<ConnectionStatus>(
      connection,
      () => connection.status,
      _connectionNotification,
    );

    final tasks = <Future<void>>[];

    if (Platform.isAndroid) {
      tasks.add(_initTile(connection));
    }

    if (Platform.isLinux || Platform.isWindows) {
      tasks.add(() async {
        settings.launchAtLogin = await AutostartService.isEnabled();
      }());
      tasks.add(TrayService(connection, settings).init());
    }

    await Future.wait(
      tasks.map((task) => task.catchError((Object _) {})),
    );

    if (settings.connectOnLaunch &&
        servers.servers.isNotEmpty &&
        connection.status == ConnectionStatus.disconnected) {
      unawaited(connection.toggle());
    }
  } on Object catch (error, stack) {
    unawaited(StartupLog.write(error, stack));
  }
}

Future<void> _initTile(ConnectionController connection) async {
  await QuickTileService.init(connection.toggle);
  await QuickTileService.enable();
  var last = _tileState(connection.status);
  await QuickTileService.setState(last);
  connection.addListener(() {
    final current = _tileState(connection.status);
    if (current == last) return;
    last = current;
    unawaited(QuickTileService.setState(current));
  });
}

TileState _tileState(ConnectionStatus status) => switch (status) {
      ConnectionStatus.disconnected => TileState.off,
      ConnectionStatus.connecting => TileState.busy,
      ConnectionStatus.connected => TileState.on,
    };

NotificationMessage? _connectionNotification(
  ConnectionStatus previous,
  ConnectionStatus current,
) {
  if (Platform.isAndroid) return null;
  return switch (current) {
    ConnectionStatus.connected => (
        title: '${AppInfo.name} is connected'.tr,
        body: 'Your traffic is routed through the proxy.'.tr,
      ),
    ConnectionStatus.disconnected when previous == ConnectionStatus.connected => (
        title: '${AppInfo.name} is disconnected'.tr,
        body: 'Your traffic is going directly.'.tr,
      ),
    _ => null,
  };
}
