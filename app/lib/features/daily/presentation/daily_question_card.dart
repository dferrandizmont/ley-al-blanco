import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/raised_card.dart';
import '../domain/daily_question.dart';

/// The "Pregunta del día" card of Inicio: today's question (its stem), the
/// streak and a button that opens it; once answered, a calm "Respondida hoy"
/// instead. No notifications: the card is where the habit lives.
class DailyQuestionCard extends StatelessWidget {
  const DailyQuestionCard({super.key, required this.status, this.onOpen});

  final DailyStatus status;

  /// Opens the question (null while it cannot be opened).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final question = status.question;
    if (question == null) return const SizedBox.shrink();
    final done = status.answeredToday;

    return RaisedCard(
      radius: Rad.tile,
      padding: const EdgeInsets.all(Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Side by side when they fit, the badge under the label otherwise
          // (small screens, large text).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Sp.m,
            runSpacing: Sp.s,
            children: [
              Overline(l10n.dailyTitle),
              if (status.streak > 0) _StreakBadge(days: status.streak),
            ],
          ),
          const SizedBox(height: Sp.m),
          if (done) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: IconSize.base,
                  color: colors.correct,
                ),
                const SizedBox(width: Sp.s),
                Expanded(child: Text(l10n.dailyDone, style: typo.label)),
              ],
            ),
            const SizedBox(height: Sp.xs),
            Text(l10n.dailyDoneHint, style: typo.subtitle),
          ] else ...[
            Text(
              question.stem,
              style: typo.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Sp.l),
            SecondaryButton(
              label: l10n.dailyAnswer,
              icon: Icons.arrow_forward_rounded,
              trailingIcon: true,
              onPressed: onOpen,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Racha de 3 días": flame icon and tabular count on `primaryContainer`.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.dailyStreak(days);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: Rad.pillRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.m,
            vertical: Sp.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: IconSize.inline,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: Sp.xs),
              Text(
                label,
                style: AptoTypography.tabular(
                  context.typo.verdict.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
