import 'package:flutter/material.dart' hide Text, Icon;
import 'package:flutter/services.dart';
import 'package:pray/app_info.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/platform/notification_service.dart';
import 'package:pray/platform/system_service.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/home_screen.dart';
import 'package:pray/ui/routing_screen.dart';
import 'package:pray/ui/servers_screen.dart';
import 'package:pray/ui/settings_screen.dart';
import 'package:pray/ui/update_prompt.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.connection,
    required this.servers,
    required this.settings,
    super.key,
  });

  final ConnectionController connection;
  final ServersController servers;
  final AppSettings settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _sidebarBreakpoint = 800;
  static const _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination('Servers', Icons.dns_outlined, Icons.dns_rounded),
    _Destination('Routing', Icons.alt_route_rounded, Icons.alt_route_rounded),
    _Destination('Settings', Icons.tune_rounded, Icons.tune_rounded),
  ];

  static var _lastIndex = 0;

  var _index = _lastIndex;

  @override
  void initState() {
    super.initState();
    if (AppInfo.usesNotifications || AppInfo.usesBackground) {
      NotificationService.requestPermission();
    }
    if (AppInfo.usesBackground) {
      Future<void>.delayed(const Duration(seconds: 2), _askBackgroundAccess);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdatePrompt.run(context, widget.settings);
    });
  }

  Future<void> _askBackgroundAccess() async {
    if (!mounted || widget.settings.backgroundAsked) return;
    if (await SystemService.isBackgroundAllowed()) return;
    if (!mounted) return;
    widget.settings.backgroundAsked = true;
    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keep running in the background'),
        content: const Text(
          'Android can stop Pray while the screen is off and drop your '
          'connection. Allow Pray to run in the background to prevent that. '
          'You can change this later in Android settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (allow ?? false) await SystemService.requestBackgroundAccess();
  }

  void _select(int index) => setState(() => _index = _lastIndex = index);

  @override
  Widget build(BuildContext context) {
    final page = SafeArea(
      child: switch (_index) {
        0 => HomeScreen(
            controller: widget.connection,
            servers: widget.servers,
            settings: widget.settings,
          ),
        1 => ServersScreen(
            servers: widget.servers,
            settings: widget.settings,
          ),
        2 => RoutingScreen(
            settings: widget.settings,
            connection: widget.connection,
          ),
        _ => SettingsScreen(
            settings: widget.settings,
            connection: widget.connection,
          ),
      },
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlayStyle =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: theme.colorScheme.surfaceContainerLow,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    final Widget scaffold;
    if (MediaQuery.sizeOf(context).width >= _sidebarBreakpoint) {
      scaffold = Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              destinations: _destinations,
              selectedIndex: _index,
              onSelected: _select,
            ),
            Expanded(child: page),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: page,
        bottomNavigationBar: _CompactBar(
          destinations: _destinations,
          selectedIndex: _index,
          onSelected: _select,
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: scaffold,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _width = 11 * AppSpacing.spaceUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: _width,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      AppInfo.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                for (var i = 0; i < destinations.length; i++)
                  ListTile(
                    selected: i == selectedIndex,
                    leading: Icon(
                      i == selectedIndex
                          ? destinations[i].selectedIcon
                          : destinations[i].icon,
                    ),
                    title: Text(destinations[i].label),
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < destinations.length; i++)
                _CompactItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactItem extends StatelessWidget {
  const _CompactItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  static const double _pillHeight = 40;
  static const Duration _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label.tr,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onTap,
            child: AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOutCubic,
              height: _pillHeight,
              constraints: const BoxConstraints(minWidth: 48),
              padding: EdgeInsets.symmetric(
                horizontal: selected ? AppSpacing.md : AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? scheme.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: AnimatedSize(
                duration: _duration,
                curve: Curves.easeOutCubic,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: color,
                    ),
                    if (selected)
                      Text(
                        destination.label,
                        style: theme.textTheme.labelLarge?.copyWith(color: color),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
