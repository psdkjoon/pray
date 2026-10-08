import 'dart:async';
import 'dart:convert';
import 'dart:io';

class XrayStartFailure implements Exception {
  const XrayStartFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const _helperScript = r'''
BIN="$1"
CFG="$2"
p=""
w=""
cleanup() {
  ip rule del fwmark 255 lookup 1001 pref 100 2>/dev/null
  ip route flush table 1001 2>/dev/null
  ip link del xray0 2>/dev/null
}
stop_xray() {
  if [ -n "$w" ]; then
    kill $w 2>/dev/null
    w=""
  fi
  if [ -n "$p" ]; then
    kill $p 2>/dev/null
    i=0
    while kill -0 $p 2>/dev/null && [ $i -lt 15 ]; do
      sleep 0.2
      i=$((i+1))
    done
    kill -9 $p 2>/dev/null
    p=""
  fi
  cleanup
}
trap 'stop_xray' EXIT
trap 'exit 0' HUP INT TERM
echo pray-helper-ready
while read -r cmd; do
  case "$cmd" in
    start)
      stop_xray
      echo pray-ready
      ROUTE=$(ip -4 route show default 2>/dev/null | head -n 1)
      GW=$(echo "$ROUTE" | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}')
      DEV=$(echo "$ROUTE" | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
      if [ -n "$DEV" ]; then
        if [ -n "$GW" ]; then
          ip route replace default via "$GW" dev "$DEV" table 1001
        else
          ip route replace default dev "$DEV" table 1001
        fi
        ip rule del fwmark 255 lookup 1001 pref 100 2>/dev/null
        ip rule add fwmark 255 lookup 1001 pref 100
      fi
      "$BIN" run -c "$CFG" </dev/null &
      p=$!
      (
        i=0
        while [ $i -lt 50 ]; do
          if [ -d /sys/class/net/xray0 ]; then
            ip link set xray0 up 2>/dev/null
            ip addr replace 10.0.0.1/16 dev xray0 2>/dev/null
            ip route replace 0.0.0.0/1 dev xray0 2>/dev/null
            ip route replace 128.0.0.0/1 dev xray0 2>/dev/null
            echo pray-tun-up
            exit 0
          fi
          i=$((i+1))
          sleep 0.2
        done
        echo pray-tun-missing
      ) </dev/null &
      (
        while kill -0 $p 2>/dev/null; do
          sleep 1
        done
        echo pray-xray-exited
      ) </dev/null &
      w=$!
      ;;
    stop)
      stop_xray
      echo pray-stopped
      ;;
    quit)
      break
      ;;
  esac
done
''';

const _androidScript = r'''
exec 3<&0
"$1" run -c "$2" &
p=$!
echo "pray-pid $p"
(
  read -r _l <&3
  kill $p 2>/dev/null
  i=0
  while kill -0 $p 2>/dev/null && [ $i -lt 10 ]; do
    sleep 0.2
    i=$((i+1))
  done
  kill -9 $p 2>/dev/null
) &
w=$!
wait $p
kill $w 2>/dev/null
''';

class XrayRuntime {
  _Handle? _process;
  _Helper? _helper;
  int? _childPid;
  bool _controlled = false;
  final _unexpectedExitController = StreamController<void>.broadcast();

  bool get isRunning => _process != null;

  Stream<void> get onUnexpectedExit => _unexpectedExitController.stream;

  Future<void> start({
    required String binaryName,
    required String configJson,
    required String configPath,
    required String logPath,
    Map<String, String>? environment,
    bool elevated = false,
  }) async {
    if (_process != null) {
      throw const XrayStartFailure('xray is already running.');
    }

    final configFile = File(configPath);
    await configFile.parent.create(recursive: true);
    await configFile.writeAsString(configJson);

    if (!elevated) {
      await _validateConfig(
        binaryName: binaryName,
        configPath: configPath,
        environment: environment,
      );
    }
    await _launch(
      binaryName: binaryName,
      configPath: configPath,
      logPath: logPath,
      environment: environment,
      elevated: elevated,
    );
  }

  Future<void> _validateConfig({
    required String binaryName,
    required String configPath,
    Map<String, String>? environment,
  }) async {
    final ProcessResult result;
    try {
      result = await Process.run(
        binaryName,
        ['run', '-test', '-c', configPath],
        environment: environment,
      );
    } on ProcessException catch (e) {
      throw XrayStartFailure(
        'Could not run "$binaryName": ${e.message}. '
        'Is xray-core installed and on your PATH?',
      );
    }
    if (result.exitCode != 0) {
      throw XrayStartFailure(
        _firstUsefulLine('${result.stdout}\n${result.stderr}') ??
            'xray rejected the config (exit code ${result.exitCode}).',
      );
    }
  }

