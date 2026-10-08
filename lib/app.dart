import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/app_info.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/servers/servers_controller.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/theme/app_theme.dart';
import 'package:pray/ui/app_shell.dart';

class PRayApp extends StatelessWidget {
  const PRayApp({
    required this.settings,
    required this.servers,
    required this.connection,
    super.key,
  });

  final AppSettings settings;
  final ServersController servers;
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: AppInfo.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          scrollBehavior: const _NoScrollbarBehavior(),
          locale: L10n.locale,
          supportedLocales: [
            for (final language in L10n.languages) Locale(language.code),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: KeyedSubtree(
            key: ValueKey(L10n.code),
            child: AppShell(
              connection: connection,
              servers: servers,
              settings: settings,
            ),
          ),
        );
      },
    );
  }
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
