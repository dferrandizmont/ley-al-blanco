/// Non-breaking space: keeps the number and the sign together on one line.
const String _nbsp = ' ';

/// Formats a ratio in 0..1 as a Spanish percentage: `0.87` -> "87 %" with a
/// non-breaking space before the sign (RAE / Fundéu style). Rounds half away
/// from zero, clamps out-of-range values and treats NaN as 0 so a bad number
/// never reaches the screen as "NaN %".
String formatPercent(double ratio) {
  final safe = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0);
  return '${(safe * 100).round()}$_nbsp%';
}
