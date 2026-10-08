import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/ping_pill.dart';

class ServerTile extends StatelessWidget {
  const ServerTile({
    required this.server,
    required this.selected,
    required this.selecting,
    required this.checked,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPin,
    required this.onShare,
    super.key,
  });

  final StoredServer server;
  final bool selected;
  final bool selecting;
  final bool checked;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onShare;

  Future<void> _openMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void run(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  server.pinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                ),
                title: Text(server.pinned ? 'Unpin' : 'Pin to top'),
                onTap: () => run(onPin),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Share'),
                onTap: () => run(onShare),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () => run(onEdit),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete'),
                onTap: () => run(onDelete),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: ListTile(
          selected: selecting ? checked : selected,
          leading: Icon(
            selecting
                ? (checked
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined)
                : (selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded),
          ),
          title: Row(
            spacing: AppSpacing.sm,
            children: [
              if (server.pinned) const Icon(Icons.push_pin_rounded, size: 16),
              Flexible(
                child: Text(
                  server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${server.summary}, ${server.address}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PingPill(pingMs: server.pingMs),
              if (!selecting)
                IconButton(
                  tooltip: 'More'.tr,
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => _openMenu(context),
                ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
