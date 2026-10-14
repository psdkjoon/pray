import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pray/platform/system_service.dart';

typedef NotificationMessage = ({String title, String body});

typedef NotificationBuilder<T> = NotificationMessage? Function(
  T previous,
  T current,
);

abstract class NotificationService {
  static bool _permissionAsked = false;

  static Future<void> requestPermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await SystemService.requestNotificationPermission();
  }

  static Future<void> show(String title, String body) =>
      SystemService.notify(title, body);

  static void follow<T>(
    Listenable source,
    T Function() read,
    NotificationBuilder<T> build,
  ) {
    var last = read();
    source.addListener(() {
      final current = read();
      if (current == last) return;
      final message = build(last, current);
      last = current;
      if (message != null) unawaited(show(message.title, message.body));
    });
  }
}
