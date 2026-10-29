import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/fitted_text.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/text_width.dart';
import '../application/mock_providers.dart';
import '../data/mock_repository.dart' show MockRecord;
import '../domain/mock_timer.dart';
import '../mock_constants.dart';

/// Mock exam introduction: the mock left open (when there is one the user may
/// resume), what the exam is, the optional indicative countdown and
/// "Empezar", and "Tus simulacros" (the finished ones; each opens its result).
class MockIntroScreen extends ConsumerStatefulWidget {
  const MockIntroScreen({super.key});

  @override
  ConsumerState<MockIntroScreen> createState() => _MockIntroScreenState();
}

class _MockIntroScreenState extends ConsumerState<MockIntroScreen> {
  /// On by default (as in the real exam; the time is only a guide, spec §2),
  /// then the user's last choice, kept in the settings table.
  bool _timed = true;

  /// The user flipped the switch before the saved value was read: theirs wins.
  bool _timedTouched = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadTimedPreference();
  }

  Future<void> _loadTimedPreference() async {
    final saved = await ref
        .read(settingsDaoProvider)
        .get(MockSettingKeys.timerEnabled);
    if (!mounted || _timedTouched || saved == null) return;
    setState(() => _timed = saved == '1');
  }

  void _setTimed(bool value) {
    _timedTouched = true;
    setState(() => _timed = value);
    ref
        .read(settingsDaoProvider)
        .set(MockSettingKeys.timerEnabled, value ? '1' : '0');
  }

  /// Resumes the open exam without starting another.
  void _resume(MockRecord record) =>
      context.pushReplacement('/simulacro/${record.id}');

  Future<bool> _confirmReplace() async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mockReplaceTitle),
        content: Text(l10n.mockReplaceBody),
        // With very large text on a small screen the body does not fit: the
        // dialog scrolls so the last line is never cut.
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mockStartAnother),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _start() async {
    if (_starting) return; // a second tap while the first one is waiting
    setState(() => _starting = true);
    try {
      // Starting another discards the mock left open, after asking. Which
      // one is read from the database, not from the widget's providers (they
      // may not have emitted yet: a tap right on arrival would find "none"
      // and discard an open mock without asking). Only that mock is replaced.
      final open = await ref.read(unfinishedMockProvider.future);
      if (!mounted) return;
      if (open != null) {
        if (!await _confirmReplace()) {
          if (mounted) setState(() => _starting = false);
          return;
        }
        if (!mounted) return;
      }
      final started = await ref
          .read(mockServiceProvider)
          .startMock(timed: _timed, replaceUnfinishedId: open?.id);
      if (!mounted) return;
      // Replace the intro: back from the exam goes to Inicio, not here.
      context.pushReplacement('/simulacro/${started.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.mockStartError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final configAsync = ref.watch(mockConfigProvider);
    final config = configAsync.value;
    final resumable = ref.watch(resumableMockProvider);
    final history = ref.watch(mockHistoryProvider).value;
    // A manifest whose exam cannot be built must be visible, not a silently
    // disabled "Empezar".
    if (configAsync.hasError && config == null) {
      return Scaffold(
        appBar: AptoAppBar(title: l10n.mockTitle),
        body: SafeArea(
          child: PageBody(
            child: ErrorState(
              title: l10n.loadErrorTitle,
              onRetry: () => ref.invalidate(mockConfigProvider),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AptoAppBar(title: l10n.mockTitle),
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
                if (resumable != null) ...[
                  _ResumeCard(
                    record: resumable,
                    onResume: _starting ? null : () => _resume(resumable),
                  ),
                  const SizedBox(height: Sp.section),
                ],
                RaisedCard(
                  padding: const EdgeInsets.all(Sp.cardPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (config != null) ...[
                        Text(
                          l10n.mockIntroBody(config.size, config.passMark),
                          style: typo.body,
                        ),
                        const SizedBox(height: Sp.m),
                      ],
                      Text(l10n.mockIntroNoFeedback, style: typo.body),
                      const SizedBox(height: Sp.l),
                      const CardDivider(),
                      const SizedBox(height: Sp.s),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.mockTimerSwitch(
                            kMockIndicativeDuration.inMinutes,
                          ),
                          style: typo.rowTitle,
                        ),
                        subtitle: Text(
                          l10n.mockTimerHelp,
                          style: typo.subtitle,
                        ),
                        value: _timed,
                        onChanged: _starting ? null : _setTimed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Sp.section),
                // One primary action per view: "Continuar simulacro" when
                // there is a mock to resume, otherwise "Empezar".
                if (resumable != null)
                  SecondaryButton(
                    label: l10n.mockStartAnother,
                    onPressed: config == null || _starting ? null : _start,
                  )
                else
                  PrimaryButton(
                    label: l10n.mockStart,
                    loading: _starting,
                    onPressed: config == null ? null : _start,
                  ),
                if (history != null) ...[
                  const SizedBox(height: Sp.section),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                    child: Overline(l10n.mockHistoryTitle),
                  ),
                  const SizedBox(height: Sp.s),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                      child: Text(
                        l10n.mockHistoryEmpty,
                        style: context.typo.body,
                      ),
                    )
                  else
                    RaisedCard(
                      child: Column(
                        children: [
                          for (final (i, record) in history.indexed) ...[
                            if (i > 0) const CardDivider(),
                            _HistoryRow(
                              record: record,
                              onTap: () => context.push(
                                '/simulacro/${record.id}/resultado',
                              ),
                            ),
                          ],
                        ],
                      ),
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

/// "Tienes un simulacro sin entregar": how many questions are answered and
/// the way back into it.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.record, required this.onResume});

  final MockRecord record;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final answered = record.answers.where((a) => a != null).length;
    return RaisedCard(
      padding: const EdgeInsets.all(Sp.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mockResumeTitle, style: typo.rowTitle),
          ),
          const SizedBox(height: Sp.xs),
          Text(
            l10n.mockResumeProgress(answered, record.questionIds.length),
            style: AptoTypography.tabular(typo.subtitle),
          ),
          const SizedBox(height: Sp.l),
          PrimaryButton(
            label: l10n.mockResume,
            icon: Icons.play_arrow_rounded,
            onPressed: onResume,
          ),
        ],
      ),
    );
  }
}

/// A finished mock in "Tus simulacros": date, "16 de 20" and APTO / NO APTO
/// (an icon besides the colour); tapping opens its result.
///
/// With very large text on a small screen the date and the hour do not fit
/// next to the verdict: the row is then stacked, with the date and the hour
/// on a line of their own (never split) and the score and the verdict under
/// it.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.onTap});

  final MockRecord record;
  final VoidCallback onTap;

  /// What the row always takes: the circle with the check, the gaps and the
  /// chevron.
  static const double _fixed = Sp.xxl + Sp.m + Sp.s + Sp.s + IconSize.base;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final passed = record.passed ?? false;
    final tone = passed ? colors.correct : colors.incorrect;
    final toneText = passed ? colors.correctText : colors.incorrectText;
    final toneFill = passed
        ? colors.correctContainer
        : colors.incorrectContainer;
    final verdict = passed ? l10n.mockResultPassed : l10n.mockResultFailed;
    final local = record.finishedAt!.toLocal();
    const format = AppDateFormat();
    final date = l10n.mockHistoryDateTime(
      format.dayMonthYear(local),
      format.time(local),
    );
    final score = l10n.mockHistoryScore(
      record.correct ?? 0,
      record.questionIds.length,
    );
    final dateStyle = typo.rowTitle;
    final scoreStyle = AptoTypography.tabular(typo.subtitle);
    final verdictStyle = typo.label.copyWith(color: toneText);
    final badge = DecoratedBox(
      decoration: BoxDecoration(color: toneFill, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: Sp.xxl,
        child: Icon(
          passed ? Icons.check_rounded : Icons.close_rounded,
          size: IconSize.inline,
          color: tone,
        ),
      ),
    );
    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: IconSize.base,
      color: colors.outlineStrong,
    );
    return Semantics(
      button: true,
      label: l10n.mockHistoryRowSemantics(date, score, verdict),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Side by side (the verdict at the right of the date) only
                // when the date and the hour fit on one line next to it.
                final dateWidth = textWidth(context, date, dateStyle);
                final scoreWidth = textWidth(context, score, scoreStyle);
                final verdictWidth = textWidth(context, verdict, verdictStyle);
                final column = dateWidth > scoreWidth ? dateWidth : scoreWidth;
                final sideBySide =
                    column + verdictWidth + 1 <= constraints.maxWidth - _fixed;
                final details = sideBySide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(date, style: dateStyle),
                          const SizedBox(height: Sp.xs),
                          Text(score, style: scoreStyle),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The date and the hour on a line of their own,
                          // never split in the middle of the hour.
                          FittedText(
                            date,
                            style: dateStyle,
                            fit: FittedTextFit.line,
                          ),
                          const SizedBox(height: Sp.xs),
                          Wrap(
                            spacing: Sp.s,
                            runSpacing: Sp.xs,
                            children: [
                              Text(score, style: scoreStyle),
                              Text(verdict, style: verdictStyle),
                            ],
                          ),
                        ],
                      );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badge,
                    const SizedBox(width: Sp.m),
                    Expanded(child: details),
                    const SizedBox(width: Sp.s),
                    if (sideBySide) ...[
                      Text(verdict, style: verdictStyle),
                      const SizedBox(width: Sp.s),
                    ],
                    chevron,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
