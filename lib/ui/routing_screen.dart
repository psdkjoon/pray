import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/connection/connection_controller.dart';
import 'package:pray/core/warp.dart';
import 'package:pray/settings/app_settings.dart';
import 'package:pray/ui/adblock_dialog.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/ui/widgets/app_picker.dart';
import 'package:pray/ui/widgets/page_frame.dart';
import 'package:pray/ui/widgets/settings_section.dart';
import 'package:xray_config/xray_config.dart';

extension on RoutingPreset {
  String get label => switch (this) {
        RoutingPreset.global => 'Proxy everything',
        RoutingPreset.bypassLan => 'Bypass local network',
        RoutingPreset.bypassIran => 'Bypass Iran',
      };

  String get description => switch (this) {
        RoutingPreset.global => 'All traffic goes through the server',
        RoutingPreset.bypassLan => 'Local addresses connect directly',
        RoutingPreset.bypassIran => 'Iranian sites and IPs connect directly',
      };
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog();

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _controller = TextEditingController();
  var _action = RuleAction.direct;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty || value.contains(RegExp(r'\s'))) {
      setState(() => _error = 'Enter a domain, IP or CIDR');
      return;
    }
    Navigator.of(context).pop(CustomRule(value: value, action: _action));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add rule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.md,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Domain, IP or CIDR'.tr,
              hintText: 'example.com, 1.2.3.0/24, geosite:google'.tr,
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          SegmentedButton<RuleAction>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: RuleAction.proxy, label: Text('Proxy')),
              ButtonSegment(value: RuleAction.direct, label: Text('Direct')),
              ButtonSegment(value: RuleAction.block, label: Text('Block')),
            ],
            selected: {_action},
            onSelectionChanged: (value) =>
                setState(() => _action = value.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}

class RoutingScreen extends StatelessWidget {
  const RoutingScreen({
    required this.settings,
    required this.connection,
    super.key,
  });

  final AppSettings settings;
  final ConnectionController connection;

