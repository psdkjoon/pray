import 'package:flutter/material.dart' hide Icon, Text;
import 'package:pray/app_info.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';

class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({
    required this.error,
    required this.logPath,
    super.key,
  });

  final Object error;
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Text(
                    '${AppInfo.name} could not start',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        '$error'
                        '${logPath == null ? '' : '\n\n${'Details were saved to:'.tr}\n$logPath'}'
                        '\n\n${'Please report this at ${AppInfo.githubDisplay}.'.tr}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
