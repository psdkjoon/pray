import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:flutter/services.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/platform/autostart_service.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/core/geo_updater.dart';
import 'package:pray/core/dns_options.dart';
import 'package:pray/ui/dns_leak_dialog.dart';
import 'package:pray/ui/language_sheet.dart';
import 'package:pray/ui/widgets/page_frame.dart';
import 'package:pray/ui/widgets/settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.connection,
    super.key,
  });

  final AppSettings settings;
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAutostart = defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;

    return ListenableBuilder(
      listenable: Listenable.merge([settings, connection]),
      builder: (context, _) {
        final locked = connection.isConnected;
        final lockedSubtitle = locked ? ' \u2014 disconnect to change' : '';
        return PageFrame(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: [
                SettingsSection(
                  title: 'Appearance',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SegmentedButton<ThemeMode>(
                        expandedInsets: EdgeInsets.zero,
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Auto'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Latte'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Mocha'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selection) =>
                            settings.themeMode = selection.first,
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Language',
                  children: [
                    ListTile(
                      title: const Text('Language'),
                      subtitle: Text(_languageName(settings.language)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _pickLanguage(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Network',
                  children: [
                    ListTile(
                      enabled: !locked,
                      title: const Text('Proxy port'),
                      subtitle: Text(
                        'SOCKS5 proxy, also available while TUN is on$lockedSubtitle',
                      ),
                      trailing: Text(
                        '${settings.proxyPort}',
                        style: theme.textTheme.titleMedium,
                      ),
                      onTap: locked ? null : () => _editPort(context),
                    ),
                    SwitchListTile(
                      title: const Text('Allow LAN connections'),
                      subtitle: Text(
                        'Let other devices use the proxy$lockedSubtitle',
                      ),
                      value: settings.allowLan,
                      onChanged:
                          locked ? null : (value) => settings.allowLan = value,
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'DNS',
                  help: 'How it works: before connecting to a site, an app asks a DNS server for its address. Whoever answers can see every site you visit, and on some networks can fake the answer.\n\n'
                      'DNS server: who answers those lookups. System default uses your device\'s own DNS, which is usually your internet provider. Cloudflare, Google and Quad9 are public servers. Custom lets you enter your own.\n\n'
                      'Encrypted DNS: sends the lookups over HTTPS, so the network between you and the server cannot read or change them.\n\n'
                      'Fake DNS: in TUN mode, answers lookups right inside the tunnel with placeholder addresses and swaps the real site name back in when the app connects. It can be faster and avoids DNS leaks, but a few apps may break.\n\n'
                      'DNS leak test: checks which servers really answer your lookups. If you see your own provider while connected, DNS is leaking.',
                  children: [
                    ListTile(
                      enabled: !locked,
                      title: const Text('DNS server'),
                      subtitle: Text(
                        '${_dnsName(settings)}$lockedSubtitle',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: locked ? null : () => _editDns(context),
                    ),
                    SwitchListTile(
                      title: const Text('Encrypted DNS'),
                      subtitle: Text(
                        'Send lookups over HTTPS so nobody on the network can read them$lockedSubtitle',
                      ),
                      value: settings.dnsEncrypted,
                      onChanged: locked || settings.dnsProvider == DnsProvider.system
                          ? null
                          : (value) => settings.dnsEncrypted = value,
                    ),
                    SwitchListTile(
                      title: const Text('Fake DNS'),
                      subtitle: Text(
                        'Answer lookups inside the tunnel with placeholder addresses. TUN mode only$lockedSubtitle',
                      ),
                      value: settings.fakeDns,
                      onChanged:
                          locked ? null : (value) => settings.fakeDns = value,
                    ),
                    ListTile(
                      title: const Text('DNS leak test'),
                      subtitle: const Text(
                        'See which servers answer your DNS lookups',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => const DnsLeakDialog(),
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Startup',
                  children: [
                    SwitchListTile(
                      title: const Text('Connect on launch'),
                      subtitle: const Text('Start the tunnel when Pray opens'),
                      value: settings.connectOnLaunch,
                      onChanged: (value) => settings.connectOnLaunch = value,
                    ),
                    if (hasAutostart)
                      SwitchListTile(
                        title: const Text('Launch at login'),
                        subtitle: const Text('Start Pray with your session'),
                        value: settings.launchAtLogin,
                        onChanged: (value) async {
                          final ok = await AutostartService.setEnabled(value);
                          settings.launchAtLogin =
                              ok ? value : await AutostartService.isEnabled();
                        },
                      ),
                  ],
                ),
                const SettingsSection(
                  title: 'Core',
                  children: [
                    _GeoDataTile(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _languageName(String code) {
    if (code == L10n.system) return 'System default'.tr;
    for (final language in L10n.languages) {
      if (language.code == code) return language.name;
    }
    return code;
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await showLanguageSheet(context, settings.language);
    if (picked != null) settings.language = picked;
  }

  String _dnsName(AppSettings settings) => switch (settings.dnsProvider) {
        DnsProvider.system => 'System default'.tr,
        DnsProvider.cloudflare => 'Cloudflare',
        DnsProvider.google => 'Google',
        DnsProvider.quad9 => 'Quad9',
        DnsProvider.custom => settings.dnsCustom.isEmpty
            ? 'Custom'.tr
            : settings.dnsCustom,
      };

  Future<void> _editDns(BuildContext context) async {
    final picked = await showDialog<(DnsProvider, String)>(
      context: context,
      builder: (_) => _DnsDialog(
        provider: settings.dnsProvider,
        custom: settings.dnsCustom,
      ),
    );
    if (picked != null) settings.setDns(picked.$1, picked.$2);
  }

  Future<void> _editPort(BuildContext context) async {
    final port = await showDialog<int>(
      context: context,
      builder: (_) => _PortDialog(initial: settings.proxyPort),
    );
    if (port != null) settings.proxyPort = port;
  }
}

class _PortDialog extends StatefulWidget {
  const _PortDialog({required this.initial});

  final int initial;

  @override
  State<_PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends State<_PortDialog> {
  static const int _minPort = 1024;
  static const int _maxPort = 65535;

  late final _controller = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_controller.text);
    if (port == null || port < _minPort || port > _maxPort) {
      setState(() => _error = 'Enter a port from $_minPort to $_maxPort');
      return;
    }
    Navigator.of(context).pop(port);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proxy port'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _DnsDialog extends StatefulWidget {
  const _DnsDialog({required this.provider, required this.custom});

  final DnsProvider provider;
  final String custom;

  @override
  State<_DnsDialog> createState() => _DnsDialogState();
}

class _DnsDialogState extends State<_DnsDialog> {
  late DnsProvider _provider = widget.provider;
  late final _controller = TextEditingController(text: widget.custom);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_provider == DnsProvider.custom && _controller.text.trim().isEmpty) {
      setState(() => _error = 'Enter at least one DNS server');
      return;
    }
    Navigator.of(context).pop((_provider, _controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final names = {
      DnsProvider.system: 'System default'.tr,
      DnsProvider.cloudflare: 'Cloudflare',
      DnsProvider.google: 'Google',
      DnsProvider.quad9: 'Quad9',
      DnsProvider.custom: 'Custom',
    };
    return AlertDialog(
      title: const Text('DNS server'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<DnsProvider>(
                groupValue: _provider,
                onChanged: (value) {
                  if (value != null) setState(() => _provider = value);
                },
                child: Column(
                  children: [
                    for (final entry in names.entries)
                      RadioListTile<DnsProvider>(
                        value: entry.key,
                        title: Text(entry.value),
                      ),
                  ],
                ),
              ),
              if (_provider == DnsProvider.custom)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'DNS server address'.tr,
                      helperText:
                          'An IP like 9.9.9.9 or an https:// DoH address, separated by commas'.tr,
                      helperMaxLines: 3,
                      errorText: _error?.tr,
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _GeoDataTile extends StatefulWidget {
  const _GeoDataTile();

  @override
  State<_GeoDataTile> createState() => _GeoDataTileState();
}

class _GeoDataTileState extends State<_GeoDataTile> {
  DateTime? _updated;
  bool _busy = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await GeoUpdater.lastUpdated();
    if (mounted) setState(() => _updated = value);
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _progress = null;
    });
    String message;
    try {
      await GeoUpdater.update(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      message = 'Geo data updated. Reconnect to use it.';
      if (mounted) setState(() => _progress = 1);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    } on Object catch (e) {
      message = "Couldn't update geo data: $e";
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final date = _updated;
    final percent = _progress == null ? null : (_progress! * 100).round();
    final subtitle = _busy
        ? (percent == null ? 'Downloading\u2026' : 'Downloading $percent%')
        : date == null
        ? 'Download the latest geoip and geosite'
        : 'Last updated ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return ListTile(
      leading: const Icon(Icons.system_update_alt_rounded),
      title: const Text('Geo data'),
      subtitle: Text(subtitle),
      trailing: _busy
          ? _RingProgress(value: _progress)
          : null,
      onTap: _busy ? null : _update,
    );
  }
}

class _RingProgress extends StatelessWidget {
  const _RingProgress({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = value;
    return SizedBox.square(
      dimension: 46,
      child: fraction == null
          ? const CircularProgressIndicator(strokeWidth: 4)
          : TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 250),
              builder: (context, animated, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: animated,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${(animated * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
    );
  }
}
