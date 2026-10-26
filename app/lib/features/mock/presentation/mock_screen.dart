import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/mock_navigator.dart';
import '../../../core/widgets/option_card.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/progress_header.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../../../core/widgets/text_width.dart';
import '../../quiz/domain/quiz_session.dart';
import '../../quiz/presentation/practice_screen.dart' show optionLetter;
import '../application/mock_controller.dart';
import '../application/mock_providers.dart' show mockRepositoryProvider;
import '../domain/mock_timer.dart';

/// A mock exam in progress: stem, three options (no feedback), a toggle to
/// mark the question as doubtful, previous / next, the navigator of all
/// questions (answered, unanswered, doubtful), an optional indicative
/// countdown and "Entregar" (with a confirmation that states how many are
/// doubtful and how many unanswered).
class MockScreen extends ConsumerStatefulWidget {
  const MockScreen({super.key, required this.mockId});

  final int mockId;

  @override
  ConsumerState<MockScreen> createState() => _MockScreenState();
}

class _MockScreenState extends ConsumerState<MockScreen> {
  bool _redirecting = false;

  MockController get _controller =>
      ref.read(mockControllerProvider(widget.mockId).notifier);

  String get _resultPath => '/simulacro/${widget.mockId}/resultado';

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirm,
    required String cancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit(MockState state) async {
    final l10n = context.l10n;
    final unanswered = state.unansweredCount;
    final doubtful = state.flaggedCount;
    final body = switch ((doubtful > 0, unanswered > 0)) {
      (true, true) => l10n.mockFlagSubmitBoth(doubtful, unanswered),
      (true, false) => l10n.mockFlagSubmitDoubtful(doubtful),
      _ => l10n.mockSubmitUnanswered(unanswered),
    };
    final ok = await _confirm(
      title: l10n.mockSubmitTitle,
      body: body,
      confirm: l10n.mockSubmit,
      cancel: l10n.mockSubmitKeep,
    );
    if (!ok || !mounted) return;
    try {
      await _controller.submit();
    } catch (_) {
      // "Already finished" (handed in elsewhere, or by an earlier attempt whose
      // answer got lost) is not a failure: the result is there.
      final finished = await _isFinished();
      if (!mounted) return;
      if (finished) {
        _showResult();
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.practiceSaveError)));
      return;
    }
    if (!mounted) return;
    _showResult();
  }

  /// Replace the exam: Inicio stays below, back from the result returns to it.
  void _showResult() {
    _redirecting = true; // `build` must not redirect a second time
    context.pushReplacement(_resultPath);
  }

  /// Whether the stored mock is already handed in.
  Future<bool> _isFinished() async {
    try {
      final record = await ref.read(mockRepositoryProvider).byId(widget.mockId);
      return record?.isFinished ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _leave() async {
    final l10n = context.l10n;
    final ok = await _confirm(
      title: l10n.mockLeaveTitle,
      body: l10n.mockLeaveBody,
      confirm: l10n.mockLeaveConfirm,
      cancel: l10n.mockSubmitKeep,
    );
    if (ok && mounted) context.go('/');
  }

  Future<void> _openNavigator(MockState state) async {
    final session = state.session;
    final l10n = context.l10n;
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.mockNavigatorTitle, style: context.typo.brand),
              ),
              const SizedBox(height: Sp.s),
              Text(
                l10n.mockFlagSummary(state.flaggedCount, state.unansweredCount),
                style: context.typo.subtitle,
              ),
              const SizedBox(height: Sp.l),
              MockNavigator(
                count: session.length,
                current: session.currentIndex,
                answered: {
                  for (var i = 0; i < session.length; i++)
                    if (session.isAnswered(i)) i,
                },
                flagged: state.flaggedIndices,
                onTap: (i) => Navigator.of(sheetContext).pop(i),
              ),
              const SizedBox(height: Sp.l),
              const MockNavigatorLegend(),
            ],
          ),
        ),
      ),
    );
    if (index != null) _controller.goTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = mockControllerProvider(widget.mockId);
    final async = ref.watch(provider);
    final l10n = context.l10n;

    final state = async.value;
    if (state != null && state.isSubmitted && !_redirecting) {
      // Opened already handed in (a stale link): show the result instead.
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(_resultPath);
      });
    }

    final Widget body = switch (async) {
      AsyncData(:final value) => LayoutBuilder(
        builder: (context, constraints) =>
            _content(context, value, constraints),
      ),
      AsyncError() => _withClose(
        context,
        ErrorState(
          title: l10n.loadErrorTitle,
          onRetry: () => ref.invalidate(provider),
        ),
      ),
      _ => _withClose(
        context,
        const Center(child: CircularProgressIndicator()),
      ),
    };

    // While "Entregar" runs nothing may leave the screen: the controller would
    // be disposed under the in-flight transaction and the user would land on
    // Inicio with no result. System back does nothing until it finishes.
    return PopScope(
      canPop: state == null || (state.isSubmitted && !state.submitting),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ref.read(provider).value?.submitting ?? false) return;
        _leave();
      },
      child: Scaffold(
        body: SafeArea(child: PageBody(child: body)),
      ),
    );
  }

  /// Whether the two buttons per row of the bottom bar do not fit side by
  /// side (small screens, large text): then they stack, full width.
  bool _barNeedsStack(BuildContext context, double width) {
    final l10n = context.l10n;
    final style = context.typo.label;
    final widest =
        [l10n.previous, l10n.next, l10n.mockQuestions, l10n.mockSubmit]
            .map((label) => textWidth(context, label, style))
            .reduce((a, b) => a > b ? a : b);
    // Icon, its gap and the horizontal padding of a button, plus a pixel.
    final needed = widest + IconSize.button + Sp.s + 2 * Sp.xl + 1;
    final half = (width - 2 * Sp.page - Sp.m) / 2;
    return needed > half;
  }

  /// A state screen (loading, error) under a lone round close button.
  Widget _withClose(BuildContext context, Widget child) => Column(
    children: [
      Padding(
        padding: Sp.headerInsets,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RoundIconButton(
            icon: Icons.close_rounded,
            tooltip: context.l10n.close,
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );

  Widget _content(
    BuildContext context,
    MockState state,
    BoxConstraints constraints,
  ) {
    final l10n = context.l10n;
    final session = state.session;
    final question = session.currentQuestion;
    final index = session.currentIndex;
    final answer = session.answers[index];
    final header = Padding(
      padding: Sp.headerInsets,
      child: Column(
        children: [
          ProgressHeader(
            current: index + 1,
            total: session.length,
            completed: session.answeredCount,
            leading: RoundIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.close,
              onPressed: state.submitting ? null : _leave,
            ),
          ),
          if (state.timed) MockCountdown(startedAt: state.startedAt),
        ],
      ),
    );
    final questionView = RaisedCard(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.xl, Sp.l, Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _FlagToggle(
              flagged: state.isFlagged(index),
              onPressed: state.submitting ? null : _controller.toggleFlag,
            ),
          ),
          const SizedBox(height: Sp.xs),
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
              state: answer == i ? OptionState.selected : OptionState.idle,
              onTap: state.submitting ? null : () => _controller.select(i),
            ),
          ],
        ],
      ),
    );
    final stacked = _barNeedsStack(context, constraints.maxWidth);
    final bar = _Bar(
      stacked: stacked,
      session: session,
      submitting: state.submitting,
      onPrevious: _controller.previous,
      onNext: _controller.next,
      onNavigator: () => _openNavigator(state),
      onSubmit: () => _submit(state),
      questionsLabel: l10n.mockQuestions,
    );

    // With very large text (accessibility sizes) or a narrow screen the pinned
    // bar would eat the screen, so it scrolls with the question instead.
    final hugeText = MediaQuery.textScalerOf(context).scale(100) > 150;
    if (hugeText || stacked) {
      return SingleChildScrollView(
        key: ValueKey('mock-question-$index'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sp.page,
                Sp.s,
                Sp.page,
                Sp.xxl,
              ),
              child: questionView,
            ),
            bar,
          ],
        ),
      );
    }
    return Column(
      children: [
        header,
        Expanded(
          child: ScrollEdgeFade(
            key: ValueKey('mock-question-fade-$index'),
            child: SingleChildScrollView(
              key: ValueKey('mock-question-$index'),
              padding: const EdgeInsets.fromLTRB(
                Sp.page,
                Sp.s,
                Sp.page,
                Sp.xxl,
              ),
              child: questionView,
            ),
          ),
        ),
        bar,
      ],
    );
  }
}

