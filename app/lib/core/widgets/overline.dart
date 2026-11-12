import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fitted_text.dart';

/// A section label ("TEMAS", "POR TEMA"): 13 / 600, upper case, tracking 6 %.
/// Pass the text as written in the ARB; it is upper-cased here and read to
/// screen readers as written. [header] marks it as a section heading.
class Overline extends StatelessWidget {
  const Overline(
    this.text, {
    super.key,
    this.header = true,
    this.spoken = true,
    this.color,
    this.maxLines,
    this.textAlign,
    this.fitWords = false,
  });

  final String text;
  final bool header;

  /// False hides it from screen readers (its text is spoken elsewhere).
  final bool spoken;
  final Color? color;
  final int? maxLines;
  final TextAlign? textAlign;

  /// True for a label that must never be split in the middle of a word (the
  /// main label of a screen): the text may take several lines, and when its
  /// longest word does not fit the room, only this label's text scale is
  /// capped just enough to fit it. Ignores [maxLines].
  final bool fitWords;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.overline;
    final drawn = color == null ? style : style.copyWith(color: color);
    final label = fitWords
        ? FittedText(text.toUpperCase(), style: drawn, textAlign: textAlign)
        : Text(
            text.toUpperCase(),
            style: drawn,
            maxLines: maxLines,
            textAlign: textAlign,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          );
    if (!spoken) return ExcludeSemantics(child: label);
    return Semantics(
      header: header,
      label: text,
      excludeSemantics: true,
      child: label,
    );
  }
}
