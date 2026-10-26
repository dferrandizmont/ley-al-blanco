import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../../features/content/domain/question.dart';
import '../../features/settings/application/settings_providers.dart';
import 'article_chip.dart';
import 'buttons.dart';
import 'notice_callout.dart';

/// The content of an explanation: the verdict, the right answer, our legal
/// reform notice (when the current law may differ from the official answer),
/// our own explanation (or a placeholder while it is still being written) and
/// the cited article. It sits inline: inside the question card of the practice
/// screens (under a divider) and in the read-only mock review. No scrolling,
/// no button.
class ExplanationBody extends ConsumerWidget {
  const ExplanationBody({
    super.key,
    required this.correct,
    required this.correctLetter,
    required this.correctText,
    required this.explanation,
    required this.article,
    this.notice,
    this.report,
  });

  /// True / false adds a "Correcto" / "Incorrecto" verdict (icon + text);
  /// null shows none (a question left blank).
  final bool? correct;

  /// Letter and text of the official answer.
  final String correctLetter;
  final String correctText;

  /// Our explanation; null shows "Explicación en preparación".
  final String? explanation;

  /// Cited article; null hides the chip.
  final String? article;

  /// Our legal-reform notice; null shows no callout. Shown above the
  /// explanation. The official answer above it is never changed by it.
  final String? notice;

  /// What the "¿Ves un error? Avísanos" mail says about the question; null
  /// shows no such action. It also needs a valid support address in the build.
  final ReportTarget? report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final verdict = correct;
    final text = explanation?.trim();
    final pending = text == null || text.isEmpty;
    final noticeText = notice?.trim();
    final hasNotice = noticeText != null && noticeText.isNotEmpty;
    final target = report;
    final supportAddress = target == null
        ? null
        : ref.watch(settingsLinksProvider).support;
    final verdictColor = verdict == true
        ? colors.correctText
        : colors.incorrectText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (verdict != null) ...[
          Semantics(
            header: true,
            child: Row(
              children: [
                Icon(
                  verdict ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: IconSize.base,
                  color: verdict ? colors.correct : colors.incorrect,
                ),
                const SizedBox(width: Sp.s),
                Expanded(
                  child: Text(
                    verdict
                        ? l10n.explanationCorrect
                        : l10n.explanationIncorrect,
                    style: typo.verdict.copyWith(color: verdictColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.m),
        ],
        Text(l10n.explanationCorrectAnswer, style: typo.caption),
        const SizedBox(height: Sp.xs),
        Text(
          l10n.explanationAnswerLine(correctLetter, correctText),
          style: AptoTypography.weight(typo.body, 600),
        ),
        const SizedBox(height: Sp.l),
        if (hasNotice) ...[
          NoticeCallout(text: noticeText),
          const SizedBox(height: Sp.l),
        ],
        Text(l10n.explanationHeading, style: typo.caption),
        const SizedBox(height: Sp.xs),
        Text(
          pending ? l10n.explanationPending : text,
          style: pending
              ? typo.body.copyWith(color: colors.textSecondary)
              : typo.body,
        ),
        if (article != null) ...[
          const SizedBox(height: Sp.l),
          Align(
            alignment: Alignment.centerLeft,
            child: ArticleChip(article: article!),
          ),
        ],
        if (target != null && supportAddress != null) ...[
          SizedBox(height: article != null ? Sp.xs : Sp.m),
          Align(
            alignment: Alignment.centerLeft,
            child: _ReportButton(target: target, address: supportAddress),
          ),
        ],
      ],
    );
  }
}

/// The facts of a question that go into the "¿Ves un error?" mail: ids and
/// the text of the question and of our explanation, nothing about the user.
class ReportTarget {
  const ReportTarget({
    required this.id,
    required this.edition,
    required this.tema,
    required this.stem,
    required this.answerLetter,
    this.explanation,
    this.article,
  });

  factory ReportTarget.fromQuestion(Question q) => ReportTarget(
    id: q.id,
    edition: q.edition,
    tema: q.tema,
    stem: q.stem,
    answerLetter: String.fromCharCode(0x41 + q.answer),
    explanation: q.explanation,
    article: q.article,
  );

  final String id;
  final String edition;
  final int tema;
  final String stem;

  /// "A", "B", "C": the official answer.
  final String answerLetter;
  final String? explanation;
  final String? article;
}

/// Longest part of the stem put in the mail.
const _maxStemChars = 200;

/// "¿Ves un error? Avísanos": a quiet text action (secondary colour and the
/// small caption size, so it never competes with "Siguiente") that opens a
/// prefilled mail to support.
class _ReportButton extends ConsumerWidget {
  const _ReportButton({required this.target, required this.address});

  final ReportTarget target;
  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final label = context.l10n.explanationReport;
    final base = Theme.of(context).textButtonTheme.style;
    final quiet = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(colors.textSecondary),
      iconColor: WidgetStatePropertyAll(colors.textSecondary),
      textStyle: WidgetStatePropertyAll(
        AptoTypography.weight(context.typo.caption, 600),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
      ),
    );
    return TextButtonTheme(
      data: TextButtonThemeData(style: base?.merge(quiet) ?? quiet),
      child: TextActionButton(
        label: label,
        icon: Icons.flag_rounded,
        onPressed: () => _send(context, ref),
      ),
    );
  }

  /// Opens the mail app; a snack bar says so when nothing could.
  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    var version = '';
    try {
      version = (await ref.read(appInfoProvider.future)).label;
    } on Object {
      // No version known: the mail still opens.
    }
    // Leaving the screen while waiting disposes [ref].
    if (!context.mounted) return;
    final system = await readSystemLabel(ref);
    if (!context.mounted) return;
    final stem = target.stem.length > _maxStemChars
        ? target.stem.substring(0, _maxStemChars)
        : target.stem;
    final explanation = target.explanation?.trim();
    final uri = supportMailUri(
      address,
      subject: l10n.explanationReportMailSubject(target.id, version),
      body: l10n.explanationReportMailBody(
        target.id,
        target.edition,
        target.tema,
        stem,
        target.answerLetter,
        explanation == null || explanation.isEmpty
            ? l10n.explanationPending
            : explanation,
        target.article ?? '-',
        version,
        system,
      ),
    );
    final opened = await ref.read(urlLauncherProvider).open(uri);
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.settingsOpenFailed)));
  }
}