  Future<void> _launch({
    required String binaryName,
    required String configPath,
    required String logPath,
    Map<String, String>? environment,
    bool elevated = false,
  }) async {
    final _Handle process;
    try {
      if (elevated) {
        final helper = await _ensureHelper(
          binaryName: binaryName,
          configPath: configPath,
          environment: environment,
        );
        process = _HelperRun(helper);
      } else if (Platform.isAndroid) {
        process = _ProcessHandle(
          await Process.start(
            '/system/bin/sh',
            ['-c', _androidScript, 'sh', binaryName, configPath],
            environment: environment,
          ),
        );
      } else {
        process = _ProcessHandle(
          await Process.start(
            binaryName,
            ['run', '-c', configPath],
            environment: environment,
          ),
        );
      }
    } on ProcessException catch (e) {
      throw XrayStartFailure(
        elevated
            ? 'Could not ask for administrator permission: ${e.message}. '
                'Is polkit (pkexec) installed?'
            : 'Could not run "$binaryName": ${e.message}.',
      );
    }
    _process = process;
    _controlled = elevated || Platform.isAndroid;

    final logFile = File(logPath);
    final logSink = _SafeSink(logFile.openWrite());
    final startupLog = StringBuffer();
    var capturingStartup = true;

    final ready = Completer<void>();
    final tun = Completer<bool>();

    _childPid = null;

    void onOutput(String chunk) {
      final pid = RegExp(r'pray-pid (\d+)').firstMatch(chunk);
      if (pid != null) _childPid = int.parse(pid.group(1)!);
      if (!ready.isCompleted && chunk.contains('pray-ready')) {
        ready.complete();
      }
      if (!tun.isCompleted) {
        if (chunk.contains('pray-tun-up')) tun.complete(true);
        if (chunk.contains('pray-tun-missing')) tun.complete(false);
      }
      logSink.write(chunk);
      if (capturingStartup) startupLog.write(chunk);
    }

    process.output.listen(onOutput);
    process.begin();

    if (elevated) {
      final exited = await Future.any<int?>([
        process.exitCode,
        ready.future.then<int?>((_) => null),
      ]);
      if (exited != null) {
        _process = null;
        await logSink.close();
        throw XrayStartFailure(
          exited == 126 || exited == 127
              ? 'Administrator permission was not granted.'
              : _firstUsefulLine(startupLog.toString()) ??
                  'xray exited immediately (code $exited).',
        );
      }
    }

    if (elevated) {
      final up = await Future.any<bool>([
        tun.future,
        process.exitCode.then((_) => false),
      ]).timeout(const Duration(seconds: 15), onTimeout: () => false);
      if (!up) {
        capturingStartup = false;
        await stop();
        await logSink.close();
        throw XrayStartFailure(
          _firstUsefulLine(startupLog.toString()) ??
              'xray did not create the TUN interface.',
        );
      }
    }

    const startupWindow = Duration(milliseconds: 700);
    final earlyExitCode = await process.exitCode
        .then<int?>((code) => code)
        .timeout(startupWindow, onTimeout: () => null);

    capturingStartup = false;

    if (earlyExitCode != null) {
      _process = null;
      await logSink.close();
      throw XrayStartFailure(
        _firstUsefulLine(startupLog.toString()) ??
            'xray exited immediately (code $earlyExitCode). '
                'Is the proxy port already in use?',
      );
    }

    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) _process = null;
        unawaited(logSink.close());
        _unexpectedExitController.add(null);
      }),
    );
  }

  Future<_Helper> _ensureHelper({
    required String binaryName,
    required String configPath,
    Map<String, String>? environment,
  }) async {
    final env = [
      for (final e in environment?.entries ?? <MapEntry<String, String>>[])
        '${e.key}=${e.value}',
    ];
    final key = [binaryName, configPath, ...env].join('\u0000');
    final existing = _helper;
    if (existing != null && !existing.dead && existing.key == key) {
      return existing;
    }
    existing?.close();
    _helper = null;
    final process = await Process.start('pkexec', [
      'env',
      ...env,
      'sh',
      '-c',
      _helperScript,
      'sh',
      binaryName,
      configPath,
    ]);
    final helper = _Helper(process, key);
    final result = await helper.ready;
    if (result != null) {
      throw XrayStartFailure(
        result == 126 || result == 127
            ? 'Administrator permission was not granted.'
            : 'Could not start the administrator helper (code $result).',
      );
    }
    _helper = helper;
    return helper;
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) return;

    final childPid = _childPid;
    _childPid = null;
    if (Platform.isAndroid && childPid != null) {
      Process.killPid(childPid, ProcessSignal.sigkill);
    }

    if (_controlled) {
      try {
        await process.sendStop();
      } on Object {
        _childPid = null;
      }
    } else {
      process.kill(false);
    }
    final exitCode = await process.exitCode
        .then<int?>((code) => code)
        .timeout(
          Duration(seconds: _controlled ? 8 : 2),
          onTimeout: () => null,
        );
    if (exitCode == null && !_controlled) {
      process.kill(true);
    }
    _process = null;
  }

  String? _firstUsefulLine(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where(
          (l) =>
              l.isNotEmpty &&
              l != 'pray-ready' &&
              !l.startsWith('Xray ') &&
              !l.startsWith('pray-') &&
              !l.startsWith('Configuration OK'),
        )
        .toList();
    if (lines.isEmpty) return null;
    return lines.firstWhere(
      (l) => RegExp('fail|error|denied|permitted', caseSensitive: false)
          .hasMatch(l),
      orElse: () => lines.last,
    );
  }
}

