// Renders the launcher icon / splash PNGs from AppMarkPainter into
// assets/branding/ (versioned source assets). Skipped in the normal run:
//
//   flutter test test/branding/render_icons_test.dart --dart-define=GENERATE_ICONS=true
//
// then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:apto_armas/core/widgets/app_mark.dart';
import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render_support.dart';

const _generate = bool.fromEnvironment('GENERATE_ICONS');

Future<void> _write(String name, CustomPainter painter, int px) async {
  final image = await renderPainter(painter, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('assets/branding/$name').writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render launcher icon and splash PNGs', () async {
    Directory('assets/branding').createSync(recursive: true);
    // Store / iOS icon: opaque full-bleed square (the OS applies the mask).
    await _write('icon_1024.png', const AppMarkPainter(), 1024);
    // Adaptive icon foreground: the mark without background, in the safe zone.
    await _write(
      'icon_foreground.png',
      const AppMarkPainter(background: false, scale: adaptiveScale),
      1024,
    );
    // Themed (monochrome) layer: white silhouette, same scale as foreground.
    await _write(
      'icon_monochrome.png',
      const AppMarkPainter(
        background: false,
        monochrome: true,
        scale: adaptiveScale,
      ),
      1024,
    );
    // Splash (Android < 12, iOS): the mark on its rounded tile.
    await _write(
      'splash_mark.png',
      const AppMarkPainter(cornerRadius: AppMark.cornerRadius),
      768,
    );
    // Android 12 splash icon: the mark without background inside the inner
    // circle; the system draws the green disc (icon_background_color).
    await _write(
      'splash_mark_android12.png',
      const AppMarkPainter(background: false, scale: android12Scale),
      1152,
    );
  }, skip: _generate ? false : 'Pass --dart-define=GENERATE_ICONS=true');
}
