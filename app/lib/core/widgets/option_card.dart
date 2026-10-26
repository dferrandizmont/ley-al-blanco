import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Visual state of an [OptionCard].
enum OptionState {
  /// Not picked.
  idle,

  /// Picked, no verdict yet (mock).
  selected,

  /// Picked and right: check in a green circle.
  correct,

  /// Picked and wrong: cross in a red circle.
  incorrect,

  /// The right option, shown after a wrong pick: styled like [correct].
  revealedCorrect,
}

/// One answer option: a full-width card, at least 56 dp tall, tappable all
/// over, with a 26 dp circle on the left: the letter at rest, a filled letter
/// when selected, a check or a cross once judged. A right / wrong state is
/// never colour alone (the circle holds a check / cross) and is spoken as
/// "Correcta" / "Incorrecta". Pass a null [onTap] to lock the card (it keeps
/// its look).
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });

  /// "A", "B" or "C": the questionnaire's order, never shuffled.
  final String letter;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  static const double minHeight = 56;

  /// Diameter of the leading circle.
  static const double circle = 26;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;

    final judgedRight =
        state == OptionState.correct || state == OptionState.revealedCorrect;
    final (Color fill, Color border) = switch (state) {
      OptionState.idle => (colors.surfaceRaised, colors.optionBorder),
      OptionState.selected => (colors.primaryContainer, colors.primary),
      OptionState.correct ||
      OptionState.revealedCorrect => (colors.correctContainer, colors.correct),
      OptionState.incorrect => (colors.incorrectContainer, colors.incorrect),
    };
    final verdict = switch (state) {
      OptionState.correct || OptionState.revealedCorrect => l10n.optionCorrect,
      OptionState.incorrect => l10n.optionIncorrect,
      _ => null,
    };
    // The verdict is joined with «. »: drop the option's own final full stop
    // so it is not read twice («semiautomática.. Incorrecta»).
    final spokenText = verdict == null
        ? text
        : text.replaceFirst(RegExp(r'[.\s]+$'), '');
    final spoken = [
      l10n.optionSemantics(letter, spokenText),
      ?verdict,
    ].join('. ');
    final shape = RoundedRectangleBorder(
      borderRadius: Rad.optionRadius,
      side: BorderSide(color: border, width: Sp.borderStrong),
    );

    return Semantics(
      button: onTap != null,
      selected: state == OptionState.selected,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.l,
                vertical: Sp.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Leading(letter: letter, state: state),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Text(
                      text,
                      style: judgedRight ? typo.optionStrong : typo.option,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 26 dp circle: letter (idle / selected), check or cross (judged).
class _Leading extends StatelessWidget {
  const _Leading({required this.letter, required this.state});

  final String letter;
  final OptionState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    // A null fill leaves the card's own surface showing through.
    final (Color? fill, Color? border) = switch (state) {
      OptionState.idle => (null, colors.outlineStrong),
      OptionState.selected => (colors.primary, colors.primary),
      OptionState.correct ||
      OptionState.revealedCorrect => (colors.correct, null),
      OptionState.incorrect => (colors.incorrect, null),
    };
    final Widget glyph = switch (state) {
      OptionState.correct || OptionState.revealedCorrect => Icon(
        Icons.check_rounded,
        size: IconSize.inline,
        color: colors.onPrimary,
      ),
      OptionState.incorrect => Icon(
        Icons.close_rounded,
        size: IconSize.inline,
        color: colors.onPrimary,
      ),
      _ => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letter,
          style: typo.verdict.copyWith(
            color: state == OptionState.selected
                ? colors.onPrimary
                : colors.textSecondary,
          ),
        ),
      ),
    };
    return SizedBox.square(
      dimension: OptionCard.circle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: border == null
              ? null
              : Border.all(color: border, width: Sp.borderStrong),
        ),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(Sp.xxs), child: glyph),
        ),
      ),
    );
  }
}
