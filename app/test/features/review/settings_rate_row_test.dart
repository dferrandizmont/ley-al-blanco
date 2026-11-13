import 'package:apto_armas/features/review/application/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../support/screen_support.dart';
import '../../support/settings_support.dart';
import 'review_test_support.dart';

void main() {
  for (final small in [false, true]) {
    testScreen(
      'Settings rate row opens store${small ? ' at 320x568 with x2 text' : ''}',
      (tester) async {
        tester.view.physicalSize = small
            ? const Size(320, 568)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final store = FakeStore();
        await pumpFullApp(
          tester,
          overrides: [
            ...settingsOverrides(launcher: FakeUrlLauncher()),
            storeReviewPlatformProvider.overrideWithValue(store),
          ],
        );
        await openRoute(tester, '/ajustes');
        final title = find.text('Valorar Ley al Blanco');
        final subtitle = find.text(
          'Una reseña ayuda a que otros la encuentren',
        );
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        expect(title, findsOneWidget);
        expect(subtitle, findsOneWidget);
        expectWordsInside(tester, title, 'Valorar Ley al Blanco');
        expectWordsInside(
          tester,
          subtitle,
          'Una reseña ayuda a que otros la encuentren',
        );
        expect(
          tester.getTopLeft(title).dy,
          greaterThan(tester.getTopLeft(find.text('AYUDA')).dy),
        );
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(store.listings, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
