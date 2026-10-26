import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/explanation_body.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/progress_header.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
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
                      child: ExplanationBody(
                        correct: true,
                        correctLetter: String.fromCharCode(
                          0x41 + value.current.answer,
                        ),
                        correctText:
                            value.current.options[value.current.answer],
                        explanation: value.current.explanation,
                        article: value.current.article,
                        notice: value.current.notice,
                      ),
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
