import 'package:flutter/material.dart';

import 'apto_colors.dart';
import 'apto_typography.dart';

export 'apto_colors.dart' show AptoColors;
export 'apto_typography.dart' show AptoTypography;
export 'shadows.dart';
export 'spacing.dart';

extension AptoThemeContext on BuildContext {
  /// Colour tokens of the active theme.
  AptoColors get colors => Theme.of(this).extension<AptoColors>()!;

  /// Text styles of the active theme.
  AptoTypography get typo => Theme.of(this).extension<AptoTypography>()!;
}
