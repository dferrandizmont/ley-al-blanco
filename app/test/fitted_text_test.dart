import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/fitted_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_support.dart';

/// The width of [text] in [style], with the size of the user at 1.
double widthOf(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The boxes of the whole [text]: one when it is on a single line.
List<TextBox> boxesOf(WidgetTester tester, Finder finder, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
}

/// Pumps [child] in a box of [width] dp, with the app theme.
Future<void> pumpBox(
  WidgetTester tester,
  Widget child, {
  required double width,
  bool bold = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(boldText: bold),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a style without a font size is measured with the inherited one', (
    tester,
  ) async {
    // The size the text is really drawn at is the inherited one (40): the
    // text is scaled down until it fits, instead of being split in the
    // middle of the word.
    const inherited = TextStyle(fontFamily: 'PublicSans', fontSize: 40);
    // The room fits the word at the size a measure without the inherited one
    // would use, but not at the inherited size.
    final room =
        (widthOf('Hola', const TextStyle()) + widthOf('Hola', inherited)) / 2;

    await pumpBox(
      tester,
      const DefaultTextStyle(
        style: inherited,
        child: FittedText('Hola', style: TextStyle(color: Color(0xFF101010))),
      ),
      width: room,
    );

    expect(tester.takeException(), isNull);
    final text = find.text('Hola');
    expectWordsNotSplit(tester, text, 'Hola');
    expect(boxesOf(tester, text, 'Hola').single.right, lessThanOrEqualTo(room));
  });

  testWidgets('the bold of the accessibility is measured too', (tester) async {
    // A style without variations: the bold of the accessibility is the one
    // that decides how wide the text is.
    const normal = TextStyle(fontFamily: 'PublicSans', fontSize: 16);
    final bold = normal.copyWith(fontWeight: FontWeight.bold);
    expect(
      widthOf('Documentación', bold),
      greaterThan(widthOf('Documentación', normal)),
      reason: 'the font has to be wider in bold',
    );
    // The room fits the word in the normal weight, but not in bold.
    final room =
        (widthOf('Documentación', normal) + widthOf('Documentación', bold)) / 2;

    await pumpBox(
      tester,
      const DefaultTextStyle(
        style: normal,
        child: FittedText('Documentación', style: normal),
      ),
      width: room,
      bold: true,
    );

    expect(tester.takeException(), isNull);
    final text = find.text('Documentación');
    expectWordsNotSplit(tester, text, 'Documentación');
    expect(
      boxesOf(tester, text, 'Documentación').single.right,
      lessThanOrEqualTo(room),
    );
    // The text was scaled down to fit the room.
    expect(effectiveFontSize(tester, text), lessThan(16));
  });

  testWidgets('the style that is drawn is the inherited one with the bold of '
      'the accessibility', (tester) async {
    await pumpBox(
      tester,
      const DefaultTextStyle(
        style: TextStyle(fontFamily: 'PublicSans', fontSize: 40),
        child: FittedText('Hola', style: TextStyle(color: Color(0xFF101010))),
      ),
      width: 300,
      bold: true,
    );

    final style = tester.widget<Text>(find.text('Hola')).style!;
    expect(style.fontSize, 40, reason: 'the inherited size');
    expect(style.fontFamily, 'PublicSans');
    expect(style.fontWeight, FontWeight.bold, reason: 'the bold of the user');
    expect(style.color, const Color(0xFF101010), reason: 'the style given');
  });

  testWidgets('a text that fits keeps the size of the user', (tester) async {
    await pumpBox(
      tester,
      const FittedText('Hola', style: TextStyle(fontSize: 16)),
      width: 300,
    );

    expect(effectiveFontSize(tester, find.text('Hola')), 16);
    expectWordsNotSplit(tester, find.text('Hola'), 'Hola');
  });
}
