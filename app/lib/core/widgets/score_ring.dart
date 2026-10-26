import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format/percent.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Ring with a figure in the middle: the pass probability on Inicio (116 dp,
/// stroke 8) or the score of a mock (168 dp, stroke 10, with a tick at the
/// pass mark).
///
/// [value] is 0..1; `null` means loading / unknown: an empty ring and a dash,
/// so the layout does not jump when the number arrives. By default the middle
/// shows the percentage with tabular numerals, scaled down (never clipped)
/// with large text; [center] replaces it. [label] is spoken together with the
/// percentage ("Probabilidad de aprobar: 30 %"); [semanticsLabel] replaces
/// the whole spoken text (when [center] is not a percentage).
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    this.label,
    this.size = homeSize,
    this.strokeWidth = homeStroke,
    this.color,
    this.passMark,
    this.center,
    this.semanticsLabel,
  });

  /// Diameter and stroke of the ring on Inicio.
  static const double homeSize = 116;
  static const double homeStroke = 8;

  /// Diameter and stroke of the ring of a mock result.
  static const double resultSize = 168;
  static const double resultStroke = 10;

  /// Stroke of the mini ring of a tema row (`TemaCard`).
  static const double miniStroke = 4;

  /// 0..1, or null while unknown.
  final double? value;
  final String? label;
  final String? semanticsLabel;

  /// Outer diameter.
  final double size;
  final double strokeWidth;

  /// Colour of the arc; defaults to the brand green.
  final Color? color;

  /// 0..1 position of the pass mark (tick on the ring); null = no tick.
  final double? passMark;

  /// Replaces the percentage in the middle.
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final current = value;
    final fraction = current == null || current.isNaN
        ? 0.0
        : current.clamp(0.0, 1.0);
    final percent = current == null ? null : formatPercent(current);
    final spoken = percent ?? l10n.scoreRingUnknown;

    return Semantics(
      label:
          semanticsLabel ??
          (label == null ? spoken : l10n.scoreRingSemantics(label!, spoken)),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: ScoreRingPainter(
            value: fraction,
            strokeWidth: strokeWidth,
            color: color ?? colors.primary,
            trackColor: colors.ringTrack,
            tickColor: colors.textPrimary,
            passMark: passMark,
          ),
          child: Padding(
            padding: EdgeInsets.all(strokeWidth + Sp.s),
            child: Center(
              child:
                  center ??
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(percent ?? '–', style: typo.score),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the track, the arc (round caps, from 12 o'clock, clockwise) and the
/// optional pass-mark tick of a [ScoreRing].
class ScoreRingPainter extends CustomPainter {
  const ScoreRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    required this.tickColor,
    this.passMark,
  });

  /// 0..1.
  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Color tickColor;
  final double? passMark;

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * value;
    if (sweep > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = color;
      canvas.drawArc(rect, _start, sweep, false, arc);
    }

    final mark = passMark;
    if (mark != null) {
      final angle = _start + 2 * math.pi * mark.clamp(0.0, 1.0);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final reach = strokeWidth / 2 + 3;
      final tick = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = tickColor;
      canvas.drawLine(
        center + direction * (radius - reach),
        center + direction * (radius + reach),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(ScoreRingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor ||
      old.passMark != passMark;
}
