import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:pray/localization/localization.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/connection/proxy_endpoint.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/servers/stored_server.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/endpoint_card.dart';
import 'package:pray/ui/widgets/power_button.dart';
import 'package:pray/ui/widgets/server_card.dart';
import 'package:pray/ui/widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.controller,
    required this.servers,
    required this.settings,
    super.key,
  });

  final ConnectionController controller;
  final ServersController servers;
  final AppSettings settings;

  static const double _wideBreakpoint = 620;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, servers, settings]),
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= _wideBreakpoint;
                    final hero = _Hero(controller: controller);
                    final info = _Info(
                      inline: wide,
                      controller: controller,
                      server: servers.selected,
                      address: ProxyEndpoint.address(settings.proxyPort),
                    );
                    if (wide) {
                      return Row(
                        spacing: AppSpacing.xxl,
                        children: [
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(child: hero),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(child: info),
                            ),
                          ),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.lg,
                      ),
                      child: Column(
                        spacing: AppSpacing.md,
                        children: [hero, info],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, subtitle) = switch (controller.status) {
      ConnectionStatus.disconnected => ('Disconnected', 'Tap to connect'),
      ConnectionStatus.connecting => ('Connecting', 'Starting the tunnel'),
      ConnectionStatus.connected => ('Connected', _format(controller.elapsed)),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PowerButton(
            status: controller.status,
            onPressed: controller.toggle,
          ),
        ),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (controller.status == ConnectionStatus.disconnected &&
            controller.lastError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SelectableText(
              controller.lastError!.tr,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
        if (defaultTargetPlatform != TargetPlatform.android) ...[
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<ConnectionMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ConnectionMode.proxy, label: Text('Proxy')),
            ButtonSegment(value: ConnectionMode.tun, label: Text('TUN')),
          ],
          selected: {controller.mode},
          onSelectionChanged: controller.canChangeMode
              ? (selection) => controller.setMode(selection.first)
              : null,
        ),
        ],
      ],
    );
  }

  static String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.inline,
    required this.controller,
    required this.server,
    required this.address,
  });

  final bool inline;
  final ConnectionController controller;
  final StoredServer? server;
  final String address;

  @override
  Widget build(BuildContext context) {
    final connected = controller.isConnected;
    final ping =
        connected && server?.pingMs != null ? '${server!.pingMs} ms' : '\u2014';
    final stats = [
      StatCard(
        icon: Icons.south_rounded,
        label: 'Down',
        value: connected ? '12.4 MB/s' : '\u2014',
        inline: inline,
      ),
      StatCard(
        icon: Icons.north_rounded,
        label: 'Up',
        value: connected ? '1.8 MB/s' : '\u2014',
        inline: inline,
      ),
      StatCard(
        icon: Icons.bolt_rounded,
        label: 'Ping',
        value: ping,
        inline: inline,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        if (inline)
          ...stats
        else
          Row(
            spacing: AppSpacing.sm,
            children: [for (final stat in stats) Expanded(child: stat)],
          ),
        if (server != null) ServerCard(server: server!),
        if (defaultTargetPlatform != TargetPlatform.android)
          EndpointCard(address: address),
      ],
    );
  }
}
