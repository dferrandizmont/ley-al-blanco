import 'package:flutter/material.dart';

import '../format/percent.dart';
import '../l10n/l10n.dart';
import 'pill_bar.dart';

/// Thin horizontal bar for a 0..1 level (a tema's hits). [value] is shown as
/// given: map raw mastery with `displayMastery` first. Out-of-range values are
/// clamped. Exposes the level to screen readers.
class MasteryBar extends StatelessWidget {
  const MasteryBar({
    super.key,
    required this.value,
    this.height = PillBar.thin,
  });

  /// 0..1.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safe = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: context.l10n.masteryBarSemantics(formatPercent(safe)),
      excludeSemantics: true,
      child: PillBar(value: safe, height: height),
    );
  }
}
