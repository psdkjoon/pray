import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pray/theme/catppuccin.dart';

abstract class AccentIcon {
  static const _mochaTile = ui.Color(0xFF342E46);
  static const _mochaGlyph = ui.Color(0xFFCBA6F7);
  static const _latteTile = ui.Color(0xFFD6CCEF);
  static const _latteGlyph = ui.Color(0xFF8839EF);
  static const _mochaMix = 0.12;
  static const _latteMix = 0.22;

  static Future<ui.Image> tinted(
    Uint8List png, {
    required bool dark,
    required String accent,
    int? size,
  }) async {
    final codec = await ui.instantiateImageCodec(
      png,
      targetWidth: size,
      targetHeight: size,
    );
    final image = (await codec.getNextFrame()).image;
    if (accent == CatppuccinPalette.defaultAccent) return image;

    final palette = dark ? CatppuccinPalette.mocha : CatppuccinPalette.latte;
    final sourceTile = dark ? _mochaTile : _latteTile;
    final sourceGlyph = dark ? _mochaGlyph : _latteGlyph;
    final glyph = palette.accent(accent);
    final tile = ui.Color.lerp(
      palette.base,
      glyph,
      dark ? _mochaMix : _latteMix,
    )!;

    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return image;
    final pixels = Uint8List.fromList(data.buffer.asUint8List());

    final tr = _channel(sourceTile.r);
    final tg = _channel(sourceTile.g);
    final tb = _channel(sourceTile.b);
    final dr = _channel(sourceGlyph.r) - tr;
    final dg = _channel(sourceGlyph.g) - tg;
    final db = _channel(sourceGlyph.b) - tb;
    final span = dr * dr + dg * dg + db * db;
    final nr = _channel(tile.r);
    final ng = _channel(tile.g);
    final nb = _channel(tile.b);
    final er = _channel(glyph.r) - nr;
    final eg = _channel(glyph.g) - ng;
    final eb = _channel(glyph.b) - nb;

    for (var i = 0; i < pixels.length; i += 4) {
      final alpha = pixels[i + 3];
      if (alpha == 0) continue;
      final mix = span == 0
          ? 0.0
          : (((pixels[i] - tr) * dr +
                      (pixels[i + 1] - tg) * dg +
                      (pixels[i + 2] - tb) * db) /
                  span)
              .clamp(0.0, 1.0);
      pixels[i] = ((nr + er * mix) * alpha / 255).round();
      pixels[i + 1] = ((ng + eg * mix) * alpha / 255).round();
      pixels[i + 2] = ((nb + eb * mix) * alpha / 255).round();
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: image.width,
      height: image.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final result = (await (await descriptor.instantiateCodec()).getNextFrame()).image;
    descriptor.dispose();
    buffer.dispose();
    image.dispose();
    return result;
  }

  static double _channel(double value) => value * 255;
}
