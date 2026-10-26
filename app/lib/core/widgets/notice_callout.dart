import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// "Aviso: cambio en la norma": amber callout (icon + title + text) for a
/// question, or a block of theory, whose official answer the current law may
/// contradict. Amber, not the red of a wrong answer: it is information, not an
/// error, and it never changes the official answer.
class NoticeCallout extends StatelessWidget {
  const NoticeCallout({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.noticeContainer,
        borderRadius: Rad.optionRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_rounded,
              size: IconSize.base,
              color: colors.onNoticeContainer,
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.noticeTitle,
                      style: typo.verdict.copyWith(
                        color: colors.onNoticeContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    text,
                    style: typo.body.copyWith(color: colors.onNoticeContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