  Future<void> _addRule(BuildContext context) async {
    final rule = await showDialog<CustomRule>(
      context: context,
      builder: (_) => const _RuleDialog(),
    );
    if (rule != null) settings.addCustomRule(rule);
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

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
                  title: 'Where traffic goes',
                  help: 'Proxy everything: all traffic goes through the '
                      'server.\n\n'
                      'Bypass local network: only addresses on your own '
                      'network (router, printers, other devices) connect '
                      'directly. Everything else goes through the server.\n\n'
                      'Bypass Iran: Iranian sites (.ir and known Iranian '
                      'domains) and Iranian IP addresses connect directly, as '
                      'well as your local network. Everything else goes '
                      'through the server.',
                  children: [
                    for (final preset in RoutingPreset.values)
                      ListTile(
                        enabled: !locked,
                        selected: preset == settings.routingPreset,
                        leading: Icon(
                          preset == settings.routingPreset
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                        ),
                        title: Text(preset.label),
                        subtitle: Text('${preset.description}$lockedSubtitle'),
                        onTap: locked
                            ? null
                            : () => settings.routingPreset = preset,
                      ),
                  ],
                ),
                SettingsSection(
                  title: 'Ad blocking',
                  help: 'How it works: while connected, Pray looks at the '
                      'name of every site or server an app tries to reach '
                      'and drops the connection if the name is on a block '
                      'list. Nothing is installed on your device and no '
                      'traffic is read.\n\n'
                      'Off: nothing is blocked.\n\n'
                      'Standard: blocks the well-known ad networks and '
                      'trackers from the built-in geo data.\n\n'
                      'Strict: Standard plus extra ad, tracker and '
                      'analytics domains built into Pray, including '
                      'Iranian ad networks. A few apps may stop working.\n\n'
                      'Filter lists: download community lists such as '
                      'StevenBlack, HaGeZi or PersianBlocker for much wider '
                      'coverage, or add your own list URL. You can also '
                      'block single sites in Custom rules below.\n\n'
                      'YouTube ads: blocks the ad servers YouTube and '
                      'Google use for banner, display and some video ad '
                      'requests. Most video ads come from the same servers '
                      'as the video itself, so a few will remain. For '
                      'complete YouTube ad blocking use an ad-free client.\n\n'
                      'Limits: ads served from the same address as the '
                      'content (most YouTube and in-app video ads) cannot '
                      'be told apart and still show. Encrypted DNS inside '
                      'an app can also bypass name-based blocking.',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SegmentedButton<AdBlockLevel>(
                        expandedInsets: EdgeInsets.zero,
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: AdBlockLevel.off,
                            label: Text('Off'),
                          ),
                          ButtonSegment(
                            value: AdBlockLevel.standard,
                            label: Text('Standard'),
                          ),
                          ButtonSegment(
                            value: AdBlockLevel.strict,
                            label: Text('Strict'),
                          ),
                        ],
                        selected: {settings.adBlock},
                        onSelectionChanged: locked
                            ? null
                            : (value) => settings.adBlock = value.first,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          switch (settings.adBlock) {
                            AdBlockLevel.off => 'Nothing is blocked.',
                            AdBlockLevel.standard =>
                              'Blocks the well-known ad networks and trackers.',
                            AdBlockLevel.strict =>
                              'Standard plus extra ads, trackers and analytics. A few apps may break.',
                          },
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.smart_display_rounded),
                      title: const Text('YouTube ads'),
                      subtitle: Text(
                        'Blocks YouTube and Google ad requests. Ads served inside the video itself still show.$lockedSubtitle',
                      ),
                      value: settings.blockYoutubeAds,
                      onChanged: locked
                          ? null
                          : (value) => settings.blockYoutubeAds = value,
                    ),
                    ListTile(
                      enabled: !locked && settings.blockAds,
                      leading: const Icon(Icons.filter_list_rounded),
                      title: const Text('Filter lists'),
                      subtitle: Text(
                        '${settings.adLists.where((l) => l.enabled).length} '
                        'enabled$lockedSubtitle',
                      ),
                      onTap: locked || !settings.blockAds
                          ? null
                          : () => showAdBlockLists(context, settings),
                    ),
                  ],
                ),
                _WarpSection(settings: settings, locked: locked),
                if (isAndroid)
                  SettingsSection(
                    title: 'Apps',
                    children: [
                      SwitchListTile(
                        title: const Text('Per-app proxy'),
                        subtitle: Text(
                          'Choose which apps use the VPN$lockedSubtitle',
                        ),
                        value: settings.perAppProxy,
                        onChanged: locked
                            ? null
                            : (value) => settings.perAppProxy = value,
                      ),
                      if (settings.perAppProxy)
                        ListTile(
                          enabled: !locked,
                          leading: const Icon(Icons.apps_rounded),
                          title: const Text('Choose apps'),
                          subtitle: Text(
                            '${settings.perAppPackages.length} selected',
                          ),
                          onTap: locked
                              ? null
                              : () async {
                                  final result = await showAppPicker(
                                    context,
                                    settings.perAppPackages,
                                  );
                                  if (result != null) {
                                    settings.perAppPackages = result;
                                  }
                                },
                        ),
                    ],
                  ),
                SettingsSection(
                  title: 'Custom rules',
                  children: [
                    for (final rule in settings.customRules)
                      ListTile(
                        enabled: !locked,
                        leading: Icon(
                          switch (rule.action) {
                            RuleAction.proxy => Icons.vpn_lock_rounded,
                            RuleAction.direct => Icons.trending_flat_rounded,
                            RuleAction.block => Icons.block_rounded,
                          },
                        ),
                        title: Text(rule.value),
                        subtitle: Text(
                          switch (rule.action) {
                            RuleAction.proxy => 'Through the proxy',
                            RuleAction.direct => 'Direct',
                            RuleAction.block => 'Blocked',
                          },
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove rule'.tr,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: locked
                              ? null
                              : () => settings.removeCustomRule(rule),
                        ),
                      ),
                    ListTile(
                      enabled: !locked,
                      leading: const Icon(Icons.add_rounded),
                      title: Text(
                        settings.customRules.isEmpty
                            ? 'Add a rule'
                            : 'Add another rule',
                      ),
                      subtitle: Text(
                        'Send a domain or IP through the proxy, direct, or block it$lockedSubtitle',
                      ),
                      onTap: locked ? null : () => _addRule(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on WarpMode {
  String get label => switch (this) {
        WarpMode.off => 'Off',
        WarpMode.standalone => 'WARP only',
        WarpMode.afterProxy => 'Server, then WARP',
        WarpMode.selective => 'WARP for chosen sites',
      };

  String get description => switch (this) {
        WarpMode.off => 'Use only your server',
        WarpMode.standalone => 'Send everything through Cloudflare WARP, no '
            'server needed',
        WarpMode.afterProxy => 'Your server first, then Cloudflare, so sites '
            'see a Cloudflare address',
        WarpMode.selective => 'Normal routing, but the sites you list leave '
            'through WARP',
      };
}

class _WarpSection extends StatefulWidget {
  const _WarpSection({required this.settings, required this.locked});

  final AppSettings settings;
  final bool locked;

  @override
  State<_WarpSection> createState() => _WarpSectionState();
}

class _WarpSectionState extends State<_WarpSection> {
  var _busy = false;

  AppSettings get _settings => widget.settings;

  Future<void> _register() async {
    setState(() => _busy = true);
    String? error;
    try {
      _settings.warpAccount = await WarpService.register();
    } on Object catch (e) {
      error = "Couldn't register: $e";
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _editEndpoint() async {
    final controller = TextEditingController(text: _settings.warpEndpoint);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('WARP endpoint'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'host:port'.tr,
            helperText: 'Default ${WarpAccount.defaultEndpoint}'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.contains(':')) _settings.warpEndpoint = value;
  }

  Future<void> _editDomains() async {
    final controller =
        TextEditingController(text: _settings.warpDomains.join('\n'));
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sites that use WARP'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            helperText: 'One per line, like openai.com or geosite:netflix'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    _settings.warpDomains = [
      for (final line in value.split(RegExp(r'[\n,]')))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    final lockedSubtitle = locked ? ' \u2014 disconnect to change' : '';
    final account = _settings.warpAccount;
    return SettingsSection(
      title: 'Cloudflare WARP',
      help: 'WARP is a free Cloudflare tunnel. Pray can create a free WARP '
          'account for you and use it in three ways.\n\n'
          'WARP only: all traffic goes straight through Cloudflare. No '
          'server is needed, but WARP is blocked on some networks.\n\n'
          'Server, then WARP: traffic goes through your server first and '
          'leaves from a Cloudflare address. This helps with sites that '
          'block server addresses, and hides your server address from '
          'those sites.\n\n'
          'WARP for chosen sites: everything uses your normal route, but '
          'the sites you list (for example AI services) go through WARP.\n\n'
          'WARP hides your address from sites, it does not hide your '
          'traffic from Cloudflare.',
      children: [
        ListTile(
          leading: _busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  account == null
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                ),
          title: Text(account == null ? 'No WARP account' : 'WARP account ready'),
          subtitle: Text(
            account == null
                ? 'Tap to create a free account'
                : 'Tap the bin to remove it',
          ),
          trailing: account == null
              ? null
              : IconButton(
                  tooltip: 'Remove account'.tr,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: locked
                      ? null
                      : () {
                          _settings.warpAccount = null;
                          _settings.warpMode = WarpMode.off;
                        },
                ),
          onTap: account != null || _busy ? null : _register,
        ),
        if (account != null) ...[
          ListTile(
            enabled: !locked && !_busy,
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Renew WARP account'),
            subtitle: Text(
              'Create a new free account. Use this if WARP stops working.$lockedSubtitle',
            ),
            onTap: locked || _busy ? null : _register,
          ),
          for (final mode in WarpMode.values)
            ListTile(
              enabled: !locked,
              selected: mode == _settings.warpMode,
              leading: Icon(
                mode == _settings.warpMode
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text(mode.label),
              subtitle: Text('${mode.description}$lockedSubtitle'),
              onTap: locked ? null : () => _settings.warpMode = mode,
            ),
          if (_settings.warpMode == WarpMode.selective)
            ListTile(
              enabled: !locked,
              leading: const Icon(Icons.list_alt_rounded),
              title: const Text('Sites that use WARP'),
              subtitle: Text('${_settings.warpDomains.length} entries'),
              onTap: locked ? null : _editDomains,
            ),
          ListTile(
            enabled: !locked,
            leading: const Icon(Icons.settings_ethernet_rounded),
            title: const Text('Endpoint'),
            subtitle: Text(_settings.warpEndpoint),
            onTap: locked ? null : _editEndpoint,
          ),
        ],
      ],
    );
  }
}
