import 'package:flutter/material.dart';

import '../format/percent.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'fitted_text.dart';
import 'score_ring.dart';

/// One row of the "Temas" card on Inicio: a 40 dp mini ring (stroke 4) with
/// the tema number inside, the title, a subtitle (mastery and pending
/// mistakes) and a chevron. It has no surface of its own: put the rows in a
/// `RaisedCard`, separated by dividers. Tapping it ([onTap]) opens the tema's
/// practice.
///
/// [mastery] is the 0..1 value to show (already mapped with `displayMastery`).
class TemaCard extends StatelessWidget {
  const TemaCard({
    super.key,
    required this.tema,
    required this.title,
    required this.mastery,
    required this.mistakes,
    this.hasAttempts = false,
    this.onTap,
  });

  /// 1..7.
  final int tema;
  final String title;

  /// 0..1, shown as is.
  final double mastery;

  /// Questions of the tema currently in Fallos; shown only when > 0.
  final int mistakes;

  /// Whether the tema has already been answered at least once. With attempts
  /// and a 0 % mastery the user is below the chance level and the card says so.
  final bool hasAttempts;

  final VoidCallback? onTap;

  /// Diameter of the mini ring.
  static const double ringSize = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final safe = mastery.isNaN ? 0.0 : mastery.clamp(0.0, 1.0);
    final masteryText = l10n.temaCardMastery(formatPercent(mastery));
    final mistakesText = mistakes > 0 ? l10n.temaCardMistakes(mistakes) : null;
    // 0 % with attempts: the tema is answered, but worse than chance.
    final belowChance = hasAttempts && percentValue(safe) == 0;
    final belowChanceText = belowChance ? l10n.temaCardBelowChance : null;
    final spoken = [
      l10n.temaLabel(tema),
      title,
      masteryText,
      ?mistakesText,
      ?belowChanceText,
    ].join('. ');

    return Semantics(
      button: onTap != null,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: ringSize,
                  child: CustomPaint(
                    painter: ScoreRingPainter(
                      value: safe,
                      strokeWidth: ScoreRing.miniStroke,
                      color: colors.primary,
                      trackColor: colors.ringTrack,
                      tickColor: colors.textPrimary,
                    ),
                    child: Center(
                      child: Text(
                        '$tema',
                        style: typo.rowTitle.copyWith(
                          color: colors.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Sp.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedText(title, style: typo.rowTitle),
                      const SizedBox(height: Sp.xs),
                      Wrap(
                        spacing: Sp.m,
                        children: [
                          Text(masteryText, style: typo.subtitle),
                          if (mistakesText != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  size: IconSize.inline,
                                  color: colors.incorrect,
                                ),
                                const SizedBox(width: Sp.xs),
                                Flexible(
                                  child: Text(
                                    mistakesText,
                                    style: typo.subtitle,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (belowChanceText != null) ...[
                        const SizedBox(height: Sp.xs),
                        Text(belowChanceText, style: typo.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Sp.s),
                Icon(Icons.chevron_right_rounded, color: colors.outlineStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
