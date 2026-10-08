import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pray/core/crypto/aes.dart';
import 'package:pray/core/crypto/sha256.dart';

class PrayFileException implements Exception {
  const PrayFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PrayFile {
  static const extension = 'pray';
  static const _magic = [0x50, 0x52, 0x41, 0x59];
  static const _version = 1;
  static const _appPassphrase = 'pray.psdkjoon.shared-servers.v1';
  static const _appIterations = 2000;
  static const _passwordIterations = 60000;
  static const _headerLength = 4 + 1 + 1 + 16 + 16;

  static bool looksLikePrayFile(List<int> bytes) {
    if (bytes.length < _headerLength + 32) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static bool needsPassword(List<int> bytes) =>
      looksLikePrayFile(bytes) && bytes[5] == 1;

  static Future<Uint8List> encode(
    List<String> links, {
    String? password,
  }) {
    final payload = utf8.encode(jsonEncode({'app': 'pray', 'links': links}));
    final protected = password != null && password.isNotEmpty;
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final iv = List<int>.generate(16, (_) => random.nextInt(256));
    final passphrase = protected ? password : _appPassphrase;
    final iterations = protected ? _passwordIterations : _appIterations;
    return Isolate.run(() {
      final keys = pbkdf2Sha256(utf8.encode(passphrase), salt, iterations, 64);
      final cipher = Aes256(keys.sublist(0, 32)).ctr(iv, payload);
      final header = BytesBuilder()
        ..add(_magic)
        ..addByte(_version)
        ..addByte(protected ? 1 : 0)
        ..add(salt)
        ..add(iv)
        ..add(cipher);
      final body = header.toBytes();
      final mac = hmacSha256(keys.sublist(32), body);
      return Uint8List.fromList([...body, ...mac]);
    });
  }

  static Future<List<String>> decode(
    List<int> bytes, {
    String? password,
  }) async {
    if (!looksLikePrayFile(bytes)) {
      throw const PrayFileException('This is not a .pray file.');
    }
    if (bytes[4] != _version) {
      throw const PrayFileException('This .pray file is from a newer version.');
    }
    final protected = bytes[5] == 1;
    if (protected && (password == null || password.isEmpty)) {
      throw const PrayFileException('A password is required.');
    }
    final data = Uint8List.fromList(bytes);
    final passphrase = protected ? password! : _appPassphrase;
    final iterations = protected ? _passwordIterations : _appIterations;
    final plain = await Isolate.run(() {
      final salt = data.sublist(6, 22);
      final iv = data.sublist(22, 38);
      final body = data.sublist(0, data.length - 32);
      final mac = data.sublist(data.length - 32);
      final keys = pbkdf2Sha256(utf8.encode(passphrase), salt, iterations, 64);
      if (!constantTimeEquals(hmacSha256(keys.sublist(32), body), mac)) {
        return null;
      }
      return Aes256(keys.sublist(0, 32)).ctr(iv, body.sublist(_headerLength));
    });
    if (plain == null) {
      throw PrayFileException(
        protected ? 'Wrong password or damaged file.' : 'The file is damaged.',
      );
    }
    try {
      final json = jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
      return (json['links'] as List).cast<String>();
    } on Object {
      throw const PrayFileException('The file content is not valid.');
    }
  }
}
