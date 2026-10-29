import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/elapsed_time.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/tema_title.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/pill_bar.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/text_width.dart';
import '../../quiz/presentation/practice_screen.dart' show optionLetter;
import '../application/mock_controller.dart';
import '../domain/mock_result.dart';

/// Leaves the result for the previous screen or Inicio.
void _leaveResult(BuildContext context, WidgetRef ref, {bool home = true}) {
  if (!home && context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

/// Result of a handed-in mock: the score ring with the pass mark, APTO /
/// NO APTO, hits per tema and the questions (only the failed ones by default;
/// tap one to review it, with "Anterior / Siguiente" through the list).
class MockResultScreen extends ConsumerWidget {
  const MockResultScreen({super.key, required this.mockId});

  final int mockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = mockOutcomeProvider(mockId);
    final async = ref.watch(provider);
    final outcome = async.value;

    final Widget body;
    if (async.hasError && outcome == null) {
      body = ErrorState(
        title: l10n.loadErrorTitle,
        onRetry: () => ref.invalidate(provider),
      );
    } else if (async.isLoading && outcome == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (outcome == null || !outcome.record.isFinished) {
      body = EmptyState(
        icon: Icons.assignment_late_rounded,
        title: l10n.mockResultNotFinished,
        actionLabel: l10n.backToHome,
        onAction: () => context.go('/'),
        primaryAction: true,
      );
    } else {
      body = _Result(mockId: mockId, outcome: outcome);
    }

    final finished = outcome != null && outcome.record.isFinished;
    void leave() =>
        finished ? _leaveResult(context, ref, home: false) : context.go('/');

    // Normally Inicio is below and back just pops; when the result was opened
    // as the only page (a deep link), back goes to Inicio instead of leaving.
    // A finished result always leaves through [_leaveResult].
    return PopScope(
      canPop: !finished && context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: PageBody(
            child: Column(
              children: [
                Padding(
                  padding: Sp.headerInsets,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RoundIconButton(
                      icon: Icons.close_rounded,
                      tooltip: l10n.backToHome,
                      onPressed: leave,
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends ConsumerStatefulWidget {
  const _Result({required this.mockId, required this.outcome});

  final int mockId;
  final MockOutcome outcome;

  @override
  ConsumerState<_Result> createState() => _ResultState();
}

class _ResultState extends ConsumerState<_Result> {
  /// "Solo falladas": on by default, the list shows the failed questions
  /// only; off shows all of them.
  bool _onlyFailed = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final mockId = widget.mockId;
    final outcome = widget.outcome;
    final finishedAt = outcome.record.finishedAt;
    final result = outcome.result;
    final ratioStyle = AptoTypography.tabular(context.typo.subtitle);
    final ratioWidth = result.perTema.values.fold<double>(0, (width, score) {
      final measured = textWidth(
        context,
        l10n.ratio(score.correct, score.total),
        ratioStyle,
      );
      return measured > width ? measured : width;
    });
    final passed = result.passed;
    final failed = outcome.failedIndices;
    final shown = _onlyFailed
        ? failed
        : [for (var i = 0; i < outcome.questions.length; i++) i];

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScoreCard(
              result: result,
              passed: passed,
              elapsed: finishedAt?.difference(outcome.record.startedAt),
            ),
            const SizedBox(height: Sp.section),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
              child: Overline(l10n.mockResultPerTema),
            ),
            const SizedBox(height: Sp.s),
            RaisedCard(
              child: Column(
                children: [
                  for (final (i, entry) in result.perTema.entries.indexed) ...[
                    if (i > 0) const CardDivider(),
                    _TemaRow(
                      tema: entry.key,
                      correct: entry.value.correct,
                      total: entry.value.total,
                      ratioWidth: ratioWidth,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Sp.section),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
              child: Overline(l10n.mockResultQuestionsTitle),
            ),
            const SizedBox(height: Sp.s),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(l10n.mockResultOnlyFailed),
                selected: _onlyFailed,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (value) => setState(() => _onlyFailed = value),
              ),
            ),
            const SizedBox(height: Sp.s),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                child: Text(
                  l10n.mockResultNoFailed,
                  style: context.typo.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              RaisedCard(
                child: Column(
                  children: [
                    for (final (i, index) in shown.indexed) ...[
                      if (i > 0) const CardDivider(),
                      _QuestionRow(
                        number: index + 1,
                        stem: outcome.questions[index].stem,
                        correct: !failed.contains(index),
                        answerLetter: outcome.record.answers[index] == null
                            ? null
                            : optionLetter(outcome.record.answers[index]!),
                        onTap: () => context.push(
                          '/simulacro/$mockId/revision/$index'
                          '${_onlyFailed ? '?falladas=1' : ''}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: Sp.section),
            if (failed.isNotEmpty) ...[
              PrimaryButton(
                label: l10n.mockResultReviewMistakesCount(failed.length),
                onPressed: () => context.push('/simulacro/$mockId/repasar'),
              ),
              const SizedBox(height: Sp.m),
              SecondaryButton(
                label: l10n.backToHome,
                onPressed: () => _leaveResult(context, ref),
              ),
            ] else
              PrimaryButton(
                label: l10n.backToHome,
                onPressed: () => _leaveResult(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

/// The ring with the score and the pass-mark tick, the APTO / NO APTO pill and
/// the caption that explains the tick.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.result,
    required this.passed,
    required this.elapsed,
  });

  final MockResult result;
  final bool passed;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final correct = result.correct;
    final total = result.total;
    final passMark = result.passMark;
    final tone = passed ? colors.correct : colors.incorrect;
    final toneText = passed ? colors.correctText : colors.incorrectText;
    final toneFill = passed
        ? colors.correctContainer
        : colors.incorrectContainer;

    return RaisedCard(
      padding: const EdgeInsets.all(Sp.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ScoreRing(
              value: total == 0 ? 0 : correct / total,
              size: ScoreRing.resultSize,
              strokeWidth: ScoreRing.resultStroke,
              color: tone,
              passMark: total == 0 ? null : passMark / total,
              semanticsLabel: l10n.correctOfSemantics(correct, total),
              // Scaled down (never clipped) when the text size is huge.
              center: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$correct', style: typo.display),
                    Text(l10n.mockResultOutOf(total), style: typo.subtitle),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Sp.l),
          Center(
            child: Semantics(
              header: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: toneFill,
                  borderRadius: Rad.pillRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.xl,
                    vertical: Sp.s,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passed
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: IconSize.base,
                        color: tone,
                      ),
                      const SizedBox(width: Sp.s),
                      Flexible(
                        child: Text(
                          passed
                              ? l10n.mockResultPassed
                              : l10n.mockResultFailed,
                          style: typo.badge.copyWith(color: toneText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Sp.m),
          Text(
            l10n.mockResultPassMarkHint(passMark),
            style: typo.subtitle,
            textAlign: TextAlign.center,
          ),
          if (elapsed != null) ...[
            const SizedBox(height: Sp.s),
            Text(
              l10n.mockResultElapsedTime(formatElapsedTime(elapsed!, l10n)),
              style: AptoTypography.tabular(typo.subtitle),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TemaRow extends StatelessWidget {
  const _TemaRow({
    required this.tema,
    required this.correct,
    required this.total,
    required this.ratioWidth,
  });

  final int tema;
  final int correct;
  final int total;
  final double ratioWidth;

  /// Width of the thin bar when it sits beside the title.
  static const double barWidth = 64;

  /// Narrowest title column worth keeping beside the bar; below it the bar
  /// moves under the title.
  static const double minTitleWidth = 120;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final ratioStyle = AptoTypography.tabular(typo.subtitle);
    final ratio = l10n.ratio(correct, total);
    final titleText = l10n.temaTitle(tema);
    final bar = PillBar(
      value: total == 0 ? 0 : correct / total,
      height: PillBar.thin,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
      child: Semantics(
        label: l10n.mockResultHeaderSemantics(
          l10n.temaLabel(tema),
          titleText,
          l10n.correctOfSemantics(correct, total),
        ),
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final numberWidth = Sp.xxl + Sp.s;
            final fixed = numberWidth + 2 * Sp.m + barWidth;
            final titleRoom = constraints.maxWidth - fixed - ratioWidth;
            // Side by side only when the longest word of the title fits on
            // one line (it would be split in the middle otherwise).
            // Every row uses the same breakpoint, including the longest
            // word across all tema titles, and the same score column.
            final longestWordWidth = [
              for (var t = 1; t <= 7; t++)
                for (final word in l10n.temaTitle(t).split(' '))
                  textWidth(context, word, typo.rowTitle),
            ].reduce((a, b) => a > b ? a : b);
            final score = SizedBox(
              width: ratioWidth,
              child: Text(ratio, style: ratioStyle, textAlign: TextAlign.end),
            );
            final stacked =
                titleRoom < minTitleWidth || longestWordWidth + 1 > titleRoom;
            final title = Text(titleText, style: typo.rowTitle);
            final number = SizedBox(
              width: Sp.xxl,
              child: Text(
                '$tema',
                style: AptoTypography.tabular(
                  typo.label.copyWith(color: colors.primary),
                ),
              ),
            );
            if (stacked) {
              // The title takes the whole width; the bar and the figure
              // share the line under it.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  number,
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: Sp.s),
                        Row(
                          children: [
                            Expanded(child: bar),
                            const SizedBox(width: Sp.m),
                            score,
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                number,
                const SizedBox(width: Sp.s),
                Expanded(child: title),
                const SizedBox(width: Sp.m),
                SizedBox(width: barWidth, child: bar),
                const SizedBox(width: Sp.m),
                score,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A question of the list: ✗ (failed or blank) or ✓ (right), its stem and
/// the letter the user picked.
class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.number,
    required this.stem,
    required this.correct,
    required this.answerLetter,
    required this.onTap,
  });

  final int number;
  final String stem;
  final bool correct;

  /// Letter the user picked; null = left blank.
  final String? answerLetter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final picked = answerLetter;
    final yours = picked == null
        ? l10n.mockResultUnanswered
        : l10n.mockReviewYourAnswer(picked);
    final status = correct
        ? l10n.mockResultRowCorrect
        : l10n.mockResultRowFailed;
    return Semantics(
      button: true,
      label: l10n.mockResultRowSemantics(number, stem, status, yours),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: correct
                        ? colors.correctContainer
                        : colors.incorrectContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: Sp.xxl,
                    child: Icon(
                      correct ? Icons.check_rounded : Icons.close_rounded,
                      size: IconSize.inline,
                      color: correct ? colors.correct : colors.incorrect,
                    ),
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mockResultRowTitle(number, stem),
                        style: typo.rowTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Sp.xs),
                      Text(yours, style: typo.subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.s),
                Icon(
                  Icons.chevron_right_rounded,
                  size: IconSize.base,
                  color: colors.outlineStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
