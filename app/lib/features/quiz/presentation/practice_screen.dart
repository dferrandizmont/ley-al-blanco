import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/tema_title.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/explanation_body.dart';
import '../../../core/widgets/option_card.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/progress_header.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../application/practice_controller.dart';
import '../domain/practice_source.dart';
import '../domain/quiz_session.dart';

/// Practice by tema, the daily queue, the Fallos review, the review of one
/// mock's failures, the figures mode and the question of the day: one screen,
/// six sources (see [PracticeSource]).
///
/// Flow: pick an option (it locks, shows check / cross, the attempt is saved),
/// the explanation opens inside the question card and a floating "Siguiente"
/// pill appears over the scrolling content ("Terminar" on the last question);
/// after the last question a summary with the hit count.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key, required this.source});

  final PracticeSource source;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/');

  /// Leaves the summary for the previous screen or Inicio.
  void _leaveSummary(BuildContext context, WidgetRef ref, {bool home = true}) {
    if (!home && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = practiceControllerProvider(source);
    ref.listen(provider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before != null &&
          after != null &&
          after.saveErrors > before.saveErrors) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.practiceSaveError)),
          );
      }
    });
    final async = ref.watch(provider);
    final l10n = context.l10n;
    final finished = async.value?.finished ?? false;

    final Widget body = switch (async) {
      AsyncData(:final value) => _content(context, ref, value),
      AsyncError() => _withClose(
        context,
        ErrorState(
          title: l10n.loadErrorTitle,
          onRetry: () => ref.invalidate(provider),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    // On the summary, back leaves through [_leaveSummary].
    return PopScope(
      canPop: !finished,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leaveSummary(context, ref, home: false);
      },
      child: Scaffold(
        body: SafeArea(child: PageBody(child: body)),
      ),
    );
  }

  /// A state screen (empty, error) under a lone round close button.
  Widget _withClose(BuildContext context, Widget child) => Column(
    children: [
      Padding(
        padding: Sp.headerInsets,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RoundIconButton(
            icon: Icons.close_rounded,
            tooltip: context.l10n.close,
            onPressed: () => _close(context),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );

  Widget _content(BuildContext context, WidgetRef ref, PracticeState state) {
    final l10n = context.l10n;
    final controller = ref.read(practiceControllerProvider(source).notifier);
    final session = state.session;
    if (session == null) {
      final (icon, title, message) = switch (source) {
        DailyPractice() => (
          Icons.event_available_rounded,
          l10n.practiceEmptyDailyTitle,
          l10n.practiceEmptyDailyMessage,
        ),
        FiguresPractice() => (
          Icons.pin_rounded,
          l10n.figuresEmptyTitle,
          l10n.figuresEmptyMessage,
        ),
        DailyQuestionPractice() => (
          Icons.event_available_rounded,
          l10n.dailyEmptyTitle,
          l10n.dailyEmptyMessage,
        ),
        _ => (
          Icons.task_alt_rounded,
          l10n.practiceEmptyMistakesTitle,
          l10n.practiceEmptyMistakesMessage,
        ),
      };
      return _withClose(
        context,
        EmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: l10n.backToHome,
          onAction: () => context.go('/'),
          primaryAction: true,
        ),
      );
    }
    if (state.finished) {
      return _Summary(
        session: session,
        onLeave: () => _leaveSummary(context, ref),
      );
    }

    final index = session.currentIndex;
    final answered = session.isAnswered(index);
    final showNext = answered && !state.saving;
    final title = switch (source) {
      TemaPractice(:final tema) => l10n.practiceTemaTitle(
        l10n.temaLabel(tema),
        l10n.temaTitle(tema),
      ),
      DailyPractice() => l10n.practiceDailyTitle,
      MistakesPractice() => l10n.practiceMistakesTitle,
      MockMistakesPractice() => l10n.practiceMockMistakesTitle,
      FiguresPractice() => l10n.practiceFiguresTitle,
      DailyQuestionPractice() => l10n.practiceDailyQuestionTitle,
    };
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: Sp.headerInsets,
              child: ProgressHeader(
                current: index + 1,
                total: session.length,
                completed: session.answeredCount,
                leading: RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: l10n.close,
                  onPressed: () => _close(context),
                ),
              ),
            ),
            Expanded(
              child: ScrollEdgeFade(
                key: ValueKey('question-fade-$index'),
                child: SingleChildScrollView(
                  key: ValueKey('question-$index'),
                  padding: EdgeInsets.fromLTRB(
                    Sp.page,
                    Sp.s,
                    Sp.page,
                    showNext ? Sp.floatingClearance : Sp.section,
                  ),
                  child: _QuestionCard(
                    title: title,
                    session: session,
                    onPick: state.saving ? null : controller.answer,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showNext)
          Positioned(
            left: Sp.page,
            right: Sp.page,
            bottom: Sp.floatingMargin,
            child: PrimaryButton(
              label: session.isLastQuestion ? l10n.practiceFinish : l10n.next,
              floating: true,
              // One question, no summary: "Terminar" goes back to Inicio.
              onPressed: source is DailyQuestionPractice
                  ? () => _close(context)
                  : controller.next,
            ),
          ),
      ],
    );
  }
}

/// The question card: tema label, stem, the three option cards and, once
/// answered, the explanation under a divider.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.session,
    required this.onPick,
  });

  final String title;
  final QuizSession session;

  /// Null while locked (saving).
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    final question = session.currentQuestion;
    final feedback = session.feedbackFor(session.currentIndex);
    return RaisedCard(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.xl, Sp.l, Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Overline(title),
          ),
          const SizedBox(height: Sp.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Text(question.stem, style: context.typo.stem),
          ),
          const SizedBox(height: Sp.xl),
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: Sp.m),
            OptionCard(
              letter: optionLetter(i),
              text: question.options[i],
              state: _stateOf(i, feedback),
              onTap: feedback != null || onPick == null
                  ? null
                  : () => onPick!(i),
            ),
          ],
          if (feedback != null) ...[
            const SizedBox(height: Sp.l),
            const CardDivider(),
            const SizedBox(height: Sp.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
              child: ExplanationBody(
                correct: feedback.isCorrect,
                correctLetter: optionLetter(question.answer),
                correctText: question.options[question.answer],
                explanation: question.explanation,
                article: question.article,
                notice: question.notice,
                report: ReportTarget.fromQuestion(question),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static OptionState _stateOf(int i, AnswerFeedback? feedback) {
    if (feedback == null) return OptionState.idle;
    if (i == feedback.selected) {
      return feedback.isCorrect ? OptionState.correct : OptionState.incorrect;
    }
    if (i == feedback.correctIndex) return OptionState.revealedCorrect;
    return OptionState.idle;
  }
}

/// "A", "B", "C": the option's position in the questionnaire.
String optionLetter(int index) => String.fromCharCode(0x41 + index);

/// End of a session: hits out of questions, back to Inicio.
class _Summary extends StatelessWidget {
  const _Summary({required this.session, required this.onLeave});

  final QuizSession session;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.page),
        child: RaisedCard(
          padding: const EdgeInsets.all(Sp.cardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.practiceSummaryTitle,
                  style: typo.title,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Sp.xl),
              Semantics(
                label: l10n.correctOfSemantics(
                  session.correctCount,
                  session.length,
                ),
                excludeSemantics: true,
                child: Text(
                  l10n.ratio(session.correctCount, session.length),
                  style: typo.display,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Sp.xs),
              Text(
                l10n.practiceSummaryScore,
                style: typo.body.copyWith(color: context.colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.x3),
              PrimaryButton(label: l10n.backToHome, onPressed: onLeave),
            ],
          ),
        ),
      ),
    );
  }
}
