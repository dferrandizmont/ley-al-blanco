import 'package:flutter/material.dart';

import 'apto_colors.dart';

/// Elevation of the "Sereno" design. Shadows exist in the light theme only;
/// the dark theme has none and uses a 1 px `divider` border on raised
/// surfaces instead (see [raisedBorder]).
class AptoShadows {
  const AptoShadows._();

  /// Big cards: `0 2 10 rgba(29,36,32,.07)`.
  static List<BoxShadow> card(AptoColors c) => c.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x121D2420),
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ];

  /// Small round buttons and secondary pills: `0 1 3 rgba(29,36,32,.10)`.
  static List<BoxShadow> small(AptoColors c) => c.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x1A1D2420),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ];

  /// The floating orange main button: `0 6 16 rgba(242,122,26,.30)`
  /// (`accent` of the theme at 30 %). None in the dark theme.
  static List<BoxShadow> floating(AptoColors c) => c.isDark
      ? const []
      : [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.30),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ];

  /// The border that replaces the shadow in the dark theme.
  static Border? raisedBorder(AptoColors c) =>
      c.isDark ? Border.all(color: c.divider) : null;
}
