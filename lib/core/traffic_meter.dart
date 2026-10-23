import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef TrafficSpeed = ({double down, double up});

class TrafficMeter {
  TrafficMeter({
    required this.port,
    this.ignoredOutbounds = const {'block'},
  });

  final int port;

  final Set<String> ignoredOutbounds;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2)
    ..idleTimeout = const Duration(seconds: 5)
    ..findProxy = ((_) => 'DIRECT');

  int? _down;
  int? _up;
  DateTime? _at;
  var _closed = false;

  int get totalDown => _totalDown;
  int get totalUp => _totalUp;
  int _totalDown = 0;
  int _totalUp = 0;

  Future<TrafficSpeed?> poll() async {
    if (_closed) return null;
    final counters = await _read();
    if (counters == null || _closed) return null;
    final now = DateTime.now();
    final lastDown = _down;
    final lastUp = _up;
    final lastAt = _at;
    _down = counters.down;
    _up = counters.up;
    _at = now;
    if (lastDown == null || lastUp == null || lastAt == null) {
      return (down: 0.0, up: 0.0);
    }
    final seconds = now.difference(lastAt).inMilliseconds / 1000;
    if (seconds <= 0) return null;
    final addedDown = counters.down >= lastDown ? counters.down - lastDown : 0;
    final addedUp = counters.up >= lastUp ? counters.up - lastUp : 0;
    _totalDown += addedDown;
    _totalUp += addedUp;
    return (down: addedDown / seconds, up: addedUp / seconds);
  }

  Future<({int down, int up})?> _read() async {
    try {
      final request = await _client
          .getUrl(Uri.parse('http://127.0.0.1:$port/debug/vars'))
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      return _sum(jsonDecode(body));
    } on Object {
      return null;
    }
  }

  ({int down, int up})? _sum(Object? json) {
    if (json is! Map) return null;
    final stats = json['stats'];
    if (stats is! Map) return null;
    final outbound = stats['outbound'];
    if (outbound is! Map) return (down: 0, up: 0);
    var down = 0;
    var up = 0;
    for (final entry in outbound.entries) {
      if (ignoredOutbounds.contains(entry.key) || entry.value is! Map) continue;
      final counters = entry.value as Map;
      final d = counters['downlink'];
      final u = counters['uplink'];
      if (d is num) down += d.toInt();
      if (u is num) up += u.toInt();
    }
    return (down: down, up: up);
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

String formatSpeed(double bytesPerSecond) {
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bytesPerSecond < 0 ? 0.0 : bytesPerSecond;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
