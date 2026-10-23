import 'package:flutter/material.dart' hide Text, Icon;
import 'package:flutter/services.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';

class EndpointCard extends StatelessWidget {
  const EndpointCard({required this.address, this.onTerminal, super.key});

  final String address;

  final VoidCallback? onTerminal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mixed',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      address,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (onTerminal != null)
              IconButton(
                tooltip: 'Terminal'.tr,
                icon: const Icon(Icons.terminal_rounded),
                onPressed: onTerminal,
              ),
            IconButton(
              tooltip: 'Copy address'.tr,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
