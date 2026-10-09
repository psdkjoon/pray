import 'dart:io';

import 'package:pray/app_info.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/platform/system_service.dart';

abstract class NotificationService {
  static bool _permissionAsked = false;

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid || _permissionAsked) return;
    _permissionAsked = true;
    await SystemService.requestNotificationPermission();
  }

  static ConnectionStatus _last = ConnectionStatus.disconnected;
  static bool _wasConnected = false;

  static void follow(ConnectionController connection) {
    _last = connection.status;
    connection.addListener(() => _onStatusChanged(connection));
  }

  static void _onStatusChanged(ConnectionController connection) {
    if (!Platform.isLinux && !Platform.isWindows) return;
    final status = connection.status;
    if (status == _last) return;
    _last = status;
    switch (status) {
      case ConnectionStatus.connected:
        _wasConnected = true;
        SystemService.notify(
          '${AppInfo.name} is connected'.tr,
          'Your traffic is routed through the proxy.'.tr,
        );
      case ConnectionStatus.disconnected:
        if (!_wasConnected) return;
        _wasConnected = false;
        SystemService.notify(
          '${AppInfo.name} is disconnected'.tr,
          'Your traffic is going directly.'.tr,
        );
      case ConnectionStatus.connecting:
        break;
    }
  }
}
