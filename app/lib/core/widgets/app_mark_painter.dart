import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_mark_palette.dart';

export '../theme/app_mark_palette.dart';

/// Draws the Ley al Blanco mark: a progress ring (80 % = 16/20, the pass mark of
/// the exam) around a shield with a check. Single source of truth for the
/// in-app [AppMark], the launcher icon and the splash (the PNGs are rendered
/// from this painter by `test/branding/render_icons_test.dart`).
///
/// Geometry on a 220 x 220 canvas, y down:
/// - ring: circle (110, 110) r 76, stroke 13; the arc starts at the top and
///   runs clockwise over [arcFraction] (0.8) of the circumference, round caps;
/// - shield: `M110 64 L146 78 V106 C146 131 131 148 110 157 C89 148 74 131 74
///   106 V78 Z`;
/// - check: polyline `M93 108 L105 120 L128 96`, stroke 11, round caps/joins.
class AppMarkPainter extends CustomPainter {
  const AppMarkPainter({
    this.palette = AppMarkPalette.icon,
    this.background = true,
    this.cornerRadius = 0,
    this.monochrome = false,
    this.monochromeColor = AppMarkPalette.monochromeInk,
    this.scale = 1,
    this.minStrokePx = 0,
  }) : assert(scale > 0 && scale <= 1),
       assert(cornerRadius >= 0 && cornerRadius <= 0.5);

  /// Side of the design canvas.
  static const double unit = 220;

  /// Share of the ring that is progress (16/20).
  static const double arcFraction = 0.8;

  static const double _ringRadius = 76;
  static const double _ringStroke = 13;
  static const double _checkStroke = 11;

  /// Outer diameter of the ring as a fraction of the 220 canvas
  /// ((76 + 13 / 2) * 2 / 220 = 0.75).
  static const double ringOuterFraction =
      (_ringRadius + _ringStroke / 2) * 2 / unit;

  static final Path _shield = Path()
    ..moveTo(110, 64)
    ..lineTo(146, 78)
    ..lineTo(146, 106)
    ..cubicTo(146, 131, 131, 148, 110, 157)
    ..cubicTo(89, 148, 74, 131, 74, 106)
    ..lineTo(74, 78)
    ..close();

  static final Path _check = Path()
    ..moveTo(93, 108)
    ..lineTo(105, 120)
    ..lineTo(128, 96);

  final AppMarkPalette palette;

  /// Paint the full-bleed [AppMarkPalette.background] square (rounded by
  /// [cornerRadius]); `false` leaves everything outside the mark transparent
  /// (adaptive-icon foreground, tile-less uses).
  final bool background;

  /// Corner radius of the background as a fraction of the side (0 = the
  /// square the OS masks; 0.32 = the in-app tile).
  final double cornerRadius;

  /// One-colour silhouette ([monochromeColor]): ring + shield, the track at 40 %
  /// alpha so the progress arc still reads, and the check cut out (transparent,
  /// or the background colour when [background] is drawn).
  final bool monochrome;
  final Color monochromeColor;

  /// Share of the canvas taken by the 220 design box, centred (1 = whole
  /// canvas). The ring's outer diameter is then `scale * 0.75` of the side:
  /// 0.88 puts it at 66 % (Android adaptive-icon safe zone).
  final double scale;

  /// Minimum stroke width in logical px for the ring (the check gets 85 % of
  /// it): at 34 px the 13-unit stroke is 2.0 px, so [AppMark] thickens it
  /// slightly. 0 keeps the exact geometry.
  final double minStrokePx;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final bounds = Offset.zero & size;
    if (background) {
      final radius = Radius.circular(side * cornerRadius);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: bounds.center, width: side, height: side),
          radius,
        ),
        Paint()..color = palette.background,
      );
    }

    final px = side * scale / unit; // logical px per design unit
    final ringStroke = math.max(_ringStroke, minStrokePx / px);
    final checkStroke = math.max(_checkStroke, 0.85 * minStrokePx / px);

    final cutOut = monochrome && !background;
    if (cutOut) canvas.saveLayer(bounds, Paint());
    canvas
      ..save()
      ..translate(bounds.center.dx - 110 * px, bounds.center.dy - 110 * px)
      ..scale(px);

    final trackColor = monochrome
        ? monochromeColor.withValues(alpha: 0.4)
        : palette.track;
    final arcColor = monochrome ? monochromeColor : palette.arc;
    final shieldColor = monochrome ? monochromeColor : palette.shield;

    final ring = Rect.fromCircle(
      center: const Offset(110, 110),
      radius: _ringRadius,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..isAntiAlias = true;
    canvas.drawCircle(ring.center, _ringRadius, stroke..color = trackColor);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * arcFraction,
      false,
      stroke
        ..color = arcColor
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      _shield,
      Paint()
        ..color = shieldColor
        ..isAntiAlias = true,
    );
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = checkStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    if (cutOut) {
      checkPaint.blendMode = BlendMode.clear;
    } else {
      checkPaint.color = monochrome ? palette.background : palette.check;
    }
    canvas
      ..drawPath(_check, checkPaint)
      ..restore();
    if (cutOut) canvas.restore();
  }

  @override
  bool shouldRepaint(AppMarkPainter old) =>
      old.palette != palette ||
      old.background != background ||
      old.cornerRadius != cornerRadius ||
      old.monochrome != monochrome ||
      old.monochromeColor != monochromeColor ||
      old.scale != scale ||
      old.minStrokePx != minStrokePx;
}
