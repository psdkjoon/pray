import 'dart:convert';
import 'dart:typed_data';

const _eccPerBlock = <int>[
  -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26,
  26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
  28, 28, 28,
];

const _blockCount = <int>[
  -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17,
  17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
];

class QrCode {
  QrCode._(this.size, this._modules);

  final int size;
  final List<List<bool>> _modules;

  bool isDark(int x, int y) => _modules[y][x];

  static QrCode encode(String text) {
    final bytes = utf8.encode(text);
    var version = 1;
    while (true) {
      if (version > 40) throw const FormatException('Text is too long for a QR code');
      final capacity = _dataCapacityBits(version);
      final countBits = version < 10 ? 8 : 16;
      if (4 + countBits + bytes.length * 8 <= capacity) break;
      version++;
    }

    final bits = <int>[];
    void put(int value, int count) {
      for (var i = count - 1; i >= 0; i--) {
        bits.add((value >> i) & 1);
      }
    }

    put(0x4, 4);
    put(bytes.length, version < 10 ? 8 : 16);
    for (final b in bytes) {
      put(b, 8);
    }
    final capacity = _dataCapacityBits(version);
    final terminator = capacity - bits.length < 4 ? capacity - bits.length : 4;
    put(0, terminator);
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
    var pad = 0xEC;
    while (bits.length < capacity) {
      put(pad, 8);
      pad ^= 0xEC ^ 0x11;
    }
    final data = Uint8List(bits.length ~/ 8);
    for (var i = 0; i < bits.length; i++) {
      data[i >> 3] |= bits[i] << (7 - (i & 7));
    }

    final codewords = _interleave(data, version);
    return _build(version, codewords);
  }

  static int _rawModules(int ver) {
    var result = (16 * ver + 128) * ver + 64;
    if (ver >= 2) {
      final align = ver ~/ 7 + 2;
      result -= (25 * align - 10) * align - 55;
      if (ver >= 7) result -= 36;
    }
    return result;
  }

  static int _dataCapacityBits(int ver) {
    return (_rawModules(ver) ~/ 8 - _eccPerBlock[ver] * _blockCount[ver]) * 8;
  }

  static Uint8List _interleave(Uint8List data, int ver) {
    final blocks = _blockCount[ver];
    final eccLen = _eccPerBlock[ver];
    final raw = _rawModules(ver) ~/ 8;
    final shortBlocks = blocks - raw % blocks;
    final shortLen = raw ~/ blocks;
    final generator = _generator(eccLen);

    final result = <List<int>>[];
    var k = 0;
    for (var i = 0; i < blocks; i++) {
      final end = k + shortLen - eccLen + (i < shortBlocks ? 0 : 1);
      final block = data.sublist(k, end).toList();
      k = end;
      final ecc = _remainder(block, generator);
      if (i < shortBlocks) block.add(0);
      result.add([...block, ...ecc]);
    }

    final out = <int>[];
    for (var i = 0; i < result[0].length; i++) {
      for (var j = 0; j < result.length; j++) {
        if (i != shortLen - eccLen || j >= shortBlocks) out.add(result[j][i]);
      }
    }
    return Uint8List.fromList(out);
  }

  static int _mul(int x, int y) {
    var z = 0;
    for (var i = 7; i >= 0; i--) {
      z = (z << 1) ^ ((z >> 7) * 0x11D);
      z ^= ((y >> i) & 1) * x;
    }
    return z & 0xff;
  }

  static List<int> _generator(int degree) {
    final result = List<int>.filled(degree, 0);
    result[degree - 1] = 1;
    var root = 1;
    for (var i = 0; i < degree; i++) {
      for (var j = 0; j < degree; j++) {
        result[j] = _mul(result[j], root);
        if (j + 1 < degree) result[j] ^= result[j + 1];
      }
      root = _mul(root, 0x02);
    }
    return result;
  }

  static List<int> _remainder(List<int> data, List<int> generator) {
    final result = List<int>.filled(generator.length, 0, growable: true);
    for (final b in data) {
      final factor = b ^ result.removeAt(0);
      result.add(0);
      for (var i = 0; i < generator.length; i++) {
        result[i] ^= _mul(generator[i], factor);
      }
    }
    return result;
  }

