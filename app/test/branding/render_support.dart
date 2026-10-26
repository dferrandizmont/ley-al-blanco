import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:flutter/rendering.dart';

/// Share of the canvas taken by the 220 design box so that the ring's outer
/// diameter is 54 % of it. The guaranteed visible circle is 66 % (72/108 dp);
/// 54 % leaves a green margin around the ring on circle, squircle and
/// teardrop masks instead of the ring touching the mask edge.
const adaptiveScale = 0.54 / AppMarkPainter.ringOuterFraction;

/// Same idea for the Android 12 splash: the ring's outer diameter is 75 % of
/// the 768 px circle (2/3 of the 1152 px image) the system leaves visible.
const android12Scale = 0.75 * (768 / 1152) / AppMarkPainter.ringOuterFraction;

/// Paints [painter] on a transparent [px] x [px] canvas.
Future<ui.Image> renderPainter(CustomPainter painter, int px) {
  final recorder = ui.PictureRecorder();
  painter.paint(
    Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble())),
    Size.square(px.toDouble()),
  );
  return recorder.endRecording().toImage(px, px);
}

/// Straight (non-premultiplied) RGBA bytes of [image].
Future<Uint8List> rgbaOf(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return data!.buffer.asUint8List();
}
