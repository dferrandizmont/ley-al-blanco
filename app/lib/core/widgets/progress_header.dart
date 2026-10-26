import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'pill_bar.dart';

/// Top row of a question screen: an optional [leading] widget (the round close
/// button), a flexible 8 dp progress bar and a "5 / 68" counter.
///
/// [current] is the 1-based position shown in the counter; the bar fills with
/// [completed] (questions already answered) and defaults to [current].
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.current,
    required this.total,
    this.completed,
    this.leading,
  });

  /// 1-based position of the question on screen.
  final int current;
  final int total;

  /// How much of the bar is filled, in questions. Defaults to [current].
  final int? completed;

  /// Shown before the bar (the close button).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0
        ? 0.0
        : ((completed ?? current) / total).clamp(0.0, 1.0);
    final text = context.l10n.ratio(current, total);
    final spoken = context.l10n.progressSemantics(current, total);
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: Sp.m)],
        Expanded(
          child: Semantics(
            label: spoken,
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(child: PillBar(value: fraction)),
                const SizedBox(width: Sp.m),
                Text(text, style: context.typo.counter),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
