import 'package:flutter/material.dart' hide Text, Icon;
import 'package:flutter/widgets.dart' as w show Text;
import 'package:pray/core/xray_config/xray_config.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = selecting ? checked : selected;
    final proxy = server.proxy;
    final security = proxy.securityLabel;

    return Semantics(
      button: true,
      selected: active,
      label: server.name,
      child: Material(
        color: active
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.10),
                scheme.surfaceContainerLow,
              )
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: active ? scheme.primary : scheme.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xxs,
              AppSpacing.sm,
            ),
            child: Row(
              spacing: AppSpacing.md,
              children: [
                _Badge(
                  code: _code(proxy.protocol),
                  on: active,
                  outlined: selecting && !checked,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xxs,
                    children: [
                      Row(
                        spacing: AppSpacing.xxs,
                        children: [
                          if (server.pinned)
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                          Flexible(
                            child: w.Text(
                              server.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: w.Text(
                            server.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: AppSpacing.xxs,
                            children: [
                              _Tag(proxy.protocolLabel, strong: true),
                              if (security != null) _Tag(security),
                              Flexible(child: _Tag(proxy.transportLabel)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PingPill(pingMs: server.pingMs),
                if (selecting)
                  const SizedBox(width: AppSpacing.md)
                else
                  IconButton(
                    tooltip: 'More'.tr,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _openMenu(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _code(ProxyProtocol protocol) => switch (protocol) {
        ProxyProtocol.vless => 'VL',
        ProxyProtocol.vmess => 'VM',
        ProxyProtocol.trojan => 'TJ',
        ProxyProtocol.shadowsocks => 'SS',
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.code, required this.on, required this.outlined});

  final String code;
  final bool on;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const duration = Duration(milliseconds: 180);
    return AnimatedContainer(
      duration: duration,
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? scheme.primary : scheme.surfaceContainerHighest,
        border: outlined
            ? Border.all(color: scheme.outline, width: 1.5)
            : null,
      ),
      child: AnimatedSwitcher(
        duration: duration,
        child: on
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('on'),
                color: scheme.onPrimary,
              )
            : w.Text(
                code,
                key: const ValueKey('code'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: strong
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 1,
        ),
        child: w.Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: strong ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: strong ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}
