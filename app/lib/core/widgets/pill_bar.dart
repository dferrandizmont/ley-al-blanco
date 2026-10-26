import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A rounded horizontal bar for a 0..1 level (progress, mastery). [value] is
/// clamped. Decorative: the owner provides the semantics.
class PillBar extends StatelessWidget {
  const PillBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.trackColor,
  });

  /// 0..1; NaN counts as 0.
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;

  /// Height of the thin bars inside list rows.
  static const double thin = 6;

  double get _safe => value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = color ?? colors.primary;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: ColoredBox(
          color: trackColor ?? colors.ringTrack,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: _safe,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
