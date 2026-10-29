import 'package:flutter/widgets.dart';

/// Width of [text] on one line in [style], at the user's text size. Lets a
/// layout pick between a side-by-side and a stacked arrangement by what
/// really fits (small screens, large text) instead of by magic numbers.
///
/// [locale] is the one the text is drawn with (the locale of the app): the
/// measure has to be made with the same one, or the text is not measured as
/// it is drawn.
double textWidth(
  BuildContext context,
  String text,
  TextStyle style, {
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: locale,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
