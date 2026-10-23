import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pray/theme/catppuccin.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({required this.size, super.key});

  final double size;

  static const double _darkMix = 0.12;
  static const double _lightMix = 0.22;

  static const String _sourceTile = '#342e46';
  static const String _sourceGlyph = '#cba6f7';

  static final Future<String> _artwork =
      rootBundle.loadString('assets/icons/icon_mocha.svg');

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base =
        (dark ? CatppuccinPalette.mocha : CatppuccinPalette.latte).base;
    final tile = Color.lerp(base, scheme.primary, dark ? _darkMix : _lightMix)!;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: FutureBuilder<String>(
          future: _artwork,
          builder: (context, snapshot) {
            final source = snapshot.data;
            if (source == null) return const SizedBox.shrink();
            return SvgPicture.string(
              source
                  .replaceAll(_sourceTile, _hex(tile))
                  .replaceAll(_sourceGlyph, _hex(scheme.primary)),
              width: size,
              height: size,
            );
          },
        ),
      ),
    );
  }
}
