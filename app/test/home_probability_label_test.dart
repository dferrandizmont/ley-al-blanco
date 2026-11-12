import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';

/// P2: «PROBABILIDAD DE APROBAR» is never split in the middle of a word, with
/// the largest text of iOS, bold text and both themes, on a 320 dp screen.
void main() {
  const label = 'PROBABILIDAD DE APROBAR';
  for (final scale in [1.0, 2.0, 3.1]) {
    for (final bold in [false, true]) {
      for (final dark in [false, true]) {
        testScreen(
          'the probability label keeps its words whole '
          '(x$scale, bold $bold, ${dark ? 'dark' : 'light'})',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.platformDispatcher.platformBrightnessTestValue = dark
                ? Brightness.dark
                : Brightness.light;
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(boldText: bold);
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearAllTestValues);

            await pumpFullApp(tester);

            final text = find.text(label);
            expect(text, findsOneWidget);
            expect(tester.takeException(), isNull);
            expectWordsNotSplit(tester, text, label);
            expectWordsInside(tester, text, label);
          },
        );
      }
    }
  }
}
