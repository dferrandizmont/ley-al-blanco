@Tags(['golden'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:apto_armas/core/theme/apto_colors.dart';
import 'package:apto_armas/core/widgets/app_mark.dart';
import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'render_support.dart';

/// RGBA of the pixel under design unit ([ux], [uy]) of a [px] canvas drawn
/// with design box scale [scale].
List<int> _pixel(
  Uint8List rgba,
  int px,
  double ux,
  double uy, [
  double scale = 1,
]) {
  final k = px * scale / AppMarkPainter.unit;
  final off = px / 2 - 110 * k;
  final x = (off + ux * k).round();
  final y = (off + uy * k).round();
  final i = (y * px + x) * 4;
  return rgba.sublist(i, i + 4);
}

void main() {
  const sand = Color(0xFFEFE9DD);
  final key = GlobalKey();

  Widget framed(double size, Widget child) => Center(
    child: RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: sand,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox.square(dimension: size, child: child),
        ),
      ),
    ),
  );

  group('AppMarkPainter goldens', () {
    for (final size in [220.0, 48.0]) {
      testWidgets('icon at ${size.round()} px', (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: framed(size, const CustomPaint(painter: AppMarkPainter())),
          ),
        );
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('goldens/app_mark_painter_${size.round()}.png'),
        );
      }, tags: ['golden']);
    }
  });

  group('AppMark golden at 34 px', () {
    for (final dark in [false, true]) {
      final name = dark ? 'dark' : 'light';
      testWidgets('AppMark 34 $name', (tester) async {
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await pumpApp(
          tester,
          Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: const AppMark(),
                ),
              ),
            ),
          ),
          dark: dark,
        );
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('goldens/app_mark_34_$name.png'),
        );
      }, tags: ['golden']);
    }
  });

  group('rendered geometry', () {
    test('the icon is an opaque full-bleed square', () async {
      final rgba = await rgbaOf(
        await renderPainter(const AppMarkPainter(), 256),
      );
      for (var i = 3; i < rgba.length; i += 4) {
        expect(rgba[i], 255);
      }
      expect(_pixel(rgba, 256, 2, 2), [0x2F, 0x5D, 0x50, 255]);
    });

    test('the arc starts at the top and covers 80 % clockwise', () async {
      final rgba = await rgbaOf(
        await renderPainter(const AppMarkPainter(), 440),
      );
      const orange = [0xF2, 0x7A, 0x1A];
      const track = [0x3E, 0x6E, 0x60];
      List<int> onRing(double deg) {
        // Design angle `deg` clockwise from the top (-90 deg in canvas terms).
        final rad = (deg - 90) * math.pi / 180;
        return _pixel(
          rgba,
          440,
          110 + 76 * math.cos(rad),
          110 + 76 * math.sin(rad),
        ).sublist(0, 3);
      }

      expect(onRing(10), orange); // just after the top, clockwise
      expect(onRing(90), orange); // right
      expect(onRing(180), orange); // bottom
      expect(onRing(270), orange); // left
      expect(onRing(280), orange); // 288 deg = 80 %, still inside
      expect(onRing(330), track); // the missing 20 % (72 deg) up to the top
      expect(onRing(350), track);
    });

    test('the foreground keeps the ring at about 54 % of the canvas', () async {
      const px = 512;
      final rgba = await rgbaOf(
        await renderPainter(
          const AppMarkPainter(background: false, scale: adaptiveScale),
          px,
        ),
      );
      var minX = px, maxX = -1, minY = px, maxY = -1;
      for (var y = 0; y < px; y++) {
        for (var x = 0; x < px; x++) {
          if (rgba[(y * px + x) * 4 + 3] > 8) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      expect((maxX - minX + 1) / px, lessThanOrEqualTo(0.56));
      expect((maxY - minY + 1) / px, lessThanOrEqualTo(0.56));
      expect((maxX - minX + 1) / px, greaterThan(0.52)); // not shrunk further
      expect(rgba[3], 0); // transparent corner
    });

    test(
      'the monochrome layer is a white silhouette with the check cut out',
      () async {
        const px = 440;
        final rgba = await rgbaOf(
          await renderPainter(
            const AppMarkPainter(background: false, monochrome: true),
            px,
          ),
        );
        expect(_pixel(rgba, px, 110, 90), [255, 255, 255, 255]); // shield
        expect(_pixel(rgba, px, 99, 114)[3], 0); // on the check: cut out
        expect(_pixel(rgba, px, 186, 110), [255, 255, 255, 255]); // arc
        final track = _pixel(
          rgba,
          px,
          110 + 76 * math.cos(4.08),
          110 + 76 * math.sin(4.08),
        );
        expect(track[3], inInclusiveRange(95, 110)); // 40 % alpha track
        expect(_pixel(rgba, px, 2, 2)[3], 0);
      },
    );

    test(
      'with a background the monochrome check takes the background colour',
      () async {
        const px = 440;
        final rgba = await rgbaOf(
          await renderPainter(const AppMarkPainter(monochrome: true), px),
        );
        expect(_pixel(rgba, px, 99, 114), [0x2F, 0x5D, 0x50, 255]);
        expect(_pixel(rgba, px, 110, 90), [255, 255, 255, 255]);
      },
    );

    test('the in-app palette follows the theme tokens', () {
      for (final c in [AptoColors.light, AptoColors.dark]) {
        final p = AppMarkPalette.themed(tile: c.brandTile, arc: c.accent);
        expect(p.background, c.brandTile);
        expect(p.check, c.brandTile);
        expect(p.arc, c.accent);
        expect(p.shield, AppMarkPalette.shieldSand);
      }
      // The track on the icon tile is the spec's #3E6E60 (within 6/255).
      final track = AppMarkPalette.themed(
        tile: AppMarkPalette.icon.background,
        arc: AppMarkPalette.icon.arc,
      ).track;
      for (final pair in [
        (track.r, 0x3E / 255),
        (track.g, 0x6E / 255),
        (track.b, 0x60 / 255),
      ]) {
        expect((pair.$1 - pair.$2).abs() * 255, lessThan(6));
      }
    });
  });
}
