import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/article_chip.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/notice_callout.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/progress_header.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../content/domain/question.dart';
import '../../theory/domain/theory.dart' show foldForSearch;
import '../application/figures_cards_controller.dart';

/// A button reveals the answer instantly, including with reduced motion.
/// All content and actions scroll together, including on a small screen.
class FiguresCardsScreen extends ConsumerWidget {
  const FiguresCardsScreen({super.key});

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(figuresCardsControllerProvider);
    final value = async.value;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: Column(
            children: [
              Padding(
                padding: Sp.headerInsets,
                child: value != null && !value.isEmpty && !value.finished
                    ? ProgressHeader(
                        current: value.position,
                        total: value.total,
                        completed: value.completed,
                        leading: RoundIconButton(
                          icon: Icons.close_rounded,
                          tooltip: l10n.close,
                          onPressed: () => _close(context),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: RoundIconButton(
                          icon: Icons.close_rounded,
                          tooltip: l10n.close,
                          onPressed: () => _close(context),
                        ),
                      ),
              ),
              Expanded(
                child: switch (async) {
                  AsyncData(:final value) => _content(context, ref, value),
                  AsyncError() => ErrorState(
                    title: l10n.loadErrorTitle,
                    onRetry: () =>
                        ref.invalidate(figuresCardsControllerProvider),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    FiguresCardsState value,
  ) {
    final l10n = context.l10n;
    final controller = ref.read(figuresCardsControllerProvider.notifier);
    if (value.isEmpty) {
      return EmptyState(
        icon: Icons.style_rounded,
        title: l10n.figuresEmptyTitle,
        message: l10n.figuresEmptyMessage,
        actionLabel: l10n.backToHome,
        primaryAction: true,
        onAction: () => context.go('/'),
      );
    }
    return SingleChildScrollView(
      // Reset the scroll for every new face, including a lone requeued card.
      key: ValueKey(value),
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.section),
      child: RaisedCard(
        padding: const EdgeInsets.all(Sp.cardPad),
        child: value.finished
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      l10n.figuresCardsSummary(
                        value.knownFirstTry,
                        value.total,
                      ),
                      style: AptoTypography.tabular(context.typo.title),
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  if (value.reviewed.isNotEmpty) ...[
                    PrimaryButton(
                      label: l10n.figuresCardsRestart,
                      onPressed: controller.restartReviewed,
                    ),
                    const SizedBox(height: Sp.m),
                  ],
                  SecondaryButton(
                    label: l10n.figuresCardsBack,
                    onPressed: () => _close(context),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Overline(l10n.homeFiguresCardsTitle),
                  const SizedBox(height: Sp.m),
                  Text(
                    value.current.stem,
                    style: context.typo.stem.copyWith(
                      fontSize: context.typo.brand.fontSize,
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  if (!value.revealed)
                    PrimaryButton(
                      label: l10n.figuresCardsReveal,
                      onPressed: controller.reveal,
                    )
                  else ...[
                    Semantics(
                      liveRegion: true,
                      child: _CardAnswer(question: value.current),
                    ),
                    const SizedBox(height: Sp.xl),
                    PrimaryButton(
                      label: l10n.figuresCardsKnown,
                      onPressed: () => controller.answer(known: true),
                    ),
                    const SizedBox(height: Sp.m),
                    SecondaryButton(
                      label: l10n.figuresCardsAgain,
                      onPressed: () => controller.answer(known: false),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Revealing a card gives information, before the learner assesses recall.
class _CardAnswer extends StatelessWidget {
  const _CardAnswer({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final answer = question.options[question.answer];
    final showOptions = RegExp(
      r'^(?:las (?:dos|tres) anteriores|las respuestas anteriores|'
      r'ninguna de las anteriores|ambas|'
      r'son correctas las dos respuestas anteriores)\b',
    ).hasMatch(foldForSearch(answer.trimLeft()));
    final explanation = question.explanation?.trim();
    final pending = explanation == null || explanation.isEmpty;
    final notice = question.notice?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.figuresCardAnswerLabel, style: typo.verdict),
        ),
        const SizedBox(height: Sp.m),
        for (final (i, option) in question.options.indexed)
          if (showOptions || i == question.answer)
            Padding(
              padding: EdgeInsets.only(bottom: showOptions ? Sp.s : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showOptions && i == question.answer) ...[
                    Icon(
                      Icons.check_rounded,
                      size: IconSize.base,
                      color: colors.correct,
                      semanticLabel: l10n.explanationCorrectAnswer,
                    ),
                    const SizedBox(width: Sp.s),
                  ],
                  Expanded(
                    child: Text(
                      l10n.explanationAnswerLine(
                        String.fromCharCode(0x41 + i),
                        option,
                      ),
                      style: AptoTypography.weight(typo.body, 600).copyWith(
                        color: showOptions && i == question.answer
                            ? colors.correctText
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: Sp.l),
        if (notice != null && notice.isNotEmpty) ...[
          NoticeCallout(text: notice),
          const SizedBox(height: Sp.l),
        ],
        Text(l10n.explanationHeading, style: typo.caption),
        const SizedBox(height: Sp.xs),
        Text(
          pending ? l10n.explanationPending : explanation,
          style: pending
              ? typo.body.copyWith(color: colors.textSecondary)
              : typo.body,
        ),
        if (question.article != null) ...[
          const SizedBox(height: Sp.l),
          ArticleChip(article: question.article!),
        ],
      ],
    );
  }
}
