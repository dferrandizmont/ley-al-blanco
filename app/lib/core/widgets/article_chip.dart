import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Small tag with the cited article ("Art. 96 Reglamento") shown with every
/// explanation: a book icon on a tinted [AptoColors.primaryContainer] chip.
class ArticleChip extends StatelessWidget {
  const ArticleChip({super.key, required this.article});

  final String article;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = AptoTypography.weight(
      context.typo.caption,
      600,
    ).copyWith(color: colors.onPrimaryContainer);
    return Semantics(
      label: context.l10n.articleChipSemantics(article),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: Rad.chipRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: IconSize.inline,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: Sp.s),
              Flexible(
                child: Text(
                  article,
                  style: style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
