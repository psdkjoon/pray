import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pray/app.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/core/kv_store.dart';
import 'package:pray/platform/autostart_service.dart';
import 'package:pray/platform/launcher_icon_service.dart';
import 'package:pray/platform/notification_service.dart';
import 'package:pray/platform/tray_service.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await KvStore.open();
  final settings = AppSettings.load(store);
  final servers = ServersController.load(store);
  final connection = ConnectionController(
    servers: servers,
    settings: settings,
  );

  runApp(
    PRayApp(settings: settings, servers: servers, connection: connection),
  );

  unawaited(_initPlatform(settings, servers, connection));
}

Future<void> _initPlatform(
  AppSettings settings,
  ServersController servers,
  ConnectionController connection,
) async {
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } on Object {
    debugPrint('edge-to-edge unavailable');
  }

  LauncherIconService.init(settings, connection);

  NotificationService.follow(connection);

  final tasks = <Future<void>>[];

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
}
