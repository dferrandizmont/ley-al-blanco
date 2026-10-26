import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'raised_card.dart';

/// A tile of Inicio (Simulacro, Fallos): a raised card (radius 20) with an
/// icon, a title, an optional subtitle and an optional count [badge]
/// ([AptoColors.incorrectContainer] / [AptoColors.incorrectText]). Two sit
/// side by side.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Short text on a pill in the corner (the mistakes count); null hides it.
  final String? badge;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Semantics(
      button: onTap != null,
      label: [title, ?subtitle].join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: RaisedCard(
        radius: Rad.tile,
        onTap: onTap,
        padding: const EdgeInsets.all(Sp.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: Sp.x4,
                    child: Icon(
                      icon,
                      size: IconSize.base,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                if (badge != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.incorrectContainer,
                      borderRadius: Rad.pillRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sp.m,
                        vertical: Sp.xs,
                      ),
                      child: Text(
                        badge!,
                        style: AptoTypography.tabular(
                          typo.verdict.copyWith(color: colors.incorrectText),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Sp.m),
            Text(title, style: typo.label),
            if (subtitle != null) ...[
              const SizedBox(height: Sp.xs),
              Text(subtitle!, style: typo.subtitle),
            ],
          ],
        ),
      ),
    );
  }
}
