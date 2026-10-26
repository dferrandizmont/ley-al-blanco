import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/theory.dart';

/// A diagram of a section, drawn by the app (docs/teoria-guia.md): the shooting
/// gallery, the firing sector or a numbered sequence. Never a picture, and
/// never a weapon or a person.
///
/// Every diagram has a spoken description (its [Semantics] label, plus the
/// caption when there is one).
class TheoryDiagram extends StatelessWidget {
  const TheoryDiagram({super.key, required this.block});

  final DiagramBlock block;

  /// Height of the drawn diagrams at the default text size; it grows with the
  /// text scale so the labels keep their room.
  static const double baseHeight = 220;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final caption = block.caption;

    if (block.kind == TheoryDiagramKind.secuencia) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The caption is drawn above the steps; the label of the block
          // below already speaks it.
          if (caption != null) ...[
            ExcludeSemantics(child: Text(caption, style: typo.caption)),
            const SizedBox(height: Sp.m),
          ],
          Semantics(
            container: true,
            label: [
              l10n.theoryDiagramSecuencia(block.items.length),
              ?caption,
            ].join('. '),
            child: _Steps(items: block.items),
          ),
        ],
      );
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = typo.caption.copyWith(color: colors.textPrimary);

    Widget panel({
      required CustomPainter painter,
      required double height,
      required String description,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            image: true,
            label: [description, ?caption].join(' '),
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: Rad.optionRadius,
              ),
              child: SizedBox(
                height: height,
                child: CustomPaint(painter: painter),
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: Sp.s),
            ExcludeSemantics(child: Text(caption, style: typo.caption)),
          ],
        ],
      );
    }

    return switch (block.kind) {
      TheoryDiagramKind.galeriaTiro => LayoutBuilder(
        builder: (context, constraints) {
          final painter = GaleriaTiroPainter(
            colors: colors,
            labelStyle: labelStyle,
            textScaler: textScaler,
            labels: GaleriaTiroLabels(
              puesto: l10n.theoryDiagramPuesto,
              firingLine: l10n.theoryDiagramFiringLine,
              target: l10n.theoryDiagramTarget,
              distance: l10n.theoryDiagramDistance,
              safeZone: l10n.theoryDiagramSafeZone,
            ),
          );
          return panel(
            description: l10n.theoryDiagramGaleria,
            height: painter.heightFor(
              constraints.maxWidth,
              textScaler.scale(baseHeight),
            ),
            painter: painter,
          );
        },
      ),
      TheoryDiagramKind.zonaSegura => LayoutBuilder(
        builder: (context, constraints) {
          final radius = ZonaSeguraPainter.radiusFor(
            constraints.maxWidth,
            labelStyle,
            textScaler,
          );
          final labels = ZonaSeguraLabels(
            puesto: l10n.theoryDiagramPuesto,
            sector: l10n.theoryDiagramSector,
            safeDirection: l10n.theoryDiagramSafeDirection,
          );
          final painter = ZonaSeguraPainter(
            colors: colors,
            labelStyle: labelStyle,
            textScaler: textScaler,
            radius: radius,
            labels: labels,
          );
          return panel(
            description: l10n.theoryDiagramZonaSegura,
            height: painter.heightFor(constraints.maxWidth),
            painter: painter,
          );
        },
      ),
      TheoryDiagramKind.secuencia => throw StateError('handled above'),
    };
  }
}

/// A sequence: numbered green circles joined by a line, one step per row.
class _Steps extends StatelessWidget {
  const _Steps({required this.items});

  final List<String> items;

  /// Diameter of the numbered circle at text scale 1.
  static const double baseCircle = Sp.x3;

