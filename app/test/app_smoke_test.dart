import 'package:apto_armas/core/bootstrap/app_bootstrap.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/content_constants.dart';
import 'package:apto_armas/features/content/data/content_importer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';

void main() {
  testScreen('the app boots and shows the home title and the pass ring', (
    tester,
  ) async {
    await pumpFullApp(tester);
    expect(find.text('Ley al Blanco'), findsOneWidget);
    expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testScreen('home shows the fixed non-official disclaimer', (tester) async {
    await pumpFullApp(tester);
    expect(
      find.text(
        'App independiente y no oficial. Preguntas basadas en el cuestionario '
        'publicado por la Dirección General de la Guardia Civil.',
      ),
      findsOneWidget,
    );
  });

  testScreen('booting imports the bundled bank and exposes its manifest', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final boot = container.read(bootstrapProvider).requireValue;
    expect(boot.import.status, ImportStatus.imported);
    expect(boot.manifest.edition, kContentEdition);
    expect(boot.manifest.questionCount, 423);
    final db = container.read(appDatabaseProvider);
    expect(await db.questionsDao.countByTema(), {
      1: 68,
      2: 67,
      3: 66,
      4: 70,
      5: 66,
      6: 64,
      7: 22,
    });
  });

  testScreen('a corrupt bank shows the retry state instead of crashing', (
    tester,
  ) async {
    final bytes = realQuestionsBytes();
    bytes[bytes.length ~/ 2] ^= 0x01;
    await pumpFullApp(
      tester,
      bundle: FakeAssetBundle({
        ...FakeAssetBundle.real().assets,
        contentQuestionsAsset(kContentEdition): bytes,
      }),
    );
    expect(find.text('No se ha podido preparar la app'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('checksum'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testScreen('a failing bootstrap shows the retry state, and retry recovers', (
    tester,
  ) async {
    var attempts = 0;
    await pumpFullApp(
      tester,
      overrides: [
        bootstrapProvider.overrideWith((ref) async {
          attempts++;
          if (attempts == 1) throw StateError('boom');
          final result = await ref
              .read(contentImporterProvider)
              .importIfNeeded();
          return BootstrapResult(manifest: result.manifest, import: result);
        }),
      ],
    );
    expect(find.text('No se ha podido preparar la app'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    // The exception text never reaches the user.
    expect(find.textContaining('boom'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);
  });
}
