import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:pray/core/xray_binary.dart';
import 'package:pray/core/xray_config/xray_config.dart';

class RealPing {
  RealPing._(this._install);

  final XrayInstall _install;

  static const probeUrl = 'http://www.gstatic.com/generate_204';

  static const _batchSize = 32;
  static const _minBatch = 12;
  static const _tcpTimeout = Duration(milliseconds: 1800);
  static const _probeTimeout = Duration(seconds: 5);
  static const _startTimeout = Duration(seconds: 4);
  static const _startPoll = Duration(milliseconds: 40);

  static int get _parallelBatches {
    if (Platform.isAndroid) return 3;
    return (Platform.numberOfProcessors ~/ 2).clamp(2, 6);
  }

  static int get _tcpParallel => Platform.isAndroid ? 160 : 256;

  static Future<bool>? _plainVlessRefused;

  Future<bool> refusesPlainVless() => _plainVlessRefused ??= _probePlainVless();

  Future<bool> _probePlainVless() async {
    final ports = await _freePorts(1);
    if (ports == null) return false;
    final dir = Directory('${_install.writableDir}/ping');
    final file = File('${dir.path}/probe-vless-${ports.first}.json');
    Process? process;
    try {
      await dir.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'log': {'loglevel': 'none'},
          'inbounds': [
            {
              'listen': '127.0.0.1',
              'port': ports.first,
              'protocol': 'http',
              'settings': <String, Object?>{},
            },
          ],
          'outbounds': [
            {
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': '203.0.113.7',
                    'port': 443,
                    'users': [
                      {
                        'id': '00000000-0000-4000-8000-000000000000',
                        'encryption': 'none',
                      },
                    ],
                  },
                ],
              },
              'streamSettings': {'network': 'tcp', 'security': 'none'},
            },
          ],
        }),
      );
      process = await Process.start(
        _install.binaryPath,
        ['run', '-c', file.path],
        environment: _install.assetDir == null
            ? null
            : {'XRAY_LOCATION_ASSET': _install.assetDir!},
      );
      final output = StringBuffer();
      for (final stream in [process.stdout, process.stderr]) {
        stream
            .transform(utf8.decoder)
            .listen(output.write, onError: (Object _) {});
      }
      var exited = false;
      unawaited(process.exitCode.then((_) => exited = true));
      if (await _waitListening(ports.first, () => exited)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return output.toString().contains('prohibited');
    } on Object {
      return false;
    } finally {
      process?.kill(ProcessSignal.sigkill);
      await _remove(file);
    }
  }

  static Future<RealPing?> create() async {
    try {
      return RealPing._(await resolveXrayInstall());
    } on Object {
      return null;
    }
  }

  Future<int?> measure(
    ProxyServer proxy, {
    Duration timeout = _probeTimeout,
  }) async {
    final results = await _measureBatch([proxy], timeout: timeout);
    return results?.first;
  }

  Future<List<int?>?> _measureBatch(
    List<ProxyServer> proxies, {
    Duration timeout = _probeTimeout,
    void Function(int index, int? ms)? onEach,
  }) async {
    final ports = await _freePorts(proxies.length);
    if (ports == null) return null;
    final dir = Directory('${_install.writableDir}/ping');
    await dir.create(recursive: true);
    final config = File('${dir.path}/ping-${ports.first}.json');
    Process? process;
    try {
      await config.writeAsString(
        jsonEncode(buildPingConfig(proxies, ports)),
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

      if (!await _waitListening(ports.last, () => exited)) return null;

      final results = List<int?>.filled(proxies.length, null);
      await Future.wait([
        for (var i = 0; i < proxies.length; i++)
          _probe(ports[i], timeout).then((ms) {
            results[i] = ms;
            onEach?.call(i, ms);
          }),
      ]);
      return results;
    } on Object {
      return null;
    } finally {
      process?.kill(ProcessSignal.sigkill);
      await _remove(config);
    }
  }

  static Future<void> _remove(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object catch (_) {
      return;
    }
  }

  static Future<void> _closeQuietly(ServerSocket socket) async {
    try {
      await socket.close();
    } on Object catch (_) {
      return;
    }
  }

  static Future<bool> _waitListening(int port, bool Function() exited) async {
    final deadline = DateTime.now().add(_startTimeout);
    while (!exited() && DateTime.now().isBefore(deadline)) {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 200),
        );
        socket.destroy();
        return true;
      } on Object {
        await Future<void>.delayed(_startPoll);
      }
    }
    return false;
  }

  static Future<int?> _probe(int port, Duration timeout) async {
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
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<int>?> _freePorts(int count) async {
    final sockets = <ServerSocket>[];
    try {
      for (var i = 0; i < count; i++) {
        sockets.add(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
      }
      return [for (final socket in sockets) socket.port];
    } on Object {
      return null;
    } finally {
      for (final socket in sockets) {
        await _closeQuietly(socket);
      }
    }
  }

  static Future<void> measureMany<T>(
    List<T> items,
    ProxyServer Function(T item) proxyOf,
    void Function(T item, int? ms) onResult, {
    bool Function()? cancelled,
    Duration probeTimeout = _probeTimeout,
    bool skipTcp = false,
  }) async {
    if (items.isEmpty) return;
    bool stop() => cancelled?.call() ?? false;

    final reported = HashSet<T>.identity();
    void report(T item, int? ms) {
      if (reported.add(item)) onResult(item, ms);
    }

    final ping = await create();
    final refused = ping == null ? false : await ping.refusesPlainVless();
    final tcpCache = <String, Future<int?>>{};
    final ready = <T>[];
    var tcpFinished = false;
    Completer<void>? wake;

    void signal() {
      final waiting = wake;
      wake = null;
      waiting?.complete();
    }

    Future<List<T>?> nextBatch() async {
      while (true) {
        if (stop()) return null;
        if (ready.length >= _minBatch || (tcpFinished && ready.isNotEmpty)) {
          final take = ready.length < _batchSize ? ready.length : _batchSize;
          final batch = ready.sublist(0, take);
          ready.removeRange(0, take);
          return batch;
        }
        if (tcpFinished) return null;
        final waiting = wake ??= Completer<void>();
        await waiting.future;
      }
    }

    Future<void> tcpStage() async {
      await _forEachLimited<T>(items, _tcpParallel, (item) async {
        if (stop()) return;
        final proxy = proxyOf(item);
        if (refused && proxy.isPlainVless) {
          report(item, null);
          return;
        }
        if (skipTcp || !_usesTcp(proxy)) {
          if (ping == null) {
            report(item, null);
          } else {
            ready.add(item);
            signal();
          }
          return;
        }
        final ms = await tcpCache.putIfAbsent(
          '${proxy.address}:${proxy.port}',
          () => _tcp(proxy.address, proxy.port),
        );
        if (ms == null) {
          report(item, null);
        } else if (ping == null) {
          report(item, ms);
        } else {
          ready.add(item);
          signal();
        }
      });
      tcpFinished = true;
      signal();
    }

    Future<void> worker() async {
      if (ping == null) return;
      while (true) {
        final batch = await nextBatch();
        if (batch == null) return;
        await _measureSplit<T>(ping, batch, proxyOf, report, stop, probeTimeout);
      }
    }

    await Future.wait([
      tcpStage(),
      for (var i = 0; i < _parallelBatches; i++) worker(),
    ]);
  }

  static Future<void> _measureSplit<T>(
    RealPing ping,
    List<T> batch,
    ProxyServer Function(T item) proxyOf,
    void Function(T item, int? ms) report,
    bool Function() stop,
    Duration probeTimeout,
  ) async {
    if (stop()) return;
    final results = await ping._measureBatch(
      [for (final item in batch) proxyOf(item)],
      timeout: probeTimeout,
      onEach: (index, ms) => report(batch[index], ms),
    );
    if (results != null) return;
    if (batch.length == 1) {
      report(batch.first, null);
      return;
    }
    final middle = batch.length ~/ 2;
    await Future.wait([
      _measureSplit<T>(
        ping,
        batch.sublist(0, middle),
        proxyOf,
        report,
        stop,
        probeTimeout,
      ),
      _measureSplit<T>(
        ping,
        batch.sublist(middle),
        proxyOf,
        report,
        stop,
        probeTimeout,
      ),
    ]);
  }

  static bool _usesTcp(ProxyServer proxy) {
    final stream = proxy.stream;
    if (stream.transport == Transport.kcp) return false;
    return !stream.alpn.contains('h3');
  }

  static Future<void> _forEachLimited<E>(
    List<E> items,
    int limit,
    Future<void> Function(E item) action,
  ) async {
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        await action(items[next++]);
      }
    }

    await Future.wait([
      for (var i = 0; i < limit && i < items.length; i++) worker(),
    ]);
  }

  static Future<int?> _tcp(String host, int port) async {
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: _tcpTimeout);
      watch.stop();
      socket.destroy();
      return watch.elapsedMilliseconds;
    } on Object {
      return null;
    }
  }
}
