import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/explanation_body.dart';
import '../../../core/widgets/option_card.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/text_width.dart';
import '../../quiz/presentation/practice_screen.dart' show optionLetter;
import '../application/mock_controller.dart';

/// Read-only look at the questions of a handed-in mock: the user's answer, the
/// official one and the explanation, with "Anterior / Siguiente" through the
/// list the user came from.
///
/// With [onlyFailed] (the result's "Solo falladas" filter) the walk covers the
/// failed and blank questions only; otherwise all of them. [index] is where it
/// opens; when the filter is on and that question was right the walk covers
/// them all, so the question shown is always in it.
class MockReviewScreen extends ConsumerStatefulWidget {
  const MockReviewScreen({
    super.key,
    required this.mockId,
    required this.index,
    this.onlyFailed = false,
  });

  final int mockId;

  /// 0-based position of the question in the mock.
  final int index;

  /// Walk only the failed (and blank) questions.
  final bool onlyFailed;

  @override
  ConsumerState<MockReviewScreen> createState() => _MockReviewScreenState();
}

class _MockReviewScreenState extends ConsumerState<MockReviewScreen> {
  /// The question on screen (0-based); starts at [MockReviewScreen.index].
  late int _index = widget.index;

  @override
  void didUpdateWidget(covariant MockReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mockId != widget.mockId ||
        oldWidget.index != widget.index ||
        oldWidget.onlyFailed != widget.onlyFailed) {
      _index = widget.index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = mockOutcomeProvider(widget.mockId);
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
    } else if (outcome == null ||
        !outcome.record.isFinished ||
        _index < 0 ||
        _index >= outcome.questions.length) {
      body = EmptyState(
        icon: Icons.assignment_late_rounded,
        title: l10n.mockResultNotFinished,
        actionLabel: l10n.backToHome,
        onAction: () => context.go('/'),
        primaryAction: true,
      );
    } else {
      final failed = outcome.failedIndices;
      final walk = widget.onlyFailed && failed.contains(_index)
          ? failed
          : [for (var i = 0; i < outcome.questions.length; i++) i];
      final at = walk.indexOf(_index);
      body = _Review(
        key: ValueKey(_index),
        outcome: outcome,
        index: _index,
        onPrevious: at > 0 ? () => setState(() => _index = walk[at - 1]) : null,
        onNext: at < walk.length - 1
            ? () => setState(() => _index = walk[at + 1])
            : null,
      );
    }

    return Scaffold(
      appBar: AptoAppBar(title: l10n.mockReviewTitle),
      body: SafeArea(child: PageBody(child: body)),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({
    super.key,
    required this.outcome,
    required this.index,
    required this.onPrevious,
    required this.onNext,
  });

  final MockOutcome outcome;
  final int index;

  /// Null = there is no previous / next question in the walk.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Whether the two buttons do not fit side by side (small screens, large
  /// text): then they stack, full width.
  bool _barNeedsStack(BuildContext context, double width) {
    final l10n = context.l10n;
    final style = context.typo.label;
    final widest = [l10n.previous, l10n.next]
        .map((label) => textWidth(context, label, style))
        .reduce((a, b) => a > b ? a : b);
    // Icon, its gap and the horizontal padding of a button, plus a pixel.
    final needed = widest + IconSize.button + Sp.s + 2 * Sp.xl + 1;
    final half = (width - 2 * Sp.page - Sp.m) / 2;
    return needed > half;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final question = outcome.questions[index];
    final picked = outcome.record.answers[index];

    OptionState stateOf(int i) {
      if (i == picked) {
        return question.isCorrect(i)
            ? OptionState.correct
            : OptionState.incorrect;
      }
      if (i == question.answer) return OptionState.revealedCorrect;
      return OptionState.idle;
    }

    final position = Padding(
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.s),
      child: Semantics(
        header: true,
        child: Text(
          l10n.mockReviewPosition(index + 1, outcome.questions.length),
          style: AptoTypography.tabular(typo.subtitle),
        ),
      ),
    );
    final card = RaisedCard(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.xl, Sp.l, Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Text(question.stem, style: typo.stem),
          ),
          const SizedBox(height: Sp.xl),
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: Sp.m),
            OptionCard(
              letter: optionLetter(i),
              text: question.options[i],
              state: stateOf(i),
            ),
          ],
          if (picked == null) ...[
            const SizedBox(height: Sp.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.remove_circle_outline_rounded,
                    size: IconSize.inline,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: Sp.s),
                  Text(
                    l10n.mockResultUnanswered,
                    style: typo.body.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Sp.l),
          const CardDivider(),
          const SizedBox(height: Sp.l),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: ExplanationBody(
              correct: picked == null ? null : question.isCorrect(picked),
              correctLetter: optionLetter(question.answer),
              correctText: question.options[question.answer],
              explanation: question.explanation,
              article: question.article,
              notice: question.notice,
              report: ReportTarget.fromQuestion(question),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = _barNeedsStack(context, constraints.maxWidth);
        final bar = _Bar(
          stacked: stacked,
          onPrevious: onPrevious,
          onNext: onNext,
        );
        final cardPadding = const EdgeInsets.fromLTRB(
          Sp.page,
          0,
          Sp.page,
          Sp.section,
        );
        // With very large text or a narrow screen the pinned bar would eat
        // the screen, so it scrolls with the question instead.
        final hugeText = MediaQuery.textScalerOf(context).scale(100) > 150;
        if (hugeText || stacked) {
          return ListView(
            children: [
              position,
              Padding(padding: cardPadding, child: card),
              bar,
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  position,
                  Padding(padding: cardPadding, child: card),
                ],
              ),
            ),
            bar,
          ],
        );
      },
    );
  }
}

/// "Anterior" / "Siguiente" through the questions of the review.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.stacked,
    required this.onPrevious,
    required this.onNext,
  });

  final bool stacked;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previous = SecondaryButton(
      label: l10n.previous,
      icon: Icons.arrow_back_rounded,
      onPressed: onPrevious,
    );
    final next = SecondaryButton(
      label: l10n.next,
      icon: Icons.arrow_forward_rounded,
      trailingIcon: true,
      onPressed: onNext,
    );
    return Container(
      color: context.colors.background,
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, Sp.m),
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                previous,
                const SizedBox(height: Sp.s),
                next,
              ],
            )
          : Row(
              children: [
                Expanded(child: previous),
                const SizedBox(width: Sp.m),
                Expanded(child: next),
              ],
            ),
    );
  }
}
