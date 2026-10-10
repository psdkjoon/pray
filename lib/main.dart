import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pray/app.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/core/kv_store.dart';
import 'package:pray/core/startup_log.dart';
import 'package:pray/platform/autostart_service.dart';
import 'package:pray/platform/launcher_icon_service.dart';
import 'package:pray/platform/notification_service.dart';
import 'package:pray/platform/tray_service.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';

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
    runApp(_StartupFailure(error: error, logPath: StartupLog.lastPath));
    return;
  }

  runApp(
    PRayApp(settings: settings, servers: servers, connection: connection),
  );

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
  } on Object catch (error, stack) {
    unawaited(StartupLog.write(error, stack));
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error, required this.logPath});

  final Object error;
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pray could not start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '$error'
                      '${logPath == null ? '' : '\n\nDetails were saved to:\n$logPath'}'
                      '\n\nPlease report this at github.com/psdkjoon.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