  @override
  Widget build(BuildContext context) {
    // Grows with the text so a two-digit number still fits at large scales.
    final circle = MediaQuery.textScalerOf(context).scale(baseCircle);
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, text) in items.indexed)
          Semantics(
            container: true,
            label: l10n.theoryDiagramStep(i + 1, text),
            excludeSemantics: true,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: circle,
                    child: Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: circle,
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: AptoTypography.tabular(
                                  typo.verdict.copyWith(
                                    color: colors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (i < items.length - 1)
                          Expanded(
                            child: ColoredBox(
                              color: colors.ringTrack,
                              child: const SizedBox(width: Sp.xxs),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: Sp.xs,
                        bottom: i < items.length - 1 ? Sp.l : 0,
                      ),
                      child: Text(text, style: typo.body),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The texts drawn on the gallery diagram.
class GaleriaTiroLabels {
  const GaleriaTiroLabels({
    required this.puesto,
    required this.firingLine,
    required this.target,
    required this.distance,
    required this.safeZone,
  });

  final String puesto;
  final String firingLine;
  final String target;
  final String distance;
  final String safeZone;

  @override
  bool operator ==(Object other) =>
      other is GaleriaTiroLabels &&
      other.puesto == puesto &&
      other.firingLine == firingLine &&
      other.target == target &&
      other.distance == distance &&
      other.safeZone == safeZone;

  @override
  int get hashCode =>
      Object.hash(puesto, firingLine, target, distance, safeZone);
}

/// The texts drawn on the firing-sector diagram.
class ZonaSeguraLabels {
  const ZonaSeguraLabels({
    required this.puesto,
    required this.sector,
    required this.safeDirection,
  });

  final String puesto;
  final String sector;
  final String safeDirection;

  @override
  bool operator ==(Object other) =>
      other is ZonaSeguraLabels &&
      other.puesto == puesto &&
      other.sector == sector &&
      other.safeDirection == safeDirection;

  @override
  int get hashCode => Object.hash(puesto, sector, safeDirection);
}

/// Shared helpers of the two painters.
mixin _DiagramPainting on CustomPainter {
  AptoColors get colors;
  TextStyle get labelStyle;
  TextScaler get textScaler;

  /// Margin between the drawing and the edge of the panel.
  static const double pad = Sp.l;

  /// Stroke of the lines of the drawing.
  static const double line = 1.5;

  TextPainter layoutLabel(String text, double maxWidth, {TextStyle? style}) {
    return TextPainter(
      text: TextSpan(text: text, style: style ?? labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: math.max(maxWidth, 1));
  }

  /// Draws [text] with its left edge at [x] and its vertical centre at [y].
  void labelAt(
    Canvas canvas,
    String text,
    double x,
    double y,
    double maxWidth, {
    TextStyle? style,
  }) {
    final painter = layoutLabel(text, maxWidth, style: style);
    painter.paint(canvas, Offset(x, y - painter.height / 2));
  }

  /// A dashed horizontal line.
  void dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = Sp.s;
    const gap = Sp.xs + Sp.xxs;
    final length = (to - from).distance;
    final direction = (to - from) / length;
    var travelled = 0.0;
    while (travelled < length) {
      final end = math.min(travelled + dash, length);
      canvas.drawLine(
        from + direction * travelled,
        from + direction * end,
        paint,
      );
      travelled += dash + gap;
    }
  }

  /// A shooting stand seen from above: a small rounded rectangle.
  void stand(Canvas canvas, Rect rect) {
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(Sp.s));
    canvas.drawRRect(shape, Paint()..color = colors.surfaceRaised);
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = colors.outlineStrong,
    );
  }
}

/// The shooting gallery seen from above: the stand (puesto) below the dashed
/// firing line, a shaded safe zone running up to the target at 25 m, and the
/// distance as a dimension line on the left. Labels sit in the right column.
class GaleriaTiroPainter extends CustomPainter with _DiagramPainting {
  GaleriaTiroPainter({
    required this.colors,
    required this.labelStyle,
    required this.textScaler,
    required this.labels,
  });

  @override
  final AptoColors colors;
  @override
  final TextStyle labelStyle;
  @override
  final TextScaler textScaler;
  final GaleriaTiroLabels labels;

  // Vertical layout, in the room left by the panel height.
  static const double _standHeight = Sp.x3 - Sp.xs; // 28
  static const double _standGap = Sp.m;
  static const double _targetRadius = Sp.m + Sp.xs; // 16

  // Horizontal layout: dimension line | lane | labels.
  static const double _dimX = _DiagramPainting.pad + Sp.xs;
  static const double _laneWidth = Sp.x4 + Sp.xl + Sp.l; // 76
  static const double _laneLeft = _dimX + Sp.xl + Sp.l;
  static const double _labelX = _laneLeft + _laneWidth + Sp.m;

  /// Minimum gap between two stacked labels of the right column.
  static const double _labelGap = Sp.xs;

  TextStyle get _safeZoneStyle => AptoTypography.weight(
    labelStyle.copyWith(color: colors.onPrimaryContainer),
    600,
  );

  /// Top of the target label: centred on the target, but never above the
  /// panel (a label of several lines grows downwards instead).
  static double _targetLabelTop(double targetY, TextPainter label) =>
      math.max(_labelGap, targetY - label.height / 2);

  static double _targetLabelBottom(double targetY, TextPainter label) =>
      _targetLabelTop(targetY, label) + label.height;

  double _labelWidthFor(double width) => width - _DiagramPainting.pad - _labelX;

  /// Room under the firing line: the stand and the margin, or more when the
  /// label of the stand (several lines) needs it.
  double _belowLine(double width) {
    final puesto = layoutLabel(labels.puesto, _labelWidthFor(width));
    final height = puesto.height;
    puesto.dispose();
    return math.max(
      _DiagramPainting.pad + _standHeight + _standGap,
      _labelGap + height,
    );
  }

  /// Height of the panel when it is [width] wide: [minHeight] (the scaled
  /// base height), or more when the target, safe-zone and firing-line labels
  /// need more room than the stretch between the target and the line.
  double heightFor(double width, double minHeight) {
    final labelWidth = _labelWidthFor(width);
    final target = layoutLabel(labels.target, labelWidth);
    final safe = layoutLabel(
      labels.safeZone,
      labelWidth,
      style: _safeZoneStyle,
    );
    final firing = layoutLabel(labels.firingLine, labelWidth);
    final targetY = _DiagramPainting.pad + _targetRadius;
    final needed =
        targetY +
        (_targetLabelBottom(targetY, target) - targetY) +
        safe.height +
        firing.height +
        3 * _labelGap +
        _belowLine(width);
    target.dispose();
    safe.dispose();
    firing.dispose();
    return math.max(minHeight, needed);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = _DiagramPainting.pad;
    const stroke = _DiagramPainting.line;
    const standHeight = _standHeight;
    const standGap = _standGap;
    const targetRadius = _targetRadius;
    const dimX = _dimX;
    const laneWidth = _laneWidth;
    const laneLeft = _laneLeft;
    final targetY = pad + targetRadius;
    final firingY = size.height - _belowLine(size.width);
    final laneCx = laneLeft + laneWidth / 2;

    final lineColor = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = colors.outlineStrong;

    // Safe zone: a cone from the firing line to the target.
    final zone = Path()
      ..moveTo(laneCx - targetRadius, targetY)
      ..lineTo(laneCx + targetRadius, targetY)
      ..lineTo(laneCx + laneWidth / 2, firingY)
      ..lineTo(laneCx - laneWidth / 2, firingY)
      ..close();
    canvas.drawPath(zone, Paint()..color = colors.primaryContainer);
    canvas.drawPath(
      zone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors.primary,
    );

    // Firing line, dashed, across the whole panel.
    dashedLine(
      canvas,
      Offset(pad, firingY),
      Offset(size.width - pad, firingY),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 2
        ..color = colors.textPrimary,
    );

    // Stand below the line.
    stand(
      canvas,
      Rect.fromCenter(
        center: Offset(laneCx, firingY + standGap + standHeight / 2),
        width: Sp.x4 + Sp.xl,
        height: standHeight,
      ),
    );

    // Target: rings with an orange bull's-eye.
    final target = Offset(laneCx, targetY);
    canvas.drawCircle(
      target,
      targetRadius,
      Paint()..color = colors.surfaceRaised,
    );
    canvas.drawCircle(
      target,
      targetRadius,
      lineColor..color = colors.textPrimary,
    );
    canvas.drawCircle(target, targetRadius * 0.6, lineColor);
    canvas.drawCircle(
      target,
      targetRadius * 0.28,
      Paint()..color = colors.accent,
    );

    // Dimension line (25 m) on the left, interrupted by its label.
    final dim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = colors.textSecondary;
    canvas.drawLine(Offset(dimX, targetY), Offset(dimX, firingY), dim);
    for (final y in [targetY, firingY]) {
      canvas.drawLine(
        Offset(dimX - Sp.xs - Sp.xxs, y),
        Offset(dimX + Sp.xs + Sp.xxs, y),
        dim,
      );
    }
    final distance = layoutLabel(
      labels.distance,
      Sp.x4 * 2,
      style: AptoTypography.weight(labelStyle, 700),
    );
    final mid = Offset(dimX, (targetY + firingY) / 2);
    final patch = Rect.fromCenter(
      center: mid,
      width: distance.width + Sp.s,
      height: distance.height + Sp.xs,
    );
    canvas.drawRect(patch, Paint()..color = colors.background);
    distance.paint(
      canvas,
      mid - Offset(distance.width / 2, distance.height / 2),
    );

    for (final label in _columnLabels(size)) {
      label.painter.paint(canvas, label.offset);
    }
  }

  /// The four labels of the right column placed for a panel of [size]: target
  /// at the top, safe zone half way up the lane, firing line just above the
  /// dashed line and stand below it. The safe-zone label never touches the
  /// target or the firing-line labels, however many lines they take.
  List<({String name, TextPainter painter, Offset offset})> _columnLabels(
    Size size,
  ) {
    const labelX = _labelX;
    final labelWidth = _labelWidthFor(size.width);
    final targetY = _DiagramPainting.pad + _targetRadius;
    final firingY = size.height - _belowLine(size.width);

    final target = layoutLabel(labels.target, labelWidth);
    final firing = layoutLabel(labels.firingLine, labelWidth);
    final firingTop = firingY - firing.height - Sp.xs;
    final safe = layoutLabel(
      labels.safeZone,
      labelWidth,
      style: _safeZoneStyle,
    );
    final lowest = _targetLabelBottom(targetY, target) + _labelGap;
    final highest = math.max(lowest, firingTop - _labelGap - safe.height);
    final safeTop = ((targetY + firingY) / 2 - safe.height / 2).clamp(
      lowest,
      highest,
    );
    final puesto = layoutLabel(labels.puesto, labelWidth);
    final puestoTop = math.max(
      firingY + _standGap + _standHeight / 2 - puesto.height / 2,
      firingY + _labelGap,
    );
    return [
      (
        name: 'target',
        painter: target,
        offset: Offset(labelX, _targetLabelTop(targetY, target)),
      ),
      (name: 'firing', painter: firing, offset: Offset(labelX, firingTop)),
      (name: 'safe', painter: safe, offset: Offset(labelX, safeTop)),
      (name: 'puesto', painter: puesto, offset: Offset(labelX, puestoTop)),
    ];
  }

  /// Where each label of the right column is drawn in a panel of [size],
  /// keyed by 'target', 'firing', 'safe' and 'puesto'. Exposed for the tests.
  @visibleForTesting
  Map<String, Rect> labelRects(Size size) => {
    for (final label in _columnLabels(size))
      label.name: label.offset & label.painter.size,
  };

  @override
  bool shouldRepaint(GaleriaTiroPainter old) =>
      old.colors != colors ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.labels != labels;
}

/// The firing sector seen from above: the stand at the apex, a shaded sector
/// opening away from it and an arrow along the safe direction of the muzzle.
/// The sector takes the left of the panel, the labels the right column.
class ZonaSeguraPainter extends CustomPainter with _DiagramPainting {
  ZonaSeguraPainter({
    required this.colors,
    required this.labelStyle,
    required this.textScaler,
    required this.radius,
    required this.labels,
  });

  @override
  final AptoColors colors;
  @override
  final TextStyle labelStyle;
  @override
  final TextScaler textScaler;

  /// Length of the sector's edges (see [radiusFor]).
  final double radius;
  final ZonaSeguraLabels labels;

  /// Half the opening of the sector.
  static const double halfAngle = math.pi / 6; // 30 degrees

  static const double _standHeight = Sp.x3 - Sp.xs; // 28
  static const double _standWidth = Sp.x4 + Sp.xl;
  static const double _minRadius = Sp.x4 * 2;
  static const double _maxRadius = Sp.x4 * 4;

  /// The radius that leaves the label column wide enough for its longest word
  /// at the current text size.
  static double radiusFor(
    double width,
    TextStyle labelStyle,
    TextScaler textScaler,
  ) {
    final labelRoom = textScaler.scale(labelStyle.fontSize ?? Sp.xl) * 6;
    return (width - 2 * _DiagramPainting.pad - Sp.m - labelRoom).clamp(
      _minRadius,
      _maxRadius,
    );
  }

  /// Width of the label column when the panel is [width] wide.
  double labelWidthFor(double width) =>
      width - 2 * _DiagramPainting.pad - radius - Sp.m;

  TextPainter _sectorLabel(double width) =>
      layoutLabel(labels.sector, labelWidthFor(width));

  TextPainter _directionLabel(double width) => layoutLabel(
    labels.safeDirection,
    labelWidthFor(width),
    style: AptoTypography.weight(
      labelStyle.copyWith(color: colors.primary),
      700,
    ),
  );

  /// Height of the panel when it is [width] wide: the sector and the stand,
  /// or the three labels stacked, whichever is taller, plus the margins.
  double heightFor(double width) {
    final stacked =
        _sectorLabel(width).height +
        _directionLabel(width).height +
        layoutLabel(labels.puesto, labelWidthFor(width)).height +
        2 * Sp.m;
    return 2 * _DiagramPainting.pad + math.max(radius + _standHeight, stacked);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = _DiagramPainting.pad;
    const stroke = _DiagramPainting.line;

    final halfWidth = radius * math.sin(halfAngle);
    final apex = Offset(pad + halfWidth, size.height - pad - _standHeight);
    final labelX = apex.dx + halfWidth + Sp.m;
    final labelWidth = size.width - pad - labelX;

    // Sector.
    final rect = Rect.fromCircle(center: apex, radius: radius);
    final sector = Path()
      ..moveTo(apex.dx, apex.dy)
      ..arcTo(rect, -math.pi / 2 - halfAngle, 2 * halfAngle, false)
      ..close();
    canvas.drawPath(sector, Paint()..color = colors.primaryContainer);
    canvas.drawPath(
      sector,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors.primary,
    );

    // Stand at the apex.
    stand(
      canvas,
      Rect.fromLTWH(
        apex.dx - _standWidth / 2,
        apex.dy,
        _standWidth,
        _standHeight,
      ),
    );

    // Safe direction: an arrow straight up the middle of the sector.
    final tip = Offset(apex.dx, apex.dy - radius * 0.78);
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 2
      ..strokeCap = StrokeCap.round
      ..color = colors.primary;
    canvas.drawLine(apex, tip, arrow);
    const head = Sp.m;
    canvas.drawLine(tip, tip + const Offset(-head / 2, head), arrow);
    canvas.drawLine(tip, tip + const Offset(head / 2, head), arrow);

    // Labels in the right column: sector at the top, direction in the middle
    // (below the sector label when they are tall), stand at the bottom.
    final sectorLabel = _sectorLabel(size.width);
    sectorLabel.paint(canvas, Offset(labelX, pad));
    final direction = _directionLabel(size.width);
    final directionTop = math.max(
      apex.dy - radius / 2 - direction.height / 2,
      pad + sectorLabel.height + Sp.m,
    );
    direction.paint(canvas, Offset(labelX, directionTop));
    labelAt(
      canvas,
      labels.puesto,
      labelX,
      apex.dy + _standHeight / 2,
      labelWidth,
    );
  }

  @override
  bool shouldRepaint(ZonaSeguraPainter old) =>
      old.colors != colors ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.radius != radius ||
      old.labels != labels;
}
