import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/format/edition_label.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/tema_title.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/action_card.dart';
import '../../../core/widgets/app_mark.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/text_width.dart';
import '../../../core/widgets/tema_card.dart';
import '../../daily/application/daily_providers.dart';
import '../../daily/presentation/daily_question_card.dart';
import '../../mistakes/application/mistakes_providers.dart';
import '../../mock/application/mock_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../quiz/application/figures_providers.dart';
import '../../progress/domain/display_mastery.dart';
import '../../srs/application/srs_providers.dart';
import '../../srs/domain/srs_review.dart' show startOfLocalDay;
import '../../theory/application/theory_providers.dart';

/// Inicio: header, the hero card (pass-probability ring and "Continuar" for
/// the daily queue), the Simulacro and Fallos tiles, the seven temas in one
/// card and the legal footer. A Teoría tile follows the two tiles when the
/// build ships theory, then the Cifras y plazos and Tarjetas de cifras tiles.
/// The "Pregunta del día"
/// card sits under the hero card.
///
/// The daily queue, the question of the day and the mastery use the clock when
/// they are built, so this
/// screen refreshes them when the app returns to the foreground on another
/// day and at midnight while it stays open.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle;
  late DateTime _day;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    _day = startOfLocalDay(ref.read(clockProvider)());
    _lifecycle = AppLifecycleListener(onResume: _refreshIfNewDay);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshIfNewDay() {
    if (!mounted) return;
    final today = startOfLocalDay(ref.read(clockProvider)());
    if (today != _day) {
      _day = today;
      ref
        ..invalidate(dailyQueueProvider)
        ..invalidate(dailyStatusProvider)
        ..invalidate(masteryByIdProvider);
    }
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider)();
    final delay =
        startOfLocalDay(now, plusDays: 1).difference(now.toLocal()) +
        const Duration(seconds: 1);
    _midnight = Timer(delay, _refreshIfNewDay);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;

    // `.value` keeps the previous number while a provider recomputes: no
    // loader after the first value (the ring must not flicker).
    final probability = ref.watch(passProbabilityProvider);
    final queue = ref.watch(dailyQueueProvider).value;
    final mistakes = ref.watch(mistakesProvider(null)).value;
    final summaries = ref.watch(temaSummaryProvider);
    final edition = ref.watch(bootstrapProvider).value?.manifest.edition;
    final resumable = ref.watch(resumableMockProvider);
    final theoryAvailable = ref.watch(theoryAvailableProvider);
    final dailyStatus = ref.watch(dailyStatusProvider).value;
    final figures = ref.watch(figuresCountProvider).value;

    final mockTile = ActionCard(
      icon: Icons.timer_rounded,
      title: l10n.homeMockTitle,
      subtitle: resumable != null
          ? l10n.homeMockResumeSubtitle
          : l10n.homeMockSubtitle,
      onTap: () => context.push('/simulacro'),
    );
    final mistakesTile = ActionCard(
      icon: Icons.fact_check_rounded,
      title: l10n.homeMistakesTitle,
      subtitle: mistakes == null ? null : l10n.mistakesCount(mistakes.length),
      badge: mistakes == null || mistakes.isEmpty ? null : '${mistakes.length}',
      onTap: () => context.push('/fallos'),
    );

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Sp.page,
              Sp.s,
              Sp.page,
              Sp.section,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: Sp.card),
                RaisedCard(
                  padding: const EdgeInsets.all(Sp.cardPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Probability(value: probability.value),
                      const SizedBox(height: Sp.l),
                      PrimaryButton(
                        label: l10n.homeContinue,
                        onPressed: queue == null || queue.isEmpty
                            ? null
                            : () => context.push('/repaso'),
                        content: _ContinueLabel(
                          label: l10n.homeContinue,
                          count: queue == null || queue.isEmpty
                              ? null
                              : l10n.homeContinueCount(queue.length),
                        ),
                        semanticsLabel: [
                          l10n.homeContinue,
                          if (queue != null && queue.isNotEmpty)
                            l10n.homeContinueCount(queue.length),
                        ].join('. '),
                      ),
                      if (queue != null && queue.isEmpty) ...[
                        const SizedBox(height: Sp.m),
                        Text(
                          l10n.homeContinueDone,
                          style: typo.subtitle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                if (dailyStatus?.question != null) ...[
                  const SizedBox(height: Sp.card),
                  DailyQuestionCard(
                    status: dailyStatus!,
                    onOpen: () => context.push('/pregunta-del-dia'),
                  ),
                ],
                const SizedBox(height: Sp.card),
                _Tiles(
                  mockTile: mockTile,
                  mistakesTile: mistakesTile,
                  titles: [l10n.homeMockTitle, l10n.homeMistakesTitle],
                ),
                if (theoryAvailable) ...[
                  const SizedBox(height: Sp.card),
                  ActionCard(
                    icon: Icons.menu_book_rounded,
                    title: l10n.homeTheoryTitle,
                    subtitle: l10n.homeTheorySubtitle,
                    onTap: () => context.push('/teoria'),
                  ),
                ],
                if (figures != null && figures > 0) ...[
                  const SizedBox(height: Sp.card),
                  _figuresTile(context, figures),
                  const SizedBox(height: Sp.card),
                  _figuresTile(context, figures, cards: true),
                ],
                const SizedBox(height: Sp.section),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                  child: Overline(l10n.homeTemasTitle),
                ),
                const SizedBox(height: Sp.s),
                RaisedCard(
                  child: summaries.hasError && !summaries.hasValue
                      ? ErrorState(
                          title: l10n.loadErrorTitle,
                          compact: true,
                          onRetry: () => ref.invalidate(temaSummaryProvider),
                        )
                      : Column(
                          children: [
                            for (final (i, summary)
                                in (summaries.value ?? const []).indexed) ...[
                              if (i > 0) const CardDivider(),
                              TemaCard(
                                tema: summary.tema,
                                title: l10n.temaTitle(summary.tema),
                                mastery: displayMastery(summary.mastery),
                                mistakes: summary.mistakesCount,
                                // Coverage > 0: the tema has been answered at
                                // least once.
                                hasAttempts: summary.coverage > 0,
                                onTap: () =>
                                    context.push('/tema/${summary.tema}'),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: Sp.l),
                Text(
                  l10n.legalDisclaimer,
                  style: typo.caption,
                  textAlign: TextAlign.center,
                ),
                if (edition != null) ...[
                  const SizedBox(height: Sp.s),
                  Text(
                    l10n.bankEdition(editionLabel(edition)),
                    style: typo.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cifras y plazos and its flashcards share the whole figures bank.
Widget _figuresTile(BuildContext context, int count, {bool cards = false}) {
  final l10n = context.l10n;
  return ActionCard(
    icon: cards ? Icons.style_rounded : Icons.pin_rounded,
    title: cards ? l10n.homeFiguresCardsTitle : l10n.homeFiguresTitle,
    subtitle: cards
        ? l10n.homeFiguresCardsSubtitle(count)
        : l10n.homeFiguresSubtitle(count),
    onTap: () => context.push(cards ? '/cifras/tarjetas' : '/cifras'),
  );
}

/// Mark and name of the app, and the round settings button.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: Sp.s),
      child: Row(
        children: [
          const AppMark(),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(context.l10n.appTitle, style: context.typo.brand),
            ),
          ),
          // The visible circle ends at the page margin like the cards: move
          // it out by the header's own side padding ([Sp.xs]) and by the gap
          // between its 48 dp box and its 44 dp circle.
          Transform.translate(
            offset: const Offset(Sp.xs + Sp.roundButtonInset, 0),
            child: RoundIconButton(
              icon: Icons.tune_rounded,
              tooltip: context.l10n.homeSettings,
              onPressed: () => context.push('/ajustes'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ring and its label. Side by side when the label fits next to the ring
/// (its longest word on one line), otherwise stacked and centred (small
/// screens, large text).
class _Probability extends StatelessWidget {
  const _Probability({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final ring = ScoreRing(value: value, label: l10n.homePassProbability);
    final longestWord = l10n.homePassProbability
        .toUpperCase()
        .split(' ')
        .reduce((a, b) => a.length >= b.length ? a : b);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - ScoreRing.homeSize - Sp.l;
        final sideBySide =
            textWidth(context, longestWord, typo.overline) + 1 <= room;
        final label = Column(
          crossAxisAlignment: sideBySide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Overline(
              l10n.homePassProbability,
              header: false,
              spoken: false,
              textAlign: sideBySide ? TextAlign.start : TextAlign.center,
            ),
            const SizedBox(height: Sp.xs),
            Text(
              l10n.homeStatusLine,
              style: typo.lead,
              textAlign: sideBySide ? TextAlign.start : TextAlign.center,
            ),
          ],
        );
        if (!sideBySide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ring,
              const SizedBox(height: Sp.l),
              label,
            ],
          );
        }
        return Row(
          children: [
            ring,
            const SizedBox(width: Sp.l),
            Expanded(child: label),
          ],
        );
      },
    );
  }
}

/// The Simulacro and Fallos tiles: two columns, or stacked when a title does
/// not fit in half the width (small screens, large text).
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.mockTile,
    required this.mistakesTile,
    required this.titles,
  });

  final Widget mockTile;
  final Widget mistakesTile;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.label;
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - Sp.card) / 2;
        // Tile padding on both sides, plus a pixel to spare.
        final needed =
            titles
                .map((title) => textWidth(context, title, style))
                .reduce((a, b) => a > b ? a : b) +
            2 * Sp.l +
            1;
        if (needed > half) {
          return Column(
            children: [
              mockTile,
              const SizedBox(height: Sp.card),
              mistakesTile,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mockTile),
              const SizedBox(width: Sp.card),
              Expanded(child: mistakesTile),
            ],
          ),
        );
      },
    );
  }
}

/// Label of the "Continuar" pill: "Continuar · 15 preguntas para hoy" on one
/// line when it fits, otherwise the count under the label.
class _ContinueLabel extends StatelessWidget {
  const _ContinueLabel({required this.label, required this.count});

  final String label;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    if (count == null) return Text(label);
    final style = DefaultTextStyle.of(context).style;
    final countStyle = context.typo.buttonCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The width of the one-line Row below, with a pixel to spare.
        final single =
            textWidth(context, label, style) +
            textWidth(context, '·', style) +
            textWidth(context, count, countStyle) +
            2 * Sp.s +
            1;
        if (single <= constraints.maxWidth) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: Sp.s),
              const Text('·'),
              const SizedBox(width: Sp.s),
              Text(count, style: countStyle),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, textAlign: TextAlign.center),
            Text(count, style: countStyle, textAlign: TextAlign.center),
          ],
        );
      },
    );
  }
}