/// «Marcar como dudosa»: a toggle on top of the question. Marked, it turns
/// amber, switches to the filled flag and says so in words, so the state is
/// never colour alone; it is spoken as a toggle.
class _FlagToggle extends StatelessWidget {
  const _FlagToggle({required this.flagged, required this.onPressed});

  final bool flagged;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final label = flagged ? l10n.mockFlagActive : l10n.mockFlagAction;
    // The button keeps its own semantics (focus, tap); the toggled state is
    // merged into the same node.
    return MergeSemantics(
      child: Semantics(
        toggled: flagged,
        child: TextButton.icon(
          key: const ValueKey('mock-flag-toggle'),
          onPressed: onPressed,
          style: flagged
              ? TextButton.styleFrom(
                  backgroundColor: colors.noticeContainer,
                  foregroundColor: colors.onNoticeContainer,
                )
              : null,
          icon: Icon(
            flagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
            size: IconSize.button,
          ),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Previous / next, the navigator and "Entregar".
class _Bar extends StatelessWidget {
  const _Bar({
    required this.stacked,
    required this.session,
    required this.submitting,
    required this.onPrevious,
    required this.onNext,
    required this.onNavigator,
    required this.onSubmit,
    required this.questionsLabel,
  });

  /// One full-width button per row instead of two.
  final bool stacked;
  final QuizSession session;
  final bool submitting;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onNavigator;
  final VoidCallback onSubmit;
  final String questionsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = session.currentIndex == 0;
    final last = session.isLastQuestion;
    return Container(
      color: context.colors.background,
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, Sp.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: stacked
            ? [
                SecondaryButton(
                  label: l10n.previous,
                  icon: Icons.arrow_back_rounded,
                  onPressed: first || submitting ? null : onPrevious,
                ),
                const SizedBox(height: Sp.s),
                SecondaryButton(
                  label: l10n.next,
                  icon: Icons.arrow_forward_rounded,
                  trailingIcon: true,
                  onPressed: last || submitting ? null : onNext,
                ),
                const SizedBox(height: Sp.s),
                TextActionButton(
                  label: questionsLabel,
                  icon: Icons.grid_view_rounded,
                  onPressed: submitting ? null : onNavigator,
                ),
                const SizedBox(height: Sp.s),
                PrimaryButton(
                  label: l10n.mockSubmit,
                  loading: submitting,
                  onPressed: onSubmit,
                ),
              ]
            : [
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: l10n.previous,
                        icon: Icons.arrow_back_rounded,
                        onPressed: first || submitting ? null : onPrevious,
                      ),
                    ),
                    const SizedBox(width: Sp.m),
                    Expanded(
                      child: SecondaryButton(
                        label: l10n.next,
                        icon: Icons.arrow_forward_rounded,
                        trailingIcon: true,
                        onPressed: last || submitting ? null : onNext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.s),
                Row(
                  children: [
                    Expanded(
                      child: TextActionButton(
                        label: questionsLabel,
                        icon: Icons.grid_view_rounded,
                        onPressed: submitting ? null : onNavigator,
                      ),
                    ),
                    const SizedBox(width: Sp.m),
                    Expanded(
                      child: PrimaryButton(
                        label: l10n.mockSubmit,
                        loading: submitting,
                        onPressed: onSubmit,
                      ),
                    ),
                  ],
                ),
              ],
      ),
    );
  }
}

/// Indicative countdown (tabular figures). When it reaches zero it says so;
/// it never submits the mock. Ticks once a second and only repaints when the
/// shown second changes.
class MockCountdown extends ConsumerStatefulWidget {
  const MockCountdown({super.key, required this.startedAt});

  final DateTime startedAt;

  @override
  ConsumerState<MockCountdown> createState() => _MockCountdownState();
}

class _MockCountdownState extends ConsumerState<MockCountdown> {
  Timer? _timer;
  late Duration _remaining = _compute();

  Duration _compute() => mockRemaining(
    startedAt: widget.startedAt,
    now: ref.read(clockProvider)(),
  );

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _compute();
      if (formatCountdown(next) != formatCountdown(_remaining) ||
          (next == Duration.zero) != (_remaining == Duration.zero)) {
        setState(() => _remaining = next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final expired = _remaining == Duration.zero;
    final style = context.typo.counter;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            expired ? Icons.timer_off_rounded : Icons.timer_rounded,
            size: IconSize.inline,
            color: colors.textSecondary,
          ),
          const SizedBox(width: Sp.xs),
          Flexible(
            child: Text(
              expired
                  ? l10n.mockTimerExpired
                  : l10n.mockTimerRemaining(formatCountdown(_remaining)),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
