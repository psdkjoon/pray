import 'dart:typed_data';

final List<int> _sbox = _buildSbox();

List<int> _buildSbox() {
  final box = List<int>.filled(256, 0);
  var p = 1;
  var q = 1;
  do {
    p = p ^ ((p << 1) & 0xff) ^ ((p & 0x80) != 0 ? 0x1b : 0);
    q ^= q << 1;
    q ^= q << 2;
    q ^= q << 4;
    q &= 0xff;
    if ((q & 0x80) != 0) q ^= 0x09;
    final x = q ^
        _rotl8(q, 1) ^
        _rotl8(q, 2) ^
        _rotl8(q, 3) ^
        _rotl8(q, 4);
    box[p] = (x ^ 0x63) & 0xff;
  } while (p != 1);
  box[0] = 0x63;
  return box;
}

int _rotl8(int x, int n) => ((x << n) | (x >> (8 - n))) & 0xff;

int _xtime(int x) => ((x << 1) ^ ((x & 0x80) != 0 ? 0x1b : 0)) & 0xff;

class Aes256 {
  Aes256(List<int> key) : _roundKeys = _expand(key) {
    assert(key.length == 32);
  }

  final List<int> _roundKeys;

  static List<int> _expand(List<int> key) {
    final w = List<int>.filled(240, 0);
    for (var i = 0; i < 32; i++) {
      w[i] = key[i];
    }
    var rcon = 1;
    for (var i = 8; i < 60; i++) {
      var t0 = w[(i - 1) * 4];
      var t1 = w[(i - 1) * 4 + 1];
      var t2 = w[(i - 1) * 4 + 2];
      var t3 = w[(i - 1) * 4 + 3];
      if (i % 8 == 0) {
        final tmp = t0;
        t0 = _sbox[t1] ^ rcon;
        t1 = _sbox[t2];
        t2 = _sbox[t3];
        t3 = _sbox[tmp];
        rcon = _xtime(rcon);
      } else if (i % 8 == 4) {
        t0 = _sbox[t0];
        t1 = _sbox[t1];
        t2 = _sbox[t2];
        t3 = _sbox[t3];
      }
      w[i * 4] = w[(i - 8) * 4] ^ t0;
      w[i * 4 + 1] = w[(i - 8) * 4 + 1] ^ t1;
      w[i * 4 + 2] = w[(i - 8) * 4 + 2] ^ t2;
      w[i * 4 + 3] = w[(i - 8) * 4 + 3] ^ t3;
    }
    return w;
  }

  Uint8List encryptBlock(Uint8List input) {
    final s = Uint8List.fromList(input);
    _addRoundKey(s, 0);
    for (var round = 1; round < 14; round++) {
      _subBytes(s);
      _shiftRows(s);
      _mixColumns(s);
      _addRoundKey(s, round);
    }
    _subBytes(s);
    _shiftRows(s);
    _addRoundKey(s, 14);
    return s;
  }

  void _addRoundKey(Uint8List s, int round) {
    for (var i = 0; i < 16; i++) {
      s[i] ^= _roundKeys[round * 16 + i];
    }
  }

  void _subBytes(Uint8List s) {
    for (var i = 0; i < 16; i++) {
      s[i] = _sbox[s[i]];
    }
  }

  void _shiftRows(Uint8List s) {
    final t = Uint8List.fromList(s);
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        s[c * 4 + r] = t[((c + r) % 4) * 4 + r];
      }
    }
  }

  void _mixColumns(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final a0 = s[c * 4];
      final a1 = s[c * 4 + 1];
      final a2 = s[c * 4 + 2];
      final a3 = s[c * 4 + 3];
      s[c * 4] = _xtime(a0) ^ (_xtime(a1) ^ a1) ^ a2 ^ a3;
      s[c * 4 + 1] = a0 ^ _xtime(a1) ^ (_xtime(a2) ^ a2) ^ a3;
      s[c * 4 + 2] = a0 ^ a1 ^ _xtime(a2) ^ (_xtime(a3) ^ a3);
      s[c * 4 + 3] = (_xtime(a0) ^ a0) ^ a1 ^ a2 ^ _xtime(a3);
    }
  }

  Uint8List ctr(List<int> iv, List<int> data) {
    final counter = Uint8List.fromList(iv);
    final out = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += 16) {
      final stream = encryptBlock(counter);
      final end = offset + 16 < data.length ? offset + 16 : data.length;
      for (var i = offset; i < end; i++) {
        out[i] = data[i] ^ stream[i - offset];
      }
      for (var i = 15; i >= 0; i--) {
        counter[i] = (counter[i] + 1) & 0xff;
        if (counter[i] != 0) break;
      }
    }
    return out;
  }
}
