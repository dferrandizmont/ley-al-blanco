import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'buttons.dart';

/// Never a blank screen: an icon, a headline, one line of body text and an
/// optional action. Scrolls when the text is large or the screen small.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.primaryAction = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Filled (primary) instead of outlined (secondary) action button.
  final bool primaryAction;

  /// Inline (inside a card or list) instead of centred on the page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: IconSize.hero, color: colors.textSecondary),
        ),
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(title, style: typo.title, textAlign: TextAlign.center),
        ),
        if (message != null) ...[
          const SizedBox(height: Sp.s),
          Text(
            message!,
            style: typo.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: Sp.xxl),
          if (primaryAction)
            PrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            )
          else
            SecondaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xl),
        child: column,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.x3,
          vertical: Sp.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: column,
        ),
      ),
    );
  }
}
