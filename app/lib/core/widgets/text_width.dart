import 'package:flutter/widgets.dart';

/// Width of [text] on one line in [style], at the user's text size. Lets a
/// layout pick between a side-by-side and a stacked arrangement by what
/// really fits (small screens, large text) instead of by magic numbers.
double textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