class _SafeSink {
  _SafeSink(this._sink);

  final IOSink _sink;
  var _closed = false;

  void write(String chunk) {
    if (_closed) return;
    try {
      _sink.write(chunk);
    } catch (_) {
      _closed = true;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _sink.close();
    } catch (_) {}
  }
}

abstract class _Handle {
  Stream<String> get output;
  Future<int> get exitCode;
  void begin() {}
  Future<void> sendStop();
  void kill(bool force);
}

class _ProcessHandle extends _Handle {
  _ProcessHandle(this._process) {
    final controller = StreamController<String>();
    var open = 2;
    void done() {
      if (--open == 0) unawaited(controller.close());
    }

    _process.stdout.transform(utf8.decoder).listen(
          controller.add,
          onDone: done,
          onError: (Object _) => done(),
        );
    _process.stderr.transform(utf8.decoder).listen(
          controller.add,
          onDone: done,
          onError: (Object _) => done(),
        );
    output = controller.stream;
  }

  final Process _process;

  @override
  late final Stream<String> output;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> sendStop() async {
    _process.stdin.writeln('stop');
    await _process.stdin.flush();
    await _process.stdin.close();
  }

  @override
  void kill(bool force) {
    _process.kill(force ? ProcessSignal.sigkill : ProcessSignal.sigterm);
  }
}

class _Helper {
  _Helper(this.process, this.key) {
    process.stdout.transform(utf8.decoder).listen(_onChunk);
    process.stderr.transform(utf8.decoder).listen(_onChunk);
    process.exitCode.then((code) {
      dead = true;
      if (!_ready.isCompleted) _ready.complete(code);
      if (!_done.isCompleted) _done.complete(code);
    });
  }

  final Process process;
  final String key;
  bool dead = false;
  final _chunks = StreamController<String>.broadcast();
  final _ready = Completer<int?>();
  final _done = Completer<int>();

  Future<int?> get ready => _ready.future;
  Future<int> get done => _done.future;
  Stream<String> get chunks => _chunks.stream;

  void _onChunk(String chunk) {
    if (!_ready.isCompleted && chunk.contains('pray-helper-ready')) {
      _ready.complete(null);
    }
    _chunks.add(chunk);
  }

  void send(String command) {
    if (dead) return;
    try {
      process.stdin.writeln(command);
    } on Object {
      dead = true;
    }
  }

  void close() {
    if (dead) return;
    send('quit');
    unawaited(
      process.stdin.close().then<void>((_) {}, onError: (Object _) {}),
    );
  }
}

class _HelperRun extends _Handle {
  _HelperRun(this._helper) {
    _sub = _helper.chunks.listen((chunk) {
      _controller.add(chunk);
      if (chunk.contains('pray-xray-exited')) {
        _helper.send('stop');
        _finish(0);
      } else if (chunk.contains('pray-stopped')) {
        _finish(0);
      }
    });
    unawaited(_helper.done.then(_finish));
  }

  final _Helper _helper;
  final _controller = StreamController<String>();
  final _exit = Completer<int>();
  late final StreamSubscription<String> _sub;

  void _finish(int code) {
    if (_exit.isCompleted) return;
    _exit.complete(code);
    unawaited(_sub.cancel());
    unawaited(_controller.close());
  }

  @override
  Stream<String> get output => _controller.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void begin() => _helper.send('start');

  @override
  Future<void> sendStop() async => _helper.send('stop');

  @override
  void kill(bool force) => _helper.send('stop');
}