  static QrCode _build(int ver, Uint8List codewords) {
    final size = ver * 4 + 17;
    final modules = List.generate(size, (_) => List<bool>.filled(size, false));
    final isFunction =
        List.generate(size, (_) => List<bool>.filled(size, false));

    void setModule(int x, int y, bool dark) {
      modules[y][x] = dark;
      isFunction[y][x] = true;
    }

    for (var i = 0; i < size; i++) {
      setModule(6, i, i % 2 == 0);
      setModule(i, 6, i % 2 == 0);
    }

    void finder(int cx, int cy) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
          final x = cx + dx;
          final y = cy + dy;
          if (x >= 0 && x < size && y >= 0 && y < size) {
            setModule(x, y, dist != 2 && dist != 4);
          }
        }
      }
    }

    finder(3, 3);
    finder(size - 4, 3);
    finder(3, size - 4);

    final positions = _alignmentPositions(ver, size);
    for (var i = 0; i < positions.length; i++) {
      for (var j = 0; j < positions.length; j++) {
        final last = positions.length - 1;
        if ((i == 0 && j == 0) || (i == 0 && j == last) || (i == last && j == 0)) {
          continue;
        }
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
            setModule(positions[i] + dx, positions[j] + dy, dist != 1);
          }
        }
      }
    }

    void formatBits(int mask) {
      final data = (0 << 3) | mask;
      var rem = data;
      for (var i = 0; i < 10; i++) {
        rem = (rem << 1) ^ ((rem >> 9) * 0x537);
      }
      final bits = ((data << 10) | rem) ^ 0x5412;
      bool bit(int i) => ((bits >> i) & 1) != 0;
      for (var i = 0; i <= 5; i++) {
        setModule(8, i, bit(i));
      }
      setModule(8, 7, bit(6));
      setModule(8, 8, bit(7));
      setModule(7, 8, bit(8));
      for (var i = 9; i < 15; i++) {
        setModule(14 - i, 8, bit(i));
      }
      for (var i = 0; i < 8; i++) {
        setModule(size - 1 - i, 8, bit(i));
      }
      for (var i = 8; i < 15; i++) {
        setModule(8, size - 15 + i, bit(i));
      }
      setModule(8, size - 8, true);
    }

    formatBits(0);

    if (ver >= 7) {
      var rem = ver;
      for (var i = 0; i < 12; i++) {
        rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
      }
      final bits = (ver << 12) | rem;
      for (var i = 0; i < 18; i++) {
        final dark = ((bits >> i) & 1) != 0;
        final a = size - 11 + i % 3;
        final b = i ~/ 3;
        setModule(a, b, dark);
        setModule(b, a, dark);
      }
    }

    var i = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (!isFunction[y][x] && i < codewords.length * 8) {
            modules[y][x] = ((codewords[i >> 3] >> (7 - (i & 7))) & 1) != 0;
            i++;
          }
        }
      }
    }

    void applyMask(int mask) {
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (isFunction[y][x]) continue;
          final invert = switch (mask) {
            0 => (x + y) % 2 == 0,
            1 => y % 2 == 0,
            2 => x % 3 == 0,
            3 => (x + y) % 3 == 0,
            4 => (x ~/ 3 + y ~/ 3) % 2 == 0,
            5 => x * y % 2 + x * y % 3 == 0,
            6 => (x * y % 2 + x * y % 3) % 2 == 0,
            _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
          };
          if (invert) modules[y][x] = !modules[y][x];
        }
      }
    }

    var bestMask = 0;
    var bestPenalty = 1 << 30;
    for (var mask = 0; mask < 8; mask++) {
      applyMask(mask);
      formatBits(mask);
      final penalty = _penalty(modules, size);
      if (penalty < bestPenalty) {
        bestPenalty = penalty;
        bestMask = mask;
      }
      applyMask(mask);
    }
    applyMask(bestMask);
    formatBits(bestMask);
    return QrCode._(size, modules);
  }

  static List<int> _alignmentPositions(int ver, int size) {
    if (ver == 1) return const [];
    final count = ver ~/ 7 + 2;
    final step = ver == 32
        ? 26
        : (ver * 8 + count * 3 + 5) ~/ (count * 4 - 4) * 2;
    final result = <int>[6];
    for (var pos = size - 7; result.length < count; pos -= step) {
      result.insert(1, pos);
    }
    return result;
  }

  static int _penalty(List<List<bool>> m, int size) {
    var result = 0;
    for (var y = 0; y < size; y++) {
      var run = 1;
      for (var x = 1; x < size; x++) {
        if (m[y][x] == m[y][x - 1]) {
          run++;
          if (run == 5) {
            result += 3;
          } else if (run > 5) {
            result++;
          }
        } else {
          run = 1;
        }
      }
    }
    for (var x = 0; x < size; x++) {
      var run = 1;
      for (var y = 1; y < size; y++) {
        if (m[y][x] == m[y - 1][x]) {
          run++;
          if (run == 5) {
            result += 3;
          } else if (run > 5) {
            result++;
          }
        } else {
          run = 1;
        }
      }
    }
    for (var y = 0; y < size - 1; y++) {
      for (var x = 0; x < size - 1; x++) {
        final c = m[y][x];
        if (c == m[y][x + 1] && c == m[y + 1][x] && c == m[y + 1][x + 1]) {
          result += 3;
        }
      }
    }
    var dark = 0;
    for (final row in m) {
      for (final cell in row) {
        if (cell) dark++;
      }
    }
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() + total - 1) ~/ total - 1;
    return result + k * 10;
  }
}
