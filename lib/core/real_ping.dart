import 'dart:async';
import 'dart:io';

import 'package:pray/core/xray_binary.dart';
import 'package:xray_config/xray_config.dart';

class RealPing {
  RealPing._(this._install);

  final XrayInstall _install;

  static const probeUrl = 'http://www.gstatic.com/generate_204';

  static Future<RealPing?> create() async {
    try {
      return RealPing._(await resolveXrayInstall());
    } on Object {
      return null;
    }
  }

  Future<int?> measure(
    ProxyServer proxy, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final port = await _freePort();
    if (port == null) return null;
    final dir = Directory('${_install.writableDir}/ping');
    await dir.create(recursive: true);
    final config = File('${dir.path}/ping-$port.json');
    Process? process;
    try {
      await config.writeAsString(
        buildXrayConfigJson(
          proxy,
          XrayConfigOptions(
            mixedPort: port,
            routing: RoutingProfile.global,
            logLevel: 'none',
          ),
        ),
      );
      process = await Process.start(
        _install.binaryPath,
        ['run', '-c', config.path],
        environment: _install.assetDir == null
            ? null
            : {'XRAY_LOCATION_ASSET': _install.assetDir!},
      );
      unawaited(process.stdout.drain<void>().catchError((Object _) {}));
      unawaited(process.stderr.drain<void>().catchError((Object _) {}));
      var exited = false;
      unawaited(process.exitCode.then((_) => exited = true));

      final deadline = DateTime.now().add(const Duration(seconds: 4));
      var listening = false;
      while (!listening && !exited && DateTime.now().isBefore(deadline)) {
        try {
          final socket = await Socket.connect(
            InternetAddress.loopbackIPv4,
            port,
            timeout: const Duration(milliseconds: 300),
          );
          socket.destroy();
          listening = true;
        } on Object {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }
      if (!listening) return null;

      final client = HttpClient()
        ..connectionTimeout = timeout
        ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
      try {
        final watch = Stopwatch()..start();
        final request = await client.getUrl(Uri.parse(probeUrl)).timeout(timeout);
        final response = await request.close().timeout(timeout);
        await response.drain<void>().timeout(timeout);
        watch.stop();
        if (response.statusCode == 204 || response.statusCode == 200) {
          return watch.elapsedMilliseconds;
        }
        return null;
      } finally {
        client.close(force: true);
      }
    } on Object {
      return null;
    } finally {
      process?.kill(ProcessSignal.sigkill);
      try {
        if (await config.exists()) await config.delete();
      } on Object {
        return null;
      }
    }
  }

  static Future<int?> _freePort() async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    } on Object {
      return null;
    }
  }

  static Future<void> measureMany<T>(
    List<T> items,
    ProxyServer Function(T item) proxyOf,
    void Function(T item, int? ms) onResult, {
    int workers = 6,
    bool Function()? cancelled,
  }) async {
    final ping = await create();
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        if (cancelled?.call() ?? false) return;
        final item = items[next++];
        final proxy = proxyOf(item);
        final ms = ping != null
            ? await ping.measure(proxy)
            : await _tcp(proxy.address, proxy.port);
        onResult(item, ms);
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }

  static Future<int?> _tcp(String host, int port) async {
    final watch = Stopwatch()..start();
    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      watch.stop();
      socket.destroy();
      return watch.elapsedMilliseconds;
    } on Object {
      return null;
    }
  }
}
