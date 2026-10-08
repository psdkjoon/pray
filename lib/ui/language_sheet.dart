import 'package:flutter/material.dart' hide Text, Icon;
import 'package:flutter/widgets.dart' as w;
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';
import 'package:pray/theme/app_text_style.dart';

const _glyphs = {
  'en': 'Aa',
  'fa': 'ف',
  'ru': 'Я',
  'id': 'Id',
  'zh': '文',
  'ja': 'あ',
};

const _families = {
  'fa': 'NotoSansArabic',
  'ru': 'NotoSans',
  'zh': 'NotoSansSC',
  'ja': 'NotoSansJP',
};

Future<String?> showLanguageSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _LanguageSheet(current: current),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                Text('Language', style: theme.textTheme.titleLarge),
                _LanguageCard(
                  code: L10n.system,
                  glyph: null,
                  title: 'System default'.tr,
                  subtitle: '',
                  family: null,
                  chosen: current == L10n.system,
                  wide: true,
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    final width = (box.maxWidth - AppSpacing.md) / 2;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final language in L10n.languages)
                          SizedBox(
                            width: width,
                            child: _LanguageCard(
                              code: language.code,
                              glyph: _glyphs[language.code],
                              title: language.name,
                              subtitle: language.english,
                              family: _families[language.code],
                              chosen: current == language.code,
                              wide: false,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.code,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.family,
    required this.chosen,
    required this.wide,
  });

  final String code;
  final String? glyph;
  final String title;
  final String subtitle;
  final String? family;
  final bool chosen;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontFamily: family ?? AppTextStyle.fontFamily,
      fontFamilyFallback: AppTextStyle.fontFallback,
      color: chosen ? scheme.onPrimaryContainer : scheme.onSurface,
    );
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: chosen ? scheme.primary : scheme.surfaceContainerHighest,
      ),
      child: glyph == null
          ? Icon(
              Icons.phone_android_rounded,
              size: 22,
              color: chosen ? scheme.onPrimary : scheme.onSurfaceVariant,
            )
          : w.Text(
              glyph!,
              style: TextStyle(
                fontFamily: family ?? 'SpaceGrotesk',
                fontFamilyFallback: AppTextStyle.fontFallback,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: chosen ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
    );
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        w.Text(title, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle.isNotEmpty)
          w.Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: chosen
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                  : scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: chosen ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: chosen ? scheme.primary : scheme.outlineVariant,
          width: chosen ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => Navigator.of(context).pop(code),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: wide
                ? Row(
                    spacing: AppSpacing.md,
                    children: [
                      badge,
                      Expanded(child: labels),
                      if (chosen)
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.sm,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          badge,
                          if (chosen)
                            Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                      labels,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
