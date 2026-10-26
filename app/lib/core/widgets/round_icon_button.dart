import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'raised_card.dart';

/// The small round button of the headers (close, back): a raised 44 dp circle
/// inside a 48 dp touch area (the Android minimum, [Sp.touch]).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  /// Spoken label and long-press tooltip.
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: Sp.touch,
            child: Center(
              child: SizedBox.square(
                dimension: Sp.roundButton,
                child: DecoratedBox(
                  decoration: raisedDecoration(
                    colors,
                    shape: BoxShape.circle,
                    shadows: AptoShadows.small(colors),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPressed,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          icon,
                          size: IconSize.base,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
