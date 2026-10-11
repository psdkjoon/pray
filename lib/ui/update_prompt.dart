import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/app_info.dart';
import 'package:pray/core/update_checker.dart';
import 'package:pray/core/update_installer.dart';
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
    if (info == null) {
      if (Platform.isAndroid) unawaited(UpdateDownload.cleanup());
      return;
    }
    if (!context.mounted) return;
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
    if (!context.mounted) return;
    if (Platform.isAndroid && info.url.toLowerCase().endsWith('.apk')) {
      await _downloadAndInstall(context, info);
    } else {
      await _openInBrowser(info.url);
    }
  }

  static Future<void> _openInBrowser(String url) async {
    try {
      await SystemService.openUrl(url);
    } on Object {
      return;
    }
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    UpdateInfo info,
  ) async {
    final progress = ValueNotifier<double?>(null);
    final download = UpdateDownload();
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Downloading update…'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, value, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: value),
                  if (value != null) ...[
                    const SizedBox(height: 8),
                    Text('${(value * 100).round()}%'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  download.cancel();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ).then((_) => dialogOpen = false),
    );

    String? path;
    var failed = false;
    try {
      path = await download.run(info.url, onProgress: (v) => progress.value = v);
    } on UpdateCancelled {
      return;
    } on Object {
      failed = true;
    } finally {
      if (dialogOpen && context.mounted) Navigator.of(context).pop();
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (failed || path == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't download the update. Opening your browser instead."),
        ),
      );
      await _openInBrowser(info.url);
      return;
    }
    try {
      final opened = await SystemService.installApk(path);
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Allow Pray to install apps, then come back to continue.'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on Object {
      await _openInBrowser(info.url);
    }
  }
}
