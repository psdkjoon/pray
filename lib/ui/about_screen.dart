import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:flutter/services.dart';
import 'package:pray/platform/system_service.dart';
import 'package:pray/app_info.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/theme/app_theme.dart';
import 'package:pray/ui/widgets/page_frame.dart';
import 'package:pray/ui/widgets/settings_section.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const double _markSize = 72;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heart = theme.extension<StatusColors>()!.heart;
    final logoAsset = theme.brightness == Brightness.dark
        ? 'assets/icons/logo_mocha.png'
        : 'assets/icons/logo_latte.png';

    return PageFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.lg,
          children: [
            Column(
              spacing: AppSpacing.sm,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Image.asset(
                    logoAsset,
                    width: _markSize,
                    height: _markSize,
                  ),
                ),
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
            const SettingsSection(
              title: 'Links',
              children: [
                _LinkTile(
                  icon: Icons.code_rounded,
                  title: 'GitHub',
                  display: AppInfo.githubDisplay,
                  url: AppInfo.githubUrl,
                ),
                _LinkTile(
                  icon: Icons.send_rounded,
                  title: 'Telegram',
                  display: AppInfo.telegramDisplay,
                  url: AppInfo.telegramUrl,
                ),
                _LinkTile(
                  icon: Icons.volunteer_activism_rounded,
                  title: 'Donate',
                  display: AppInfo.donateDisplay,
                  url: AppInfo.donateUrl,
                ),
              ],
            ),
            const _SourcesField(),
          ],
        ),
      ),
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

class _Source {
  const _Source(this.name, this.detail, this.size, this.x, this.y, this.phase);

  final String name;
  final String detail;
  final double size;
  final double x;
  final double y;
  final double phase;
}

const _sources = <_Source>[
  _Source('Flutter', 'The toolkit behind the interface', 104, 0.30, 0.20, 0.0),
  _Source('Dart', 'The language it is written in', 84, 0.74, 0.17, 1.3),
  _Source('Xray-core', 'The engine behind every connection', 96, 0.50, 0.50, 2.1),
  _Source('Catppuccin', 'The Mocha and Latte palettes', 78, 0.17, 0.64, 3.4),
  _Source('Space Grotesk', 'The typeface, under the SIL Open Font License', 66, 0.85, 0.54, 4.2),
  _Source('Noto Sans', 'Latin and Cyrillic text, under the SIL Open Font License', 58, 0.31, 0.87, 5.0),
  _Source('Noto Sans Arabic', 'Persian text, under the SIL Open Font License', 54, 0.62, 0.87, 0.7),
  _Source('Noto Sans SC', 'Chinese text, under the SIL Open Font License', 46, 0.90, 0.86, 2.8),
  _Source('Noto Sans JP', 'Japanese text, under the SIL Open Font License', 46, 0.10, 0.38, 3.9),
];

class _SourcesField extends StatefulWidget {
  const _SourcesField();

  @override
  State<_SourcesField> createState() => _SourcesFieldState();
}

class _SourcesFieldState extends State<_SourcesField>
    with SingleTickerProviderStateMixin {
  static const double _height = 340;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tints = [scheme.primary, scheme.secondary, scheme.tertiary];
    final current = _sources[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('Built with', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, box) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value * 2 * math.pi;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < _sources.length; i++)
                        _bubble(i, box, t, tints[i % tints.length], theme),
                    ],
                  );
                },
              );
            },
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Card(
            key: ValueKey(_selected),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(current.name, style: theme.textTheme.titleMedium),
                  Text(
                    current.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(int i, BoxConstraints box, double t, Color tint, ThemeData theme) {
    final s = _sources[i];
    final amp = 6 + s.size * 0.12;
    final dx = math.sin(t * (1 + i % 3) + s.phase) * amp;
    final dy = math.cos(t * (2 + i % 2) + s.phase * 1.7) * amp;
    final pulse = 1 + 0.035 * math.sin(t * 3 + s.phase);
    final chosen = i == _selected;
    final left = s.x * box.maxWidth - s.size / 2 + dx;
    final top = s.y * _height - s.size / 2 + dy;
    return Positioned(
      left: left,
      top: top,
      width: s.size,
      height: s.size,
      child: Transform.scale(
        scale: pulse,
        child: GestureDetector(
          onTap: () => setState(() => _selected = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.all(s.size * 0.14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.5),
                colors: [
                  tint.withValues(alpha: chosen ? 0.55 : 0.32),
                  tint.withValues(alpha: chosen ? 0.28 : 0.12),
                ],
              ),
              border: Border.all(
                color: tint.withValues(alpha: chosen ? 0.95 : 0.45),
                width: chosen ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: chosen ? 0.35 : 0.14),
                  blurRadius: chosen ? 22 : 12,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                s.name.replaceFirst('Noto Sans ', 'Noto Sans\n'),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 10 + s.size * 0.08,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
