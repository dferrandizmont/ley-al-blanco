@Tags(['store'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:apto_armas/core/theme/apto_colors.dart';
import 'package:apto_armas/core/theme/apto_typography.dart';
import 'package:apto_armas/core/theme/spacing.dart';
import 'package:apto_armas/core/widgets/app_mark.dart';
import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'readme_render_support.dart';

void main() {
  test(
    'Cabecera del README y gráfico destacado de Play, RGB 1024×500',
    () async {
      const width = 1024;
      const height = 500;
      const colors = AptoColors.light;
      final typo = AptoTypography.from(colors);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 500),
        Paint()..color = colors.background,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 500),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 500), [
            colors.primary.withValues(alpha: .10),
            colors.primary.withValues(alpha: 0),
          ]),
      );

      const markSide = Sp.x4 * 6;
      const margin = Sp.x3 * 2;
      const textX = margin + markSide + Sp.x3;
      const textWidth = width - textX - margin;
      canvas.save();
      canvas.translate(margin, (height - markSide) / 2);
      const AppMarkPainter(cornerRadius: AppMark.cornerRadius)
          .paint(canvas, const Size.square(markSide));
      canvas.restore();

      final title = TextPainter(
        text: TextSpan(
          text: 'Ley al Blanco',
          style: typo.title.apply(fontSizeFactor: 2),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: textWidth);
      final subtitle = TextPainter(
        text: TextSpan(
        text: 'Prepara el examen teórico de la\nlicencia de armas D, E y AEM',
          style: typo.body.apply(
            fontSizeFactor: 1.5,
            color: colors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: textWidth);
      expect(title.didExceedMaxLines, isFalse);
      expect(subtitle.didExceedMaxLines, isFalse);
      final top = (height - title.height - Sp.xl - subtitle.height) / 2;
      title.paint(canvas, Offset(textX, top));
      subtitle.paint(canvas, Offset(textX, top + title.height + Sp.xl));
      title.dispose();
      subtitle.dispose();
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      try {
        await writeReadmePng(image, 'header.png');
        await _check('header.png', width, height, 2);
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );

  test('Icono de Play, RGBA 512×512', () async {
    final recorder = ui.PictureRecorder();
    const AppMarkPainter().paint(Canvas(recorder), const Size.square(512));
    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 512);
    try {
      await writeReadmePng(image, 'icon-512.png', alpha: true);
      await _check('icon-512.png', 512, 512, 6);
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
}

Future<void> _check(String name, int width, int height, int colorType) async {
  final bytes = File('../docs/readme/$name').readAsBytesSync();
  expect(bytes[24], 8, reason: '8 bits por canal');
  expect(bytes[25], colorType, reason: 'RGB (2) o RGBA (6)');
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  expect(frame.image.width, width);
  expect(frame.image.height, height);
  frame.image.dispose();
  codec.dispose();
}
