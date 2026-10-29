import 'package:flutter/material.dart';

import 'text_width.dart';

/// What has to fit on one line in a [FittedText].
enum FittedTextFit {
  /// The longest word of the text (the title of a tema, for example): the
  /// text may take several lines, but no word is split in the middle.
  word,

  /// The whole text (a date and its hour, for example): it stays on one line.
  line,
}

/// A text that fits the room it has, without splitting anything.
///
/// The user's text size is respected while the text fits; when it does not
/// (small screen, large text), the scale is capped just enough to make it
/// fit: nothing is cut and no word is split in the middle of a word.
class FittedText extends StatelessWidget {
  const FittedText(
    this.text, {
    super.key,
    required this.style,
    this.fit = FittedTextFit.word,
    this.textAlign,
  });

  final String text;
  final TextStyle style;

  /// What has to fit on one line.
  final FittedTextFit fit;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    // The style that is really drawn, and the locale it is drawn with: the
    // measure has to be made with them or the text is not measured as it is
    // drawn.
    final effective = _effectiveStyle(context);
    final locale = Localizations.maybeLocaleOf(context);
    final child = Text(
      text,
      style: effective,
      textAlign: textAlign,
      locale: locale,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        if (!room.isFinite) return child;
        final measured = _measured(context, effective, locale);
        if (measured <= 0) return child;
        // The size the text is drawn at, before the scale of the user.
        final fontSize = effective.fontSize ?? 14;
        final factor = data.textScaler.scale(fontSize) / fontSize;
        // The scale that makes the text fit, with a margin of a pixel.
        final cap = ((room - 1) * factor / measured).clamp(0.0, factor);
        if (cap >= factor) return child;
        return MediaQuery(
          data: data.copyWith(
            textScaler: data.textScaler.clamp(maxScaleFactor: cap),
          ),
          child: child,
        );
      },
    );
  }

  /// The style that is really drawn: the inherited one with [style] on top
  /// of it and the bold of the accessibility, exactly as [Text] does it.
  ///
  /// Measuring with this style is what makes the text fit: with [style]
  /// alone the measure can be short (the inherited font, the bold of the
  /// accessibility) and the text would still be split in the middle.
  TextStyle _effectiveStyle(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    if (!MediaQuery.boldTextOf(context)) return effective;
    return effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }

  /// The width of the text (or of its widest word) at the user's text size.
  double _measured(BuildContext context, TextStyle style, Locale? locale) {
    if (fit == FittedTextFit.line) {
      return textWidth(context, text, style, locale: locale);
    }
    var widest = 0.0;
    for (final word in text.split(' ')) {
      if (word.isEmpty) continue;
      final width = textWidth(context, word, style, locale: locale);
      if (width > widest) widest = width;
    }
    return widest;
  }
}
