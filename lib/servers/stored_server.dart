import 'package:flutter/foundation.dart';
import 'package:xray_config/xray_config.dart';

@immutable
class StoredServer {
  const StoredServer({
    required this.id,
    required this.proxy,
    this.pingMs,
    this.pinned = false,
  });

  final String id;
  final ProxyServer proxy;
  final int? pingMs;
  final bool pinned;

  String get name => proxy.displayName;
  String get summary => proxy.summary;
  String get address => '${proxy.address}:${proxy.port}';

  StoredServer withPing(int? ms) {
    return StoredServer(id: id, proxy: proxy, pingMs: ms, pinned: pinned);
  }

  StoredServer withPinned({required bool pinned}) {
    return StoredServer(id: id, proxy: proxy, pingMs: pingMs, pinned: pinned);
  }
}
