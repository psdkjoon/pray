import 'dart:async';

import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/app_info.dart';
import 'package:pray/core/update_checker.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/platform/system_service.dart';

abstract class UpdatePrompt {
  static bool _started = false;

  static void run(BuildContext context) {
    if (_started) return;
    _started = true;
    unawaited(_check(context));
  }

  static Future<void> _check(BuildContext context) async {
    final info = await UpdateChecker.check();
    if (info == null || !context.mounted) return;
    final download = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: Text('Version ${info.version} is available. You have ${AppInfo.version}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (download != true) return;
    try {
      await SystemService.openUrl(info.url);
    } on Object {
      return;
    }
  }
}
