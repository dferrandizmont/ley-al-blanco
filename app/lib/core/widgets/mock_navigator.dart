import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Grid of numbered round cells, one per mock question. A filled green cell
/// has an answer, a sand one with an outline does not; the current question
/// has a thick dark border. A question marked as doubtful carries a flag
/// badge (an icon, not colour alone) and is spoken as "dudosa". [onTap]
/// receives the 0-based index.
class MockNavigator extends StatelessWidget {
  const MockNavigator({
    super.key,
    required this.count,
    required this.current,
    required this.answered,
    required this.onTap,
    this.flagged = const {},
  });

  /// Number of questions (20).
  final int count;

  /// 0-based index of the question on screen.
  final int current;

  /// 0-based indices that already have an answer.
  final Set<int> answered;

  /// 0-based indices marked as doubtful.
  final Set<int> flagged;
  final ValueChanged<int> onTap;

  /// Side of a cell, also its touch target.
  static const double cell = 48;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        for (var i = 0; i < count; i++)
          _Cell(
            number: i + 1,
            isCurrent: i == current,
            isAnswered: answered.contains(i),
            isFlagged: flagged.contains(i),
            onTap: () => onTap(i),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.number,
    required this.isCurrent,
    required this.isAnswered,
    required this.isFlagged,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;
  final bool isAnswered;
  final bool isFlagged;
  final VoidCallback onTap;

  /// Diameter of the flag badge in a corner of the cell.
  static const double badge = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final shape = CircleBorder(
      side: BorderSide(
        color: isCurrent
            ? colors.textPrimary
            : (isAnswered ? colors.primary : colors.outlineStrong),
        width: isCurrent ? 3 : 1.5,
      ),
    );
    final fill = isAnswered ? colors.primary : colors.background;
    final textColor = isAnswered ? colors.onPrimary : colors.textPrimary;
    return Semantics(
      button: true,
      selected: isCurrent,
      label: switch ((isAnswered, isFlagged)) {
        (true, true) => l10n.mockFlagCellAnswered(number),
        (true, false) => l10n.navigatorCellAnswered(number),
        (false, true) => l10n.mockFlagCellBlank(number),
        (false, false) => l10n.navigatorCellBlank(number),
      },
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: MockNavigator.cell,
        child: Stack(
          // The badge sits a little outside the corner, clear of the number.
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: fill,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  customBorder: shape,
                  // The cell is a fixed touch target: at large text scales the
                  // number shrinks to fit instead of clipping (like
                  // OptionCard's letter).
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$number',
                        style: AptoTypography.tabular(
                          AptoTypography.weight(
                            context.typo.rowTitle,
                            isCurrent ? 700 : 600,
                          ).copyWith(color: textColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isFlagged)
              Positioned(
                top: -Sp.xs,
                right: -Sp.xs,
                child: IgnorePointer(child: const FlagBadge(size: badge)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small amber circle with a flag that marks a doubtful question (the
/// notice colours of the theme: 8,65:1 / 9,62:1 between glyph and fill). Used
/// on the cells of [MockNavigator] and in its legend.
class FlagBadge extends StatelessWidget {
  const FlagBadge({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.noticeContainer,
        shape: BoxShape.circle,
        border: Border.all(color: colors.onNoticeContainer, width: Sp.border),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.flag_rounded,
          size: size * 0.7,
          color: colors.onNoticeContainer,
        ),
      ),
    );
  }
}

/// What the cells of [MockNavigator] mean: answered (filled), unanswered
/// (outlined) and doubtful (flag). Wraps onto two lines on a narrow screen or
/// with large text.
class MockNavigatorLegend extends StatelessWidget {
  const MockNavigatorLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final style = context.typo.subtitle;
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: Sp.s),
        Flexible(child: Text(label, style: style)),
      ],
    );
    const dot = 16.0;
    return Wrap(
      spacing: Sp.l,
      runSpacing: Sp.s,
      children: [
        item(
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary, width: 1.5),
            ),
            child: const SizedBox.square(dimension: dot),
          ),
          l10n.mockFlagLegendAnswered,
        ),
        item(
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineStrong, width: 1.5),
            ),
            child: const SizedBox.square(dimension: dot),
          ),
          l10n.mockFlagLegendBlank,
        ),
        item(const FlagBadge(size: dot + 4), l10n.mockFlagLegendDoubtful),
      ],
    );
  }
}
