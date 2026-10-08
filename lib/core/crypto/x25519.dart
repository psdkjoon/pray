import 'dart:math';
import 'dart:typed_data';

final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
final BigInt _a24 = BigInt.from(121665);

BigInt _decode(List<int> bytes) {
  var value = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i--) {
    value = (value << 8) | BigInt.from(bytes[i]);
  }
  return value;
}

Uint8List _encode(BigInt value) {
  final out = Uint8List(32);
  var v = value;
  for (var i = 0; i < 32; i++) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  return out;
}

Uint8List x25519(List<int> scalar, List<int> uCoordinate) {
  final k = Uint8List.fromList(scalar);
  k[0] &= 248;
  k[31] &= 127;
  k[31] |= 64;
  final kInt = _decode(k);
  final x1 = _decode(uCoordinate) & ((BigInt.one << 255) - BigInt.one);
  var x2 = BigInt.one;
  var z2 = BigInt.zero;
  var x3 = x1;
  var z3 = BigInt.one;
  var swap = 0;
  for (var t = 254; t >= 0; t--) {
    final kt = ((kInt >> t) & BigInt.one).toInt();
    swap ^= kt;
    if (swap == 1) {
      final tx = x2;
      x2 = x3;
      x3 = tx;
      final tz = z2;
      z2 = z3;
      z3 = tz;
    }
    swap = kt;
    final a = (x2 + z2) % _p;
    final aa = (a * a) % _p;
    final b = (x2 - z2) % _p;
    final bb = (b * b) % _p;
    final e = (aa - bb) % _p;
    final c = (x3 + z3) % _p;
    final d = (x3 - z3) % _p;
    final da = (d * a) % _p;
    final cb = (c * b) % _p;
    final s1 = (da + cb) % _p;
    final s2 = (da - cb) % _p;
    x3 = (s1 * s1) % _p;
    z3 = (x1 * ((s2 * s2) % _p)) % _p;
    x2 = (aa * bb) % _p;
    z2 = (e * ((aa + _a24 * e) % _p)) % _p;
  }
  if (swap == 1) {
    final tx = x2;
    x2 = x3;
    x3 = tx;
    final tz = z2;
    z2 = z3;
    z3 = tz;
  }
  return _encode((x2 * z2.modPow(_p - BigInt.two, _p)) % _p);
}

class X25519KeyPair {
  const X25519KeyPair(this.privateKey, this.publicKey);

  final Uint8List privateKey;
  final Uint8List publicKey;

  factory X25519KeyPair.generate() {
    final random = Random.secure();
    final priv = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final base = Uint8List(32)..[0] = 9;
    return X25519KeyPair(priv, x25519(priv, base));
  }
}
