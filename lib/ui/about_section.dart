import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:flutter/services.dart';
import 'package:pray/core/diagnostics.dart';
import 'package:pray/platform/system_service.dart';
import 'package:pray/app_info.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/theme/app_theme.dart';
import 'package:pray/ui/donate_sheet.dart';
import 'package:pray/ui/widgets/app_logo.dart';
import 'package:pray/ui/widgets/settings_section.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  static const double _markSize = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heart = theme.extension<StatusColors>()!.heart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: [
        SettingsSection(
          title: 'Links',
          children: [
            const _LinkTile(
              icon: Icons.code_rounded,
              title: 'GitHub',
              display: AppInfo.repoDisplay,
              url: AppInfo.repoUrl,
            ),
            const _LinkTile(
              icon: Icons.send_rounded,
              title: 'Telegram',
              display: AppInfo.telegramDisplay,
              url: AppInfo.telegramUrl,
            ),
            const _LinkTile(
              icon: Icons.volunteer_activism_rounded,
              title: 'Donate (Iran)',
              display: AppInfo.donateIranDisplay,
              url: AppInfo.donateIranUrl,
            ),
            ListTile(
              leading: const Icon(Icons.currency_bitcoin_rounded),
              title: const Text('Donate (crypto)'),
              subtitle: const Text('Bitcoin, USDT, USDC'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showDonateSheet(context),
            ),
          ],
        ),
        const _DiagnosticsSection(),
        Column(
          spacing: AppSpacing.sm,
          children: [
            const AppLogo(size: _markSize),
            Text(AppInfo.name, style: theme.textTheme.headlineSmall),
            Text(
              'Version ${AppInfo.version}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        _LoveCard(heart: heart),
      ],
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection();

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: Diagnostics.read()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error log copied'.tr)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Diagnostics',
      children: [
        ValueListenableBuilder<int>(
          valueListenable: Diagnostics.count,
          builder: (context, count, _) {
            return ListTile(
              enabled: count > 0,
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Copy error log'),
              subtitle: Text(
                count == 0
                    ? 'No errors recorded'
                    : 'Errors recorded: $count',
              ),
              trailing: count == 0
                  ? null
                  : IconButton(
                      tooltip: 'Clear'.tr,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: Diagnostics.clear,
                    ),
              onTap: count == 0 ? null : () => _copy(context),
            );
          },
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.display,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String display;
  final String url;

  Future<void> _open(BuildContext context) async {
    var opened = false;
    try {
      await SystemService.openUrl(url);
      opened = true;
    } on Object {
      opened = false;
    }
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't open $url")),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(display),
      trailing: IconButton(
        tooltip: 'Copy link'.tr,
        icon: const Icon(Icons.copy_rounded),
        onPressed: () => _copy(context),
      ),
      onTap: () => _open(context),
    );
  }
}

class _LoveCard extends StatefulWidget {
  const _LoveCard({required this.heart});

  final Color heart;

  @override
  State<_LoveCard> createState() => _LoveCardState();
}

class _LoveCardState extends State<_LoveCard>
    with SingleTickerProviderStateMixin {
  static const double _heartSize = 22;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _heart(double beat) => Transform.scale(
        scale: 1 + 0.28 * beat,
        child: Icon(
          Icons.favorite_rounded,
          size: _heartSize,
          color: widget.heart,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = [scheme.primary, scheme.tertiary, widget.heart, scheme.primary];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final beat = math.pow(math.sin(t * 2 * math.pi * 2), 8).toDouble();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                _heart(beat),
                Flexible(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: colors,
                      tileMode: TileMode.repeated,
                      transform: _SlideTransform(t),
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: Text(
                      'Made with love by ${AppInfo.author}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                _heart(beat),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * t, 0, 0);
  }
}
