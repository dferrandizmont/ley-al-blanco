import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/core/widgets/error_state.dart';
import 'package:apto_armas/features/content/content_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/theory_support.dart';

/// P10: a theory that fails to load is explained and can be retried; an
/// edition without theory simply hides the entry; a checksum that does not
/// match never shows the content.
const _errorTitle = 'No se ha podido cargar la teoría';
const _noTheoryTitle = 'La teoría no está disponible';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The failures that keep the entry visible, by what is wrong.
final _failures = <String, FakeAssetBundle Function()>{
  'asset missing': () => theoryBundle(includeAsset: false),
  'checksum mismatch': () => theoryBundle(wrongSha: 'b' * 64),
  'tampered asset': () => theoryBundle(tamperAsset: true),
  'malformed content': () => theoryBundle(theory: {'edition': 'otra'}),
};

void main() {
  group('Inicio', () {
    testScreen('hides the entry when the edition ships no theory', (
      tester,
    ) async {
      _phone(tester);
      await pumpFullApp(
        tester,
        bundle: theoryBundle(includeManifestField: false, includeAsset: false),
      );
      expect(find.widgetWithText(ActionCard, 'Teoría'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final entry in _failures.entries) {
      testScreen('keeps the entry when the theory fails: ${entry.key}', (
        tester,
      ) async {
        _phone(tester);
        await pumpFullApp(tester, bundle: entry.value());
        expect(find.widgetWithText(ActionCard, 'Teoría'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Teoría screen', () {
    testScreen('without theory in the edition: notice, no retry', (
      tester,
    ) async {
      _phone(tester);
      await pumpFullApp(
        tester,
        bundle: theoryBundle(includeManifestField: false, includeAsset: false),
      );
      await openRoute(tester, '/teoria');
      expect(find.text(_noTheoryTitle), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    for (final entry in _failures.entries) {
      testScreen('${entry.key}: explains it and offers to retry, without '
          'content', (tester) async {
        _phone(tester);
        await pumpFullApp(tester, bundle: entry.value());
        await openRoute(tester, '/teoria');
        expect(find.text(_errorTitle), findsOneWidget);
        expect(
          find.textContaining('Tu progreso no se ha visto afectado'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
        expect(find.text('La prueba práctica'), findsNothing);
        expect(find.text(_noTheoryTitle), findsNothing);

        // The reader says the same for a deep link.
        await openRoute(tester, '/teoria/t1');
        expect(find.text(_errorTitle), findsOneWidget);
        expect(find.text('Resumen del tema 1'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testScreen('retry goes to the theory once the file is right', (
      tester,
    ) async {
      _phone(tester);
      final bundle = theoryBundle(wrongSha: 'b' * 64);
      await pumpFullApp(tester, bundle: bundle);
      await openRoute(tester, '/teoria');
      expect(find.text(_errorTitle), findsOneWidget);

      // Same bytes, now with the checksum the manifest should carry.
      final good = theoryBundle();
      final manifest = contentManifestAsset(kContentEdition);
      bundle.assets[manifest] = good.assets[manifest]!;

      await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text(_errorTitle), findsNothing);
      expect(find.text('La prueba práctica'), findsOneWidget);
      expect(find.text('Funcionamiento y seguridad'), findsOneWidget);
    });

    testScreen('retry that fails again keeps the error', (tester) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: theoryBundle(wrongSha: 'b' * 64));
      await openRoute(tester, '/teoria');
      await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text(_errorTitle), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
    });
  });
}
