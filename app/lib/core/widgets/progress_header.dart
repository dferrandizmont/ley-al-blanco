import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'pill_bar.dart';
import 'text_width.dart';

/// Top row of a question screen: an optional [leading] widget (the round close
/// button), a flexible 8 dp progress bar and a "5 / 68" counter.
///
/// [current] is the 1-based position shown in the counter; the bar fills with
/// [completed] (questions already answered) and defaults to [current].
///
/// With [pending] the counter says how many questions of the session are
/// still to be answered ("1 de 67 pendientes") instead of the plain ratio.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.current,
    required this.total,
    this.completed,
    this.leading,
    this.pending = false,
  });

  /// 1-based position of the question on screen.
  final int current;
  final int total;

  /// How much of the bar is filled, in questions. Defaults to [current].
  final int? completed;

  /// Shown before the bar (the close button).
  final Widget? leading;

  /// Counts the pending questions of the session instead of showing the ratio.
  final bool pending;

  /// The bar keeps at least this width: below it the counter goes on its own
  /// line, so the bar never becomes a stub.
  static const double minBarWidth = 96;

  /// The widest counter the session can show: the index with as many digits
  /// as the total ("67 de 67 pendientes"). The layout is decided with this
  /// counter and not with the current one, so the header keeps the same
  /// shape from the first question to the last (the index grows from 9 to 10
  /// in the middle of a session and the text gets wider).
  String _widestCounter(AppLocalizations l10n) {
    final index = total < 1 ? 1 : total;
    return pending
        ? l10n.progressPendingCount(index, total)
        : l10n.ratio(index, total);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final fraction = total <= 0
        ? 0.0
        : ((completed ?? current) / total).clamp(0.0, 1.0);
    final text = pending
        ? l10n.progressPendingCount(current, total)
        : l10n.ratio(current, total);
    final spoken = pending
        ? l10n.progressPendingSemantics(current, total)
        : l10n.progressSemantics(current, total);
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: Sp.m)],
        Expanded(
          child: Semantics(
            label: spoken,
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The counter needs its own line when it leaves too little
                // room for the bar (small screens, large text). The width is
                // measured on the widest counter of the session, so the
                // arrangement does not change while the index grows.
                final counterWidth = textWidth(
                  context,
                  _widestCounter(l10n),
                  typo.counter,
                );
                if (constraints.maxWidth - Sp.m - counterWidth < minBarWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PillBar(value: fraction),
                      const SizedBox(height: Sp.xs),
                      Text(text, style: typo.counter, textAlign: TextAlign.end),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: PillBar(value: fraction)),
                    const SizedBox(width: Sp.m),
                    Text(text, style: typo.counter),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
