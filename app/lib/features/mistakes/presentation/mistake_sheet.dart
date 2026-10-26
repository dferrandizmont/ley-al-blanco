import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/explanation_body.dart';
import '../../../core/widgets/option_card.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../content/domain/question.dart';
import '../../quiz/application/quiz_providers.dart';
import '../../quiz/domain/attempt.dart';
import '../../quiz/presentation/practice_screen.dart' show optionLetter;
import '../../theory/application/theory_providers.dart';

/// Opens the ficha of a failed [question]: the stem, the options with the
/// official answer marked (and the one the user picked last time), our
/// explanation, a way to the tema's theory and a way to practise it.
///
/// [onPractice] runs after the sheet is closed (it opens the review starting
/// at this question). [practiceLabel] replaces the label of that button when
/// it does something else (the question search opens the tema's practice for a
/// question that was never failed).
Future<void> showMistakeSheet(
  BuildContext context, {
  required Question question,
  required VoidCallback onPractice,
  String? practiceLabel,
}) {
  // The router outlives the sheet: grab it before the sheet closes.
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => MistakeSheet(
      question: question,
      practiceLabel: practiceLabel,
      onTheory: () {
        Navigator.of(sheetContext).pop();
        router.push('/teoria/t${question.tema}');
      },
      onPractice: () {
        Navigator.of(sheetContext).pop();
        onPractice();
      },
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// Body of the ficha de fallo (see [showMistakeSheet]).
class MistakeSheet extends ConsumerWidget {
  const MistakeSheet({
    super.key,
    required this.question,
    required this.onTheory,
    required this.onPractice,
    required this.onClose,
    this.practiceLabel,
  });

  final Question question;

  /// Label of the practice button; null = «Practicar esta pregunta».
  final String? practiceLabel;
  final VoidCallback onTheory;
  final VoidCallback onPractice;
  final VoidCallback onClose;

  /// The most recent wrong attempt of [id] (attempts come oldest first), or
  /// null when there is none.
  static Attempt? _lastWrong(List<Attempt>? attempts, String id) {
    if (attempts == null) return null;
    for (final attempt in attempts.reversed) {
      if (attempt.questionId == id && !attempt.correct) return attempt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final lastWrong = _lastWrong(
      ref.watch(attemptsProvider).value,
      question.id,
    );
    // null with a wrong attempt = a mock question left blank.
    final picked = lastWrong?.selected;
    final hasTheory = ref.watch(theoryAvailableProvider);

    OptionState stateOf(int i) {
      if (i == picked && !question.isCorrect(i)) return OptionState.incorrect;
      if (i == question.answer) return OptionState.revealedCorrect;
      return OptionState.idle;
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.temaLabel(question.tema),
                      style: typo.subtitle,
                    ),
                  ),
                ),
                RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: l10n.close,
                  onPressed: onClose,
                ),
              ],
            ),
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
            if (lastWrong != null) ...[
              const SizedBox(height: Sp.m),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      picked == null
                          ? Icons.remove_circle_outline_rounded
                          : Icons.close_rounded,
                      size: IconSize.inline,
                      color: picked == null
                          ? colors.textSecondary
                          : colors.incorrectText,
                    ),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: Text(
                        picked == null
                            ? l10n.mockResultUnanswered
                            : l10n.mistakeSheetLastAnswer(optionLetter(picked)),
                        style: typo.body.copyWith(
                          color: picked == null
                              ? colors.textSecondary
                              : colors.incorrectText,
                        ),
                      ),
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
                correct: null,
                correctLetter: optionLetter(question.answer),
                correctText: question.options[question.answer],
                explanation: question.explanation,
                article: question.article,
                notice: question.notice,
                report: ReportTarget.fromQuestion(question),
              ),
            ),
            const SizedBox(height: Sp.xl),
            PrimaryButton(
              label: practiceLabel ?? l10n.mistakeSheetPractice,
              icon: Icons.replay_rounded,
              onPressed: onPractice,
            ),
            if (hasTheory) ...[
              const SizedBox(height: Sp.m),
              SecondaryButton(
                label: l10n.mistakeSheetTheory(question.tema),
                icon: Icons.menu_book_rounded,
                onPressed: onTheory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
