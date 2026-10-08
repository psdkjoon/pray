import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/ping_pill.dart';

class ServerCard extends StatelessWidget {
  const ServerCard({required this.server, super.key});

  final StoredServer server;

  static const double _logoSize = 52;
  static const double _compactWidth = 10 * AppSpacing.spaceUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < _compactWidth;
            return Row(
              spacing: AppSpacing.md,
              children: [
                if (!compact)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: SizedBox.square(
                      dimension: _logoSize,
                      child: Icon(Icons.dns_rounded, color: scheme.primary),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        server.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!compact) PingPill(pingMs: server.pingMs),
              ],
            );
          },
        ),
      ),
    );
  }
}
