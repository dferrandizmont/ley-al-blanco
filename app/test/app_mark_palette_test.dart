import 'package:apto_armas/core/theme/app_mark_palette.dart' as tokens;
import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the painter reexports the canonical branding palette', () {
    const painter = AppMarkPainter();
    expect(identical(AppMarkPalette.icon, tokens.AppMarkPalette.icon), isTrue);
    expect(painter.palette, same(tokens.AppMarkPalette.icon));
    expect(painter.monochromeColor, tokens.AppMarkPalette.monochromeInk);
  });

  test('branding tokens preserve the launcher and themed colours', () {
    const palette = tokens.AppMarkPalette.icon;
    expect(palette.background, const Color(0xFF2F5D50));
    expect(palette.track, const Color(0xFF3E6E60));
    expect(palette.arc, const Color(0xFFF27A1A));
    expect(palette.shield, const Color(0xFFEFE9DD));
    expect(palette.check, palette.background);
    expect(tokens.AppMarkPalette.monochromeInk, const Color(0xFFFFFFFF));

    const tile = Color(0xFF2A5448);
    const arc = Color(0xFFF27A1A);
    final themed = tokens.AppMarkPalette.themed(tile: tile, arc: arc);
    expect(themed.background, tile);
    expect(themed.track, Color.alphaBlend(const Color(0x14FFFFFF), tile));
    expect(themed.arc, arc);
    expect(themed.shield, tokens.AppMarkPalette.shieldSand);
    expect(themed.check, tile);
  });
}
