import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;

class XrayInstall {
  const XrayInstall({
    required this.binaryPath,
    required this.writableDir,
    this.assetDir,
  });

  final String binaryPath;

  final String writableDir;

  final String? assetDir;
}

Future<XrayInstall> resolveXrayInstall() async {
  if (Platform.isLinux) return _LinuxXrayBinary.ensureExtracted();
  if (Platform.isAndroid) return _AndroidXrayBinary.resolve();
  throw UnsupportedError('No bundled xray for this platform.');
}

abstract class _LinuxXrayBinary {
  static const _assetDir = 'assets/xray/linux';
  static const _files = ['xray', 'geoip.dat', 'geosite.dat'];

  static String get _installDir =>
      '${Platform.environment['HOME']}/.local/share/pray/xray';

  static bool _isElf(List<int> bytes) =>
      bytes.length > 1024 * 1024 &&
      bytes[0] == 0x7f &&
      bytes[1] == 0x45 &&
      bytes[2] == 0x4c &&
      bytes[3] == 0x46;

  static Future<bool> _fileIsElf(File file) async {
    try {
      if (!await file.exists() || await file.length() < 1024 * 1024) {
        return false;
      }
      final head = await file.openRead(0, 4).expand((c) => c).toList();
      return head.length == 4 &&
          head[0] == 0x7f &&
          head[1] == 0x45 &&
          head[2] == 0x4c &&
          head[3] == 0x46;
    } on Object {
      return false;
    }
  }

  static Future<String?> _runFailure(String path) async {
    try {
      final result = await Process.run(path, ['version']);
      if (result.exitCode == 0) return null;
      return 'exit code ${result.exitCode}';
    } on ProcessException catch (e) {
      return e.message;
    } on Object catch (e) {
      return '$e';
    }
  }

  static const _machines = {
    'x86_64': 62,
    'amd64': 62,
    'aarch64': 183,
    'arm64': 183,
    'armv7l': 40,
    'i686': 3,
    'riscv64': 243,
  };

  static String _machineName(int m) => switch (m) {
        62 => 'x86_64',
        183 => 'aarch64',
        40 => 'arm',
        3 => 'x86',
        243 => 'riscv64',
        _ => 'machine $m',
      };

  static Future<int?> _elfMachine(File file) async {
    try {
      final head = await file.openRead(0, 20).expand((c) => c).toList();
      if (head.length < 20) return null;
      return head[18] | (head[19] << 8);
    } on Object {
      return null;
    }
  }

  static Future<String> _cpu() async {
    try {
      final r = await Process.run('uname', ['-m']);
      return '${r.stdout}'.trim();
    } on Object {
      return '';
    }
  }

  static Future<String?> _tryRun(String path) async {
    await Process.run('chmod', ['755', path]);
    var failure = await _runFailure(path);
    for (var i = 0; i < 3 && failure != null && failure.contains('busy'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      failure = await _runFailure(path);
    }
    return failure;
  }

  static Future<String?> _copyToExecutableDir(String source) async {
    final env = Platform.environment;
    final candidates = <String>[
      if (env['XDG_RUNTIME_DIR'] != null) '${env['XDG_RUNTIME_DIR']}/pray',
      '${env['HOME']}/.config/pray/bin',
      '${Directory.systemTemp.path}/pray-${env['USER'] ?? 'user'}',
    ];
    for (final dir in candidates) {
      try {
        await Directory(dir).create(recursive: true);
        final target = '$dir/xray';
        await File(source).copy('$target.tmp');
        await Process.run('chmod', ['755', '$target.tmp']);
        await File('$target.tmp').rename(target);
        if (await _runFailure(target) == null) return target;
      } on Object {
        continue;
      }
    }
    return null;
  }

  static Future<String?> _systemXray() async {
    try {
      final result = await Process.run('which', ['xray']);
      final path = '${result.stdout}'.trim();
      if (result.exitCode == 0 && path.isNotEmpty) return path;
    } on Object {
      return null;
    }
    return null;
  }

  static Future<XrayInstall> ensureExtracted() async {
    final dir = Directory(_installDir);
    await dir.create(recursive: true);

    String? binaryPath;
    for (final name in _files) {
      final file = File('${dir.path}/$name');
      final data = await rootBundle.load('$_assetDir/$name');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      if (name == 'xray') {
        if (!_isElf(bytes)) {
          if (await file.exists()) await file.delete();
          continue;
        }
        if (await _fileIsElf(file) && await file.length() == bytes.length) {
          binaryPath = file.path;
          continue;
        }
        await file.writeAsBytes(bytes, flush: true);
        binaryPath = file.path;
        continue;
      }

      if (await file.exists() && await file.length() == bytes.length) continue;
      await file.writeAsBytes(bytes, flush: true);
    }

    String? failure;
    if (binaryPath != null) {
      final machine = await _elfMachine(File(binaryPath));
      final cpu = await _cpu();
      final expected = _machines[cpu];
      if (expected != null && machine != null && machine != expected) {
        failure = 'built for ${_machineName(machine)}, this computer is $cpu';
      } else {
        failure = await _tryRun(binaryPath);
        if (failure != null) {
          final alt = await _copyToExecutableDir(binaryPath);
          if (alt != null) {
            final altFailure = await _tryRun(alt);
            if (altFailure == null) {
              binaryPath = alt;
              failure = null;
            } else {
              failure = '$failure; copy: $altFailure';
            }
          }
        }
      }
      if (failure != null) binaryPath = null;
    }
    if (binaryPath == null) {
      final system = await _systemXray();
      if (system != null && await _runFailure(system) == null) {
        binaryPath = system;
      }
    }
    if (binaryPath == null) {
      throw StateError(
        'The bundled xray cannot run on this computer'
        '${failure == null ? '' : ' ($failure)'}. '
        'Run scripts/fetch-xray.sh linux-64 and rebuild, or install xray '
        '(Arch: pacman -S xray).',
      );
    }

    return XrayInstall(
      binaryPath: binaryPath,
      writableDir: '${Platform.environment['HOME']}/.config/pray',
      assetDir: dir.path,
    );
  }
}

abstract class _AndroidXrayBinary {
  static const _channel = MethodChannel('pray/android_paths');

  static Future<XrayInstall> resolve() async {
    final paths = await _channel.invokeMapMethod<String, String>('resolve');
    final nativeLibraryDir = paths?['nativeLibraryDir'];
    final filesDir = paths?['filesDir'];
    if (nativeLibraryDir == null || filesDir == null) {
      throw StateError("Couldn't reach the Android native side.");
    }
    return XrayInstall(
      binaryPath: '$nativeLibraryDir/libxray.so',
      writableDir: filesDir,
      assetDir: await _extractGeoData('$filesDir/xray'),
    );
  }

  static Future<String?> _extractGeoData(String path) async {
    try {
      final dir = Directory(path);
      await dir.create(recursive: true);
      for (final name in const ['geoip.dat', 'geosite.dat']) {
        final file = File('$path/$name');
        if (await file.exists()) continue;
        final data = await rootBundle.load('assets/xray/linux/$name');
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      return path;
    } on Object {
      return null;
    }
  }
}
