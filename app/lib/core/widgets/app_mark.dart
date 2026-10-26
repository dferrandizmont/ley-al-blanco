import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_mark_painter.dart';

/// The brand mark: a rounded mountain-green square ([AptoColors.brandTile])
/// with the progress ring (80 % = 16/20) around a sand shield-check, drawn by
/// [AppMarkPainter] (same geometry as the app icon). The arc is the theme
/// `accent` (orange, >= 3:1 on the tile); the shield is sand (>= 6:1). 34 dp in
/// the header of Inicio.
///
/// Small sizes: the ring stroke is never thinner than [minStroke] (2.4 dp; at
/// 34 dp the exact 13/220 stroke would be 2.0 dp), so the arc stays legible;
/// from about 40 dp up it is the exact icon geometry. Decorative (hidden from
/// screen readers).
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 34});

  final double size;

  /// Corner radius of the tile as a fraction of its side.
  static const double cornerRadius = 0.32;

  /// Minimum ring stroke in dp (see the class documentation).
  static const double minStroke = 2.4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.brandTile,
            borderRadius: BorderRadius.circular(size * cornerRadius),
          ),
          child: CustomPaint(
            painter: AppMarkPainter(
              palette: AppMarkPalette.themed(
                tile: colors.brandTile,
                arc: colors.accent,
              ),
              background: false,
              minStrokePx: minStroke,
            ),
          ),
        ),
      ),
    );
  }
}
