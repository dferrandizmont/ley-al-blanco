import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/features/progress_transfer/application/progress_transfer_providers.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_file_store.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';
import '../support/qa_ui.dart';

// Ajustes > Tus datos (route /ajustes): «Exportar progreso» and «Importar
// progreso».
//
// The native file dialogs (Android Storage Access Framework, iOS document
// picker) belong to the system and cannot be driven from a Dart test, so the
// scenarios replace only that seam ([progressFileStoreProvider]) with
// [_FakeFileStore]: everything else is real (the screen, the strict
// validation, the confirmation, the transaction on the real Drift file and
// the refresh of the providers). What stays manual on a device: that the
// system dialog opens, lets the user choose where to save, and returns the
// chosen file (docs/qa.md, checklist of «Tus datos»). Run only these with
// `QA_ONLY=datos`.

/// The system dialogs, scripted: [pickResult] is what the user "picks"; every
/// "save" is recorded.
class _FakeFileStore implements ProgressFileStore {
  _FakeFileStore([this.pickResult = const PickCancelled()]);

  PickedProgressFile pickResult;
  final saved = <({String fileName, Uint8List bytes})>[];

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    saved.add((fileName: fileName, bytes: bytes));
    return true;
  }

  @override
  Future<PickedProgressFile> pick() async => pickResult;
}

Future<void> _openAjustes(QaApp app) async {
  await app.tester.tapFinder(
    find.byTooltip(T.ajustes),
    reason: 'Ajustes button',
  );
  await app.tester.waitFor(find.text(T.ajustes), reason: 'the Ajustes title');
  await app.tester.pumpFor(const Duration(milliseconds: 300));
}

/// Scrolls Ajustes until [finder] is on screen.
Future<void> _see(WidgetTester tester, Finder finder, {String? what}) async {
  if (finder.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
    } on Object {
      throw TestFailure(
        'Ajustes does not show ${what ?? finder}. '
        'On screen: ${tester.visibleTexts().take(40).join(' | ')}',
      );
    }
  }
  expect(finder, findsWidgets, reason: what);
}

Uint8List _bytes(Map<String, dynamic> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

/// A progress file with one wrong answer on the first question of the bank.
Uint8List _fileWithOneMistake(QaApp app) {
  final q = app.bank.questions.first;
  final now = DateTime.now().toUtc().toIso8601String();
  return _bytes({
    'format': 'apto-armas-progress',
    'version': 1,
    'edition': 'GC-2020-11',
    'exported_at': now,
    'app_version': 'qa',
    'attempts': [
      {
        'question_id': q.id,
        'mode': 'practice',
        'selected': q.wrongOption,
        'correct': false,
        'answered_at': now,
        'mock_id': null,
        'elapsed_ms': 3000,
      },
    ],
    'srs': <Object?>[],
    'mocks': <Object?>[],
    'settings': {'theme_mode': 'dark'},
  });
}

Future<int> _attemptCount(QaApp app) async =>
    (await app.container.read(attemptsProvider.future)).length;

void registerDatos() {
  qaScenario('datos', 'las dos filas aparecen y exportar guarda el archivo', (
    tester,
  ) async {
    final store = _FakeFileStore();
    final app = await launchApp(
      tester,
      overrides: [progressFileStoreProvider.overrideWithValue(store)],
    );
    await _openAjustes(app);

    await _see(tester, find.text(T.tusDatos), what: 'the «Tus datos» section');
    await _see(tester, find.text(T.exportar), what: 'Exportar progreso');
    await _see(tester, find.text(T.importar), what: 'Importar progreso');

    await tester.tapFinder(find.text(T.exportar));
    await tester.waitFor(find.text(T.progresoGuardado));
    expect(store.saved, hasLength(1), reason: 'one file offered to the user');
    expect(
      store.saved.single.fileName,
      matches(RegExp(r'^ley-al-blanco-progreso-\d{4}-\d{2}-\d{2}\.json$')),
    );
    final json = jsonDecode(
      utf8.decode(store.saved.single.bytes),
    ) as Map<String, dynamic>;
    expect(json['format'], 'apto-armas-progress');
    expect(json['version'], 1);
    tester.expectNoException('datos');
  });

  qaScenario('datos_invalido', 'un archivo no válido se rechaza sin cambios', (
    tester,
  ) async {
    final store = _FakeFileStore(
      PickedBytes(Uint8List.fromList(utf8.encode('esto no es un progreso'))),
    );
    final app = await launchApp(
      tester,
      overrides: [progressFileStoreProvider.overrideWithValue(store)],
    );
    await _openAjustes(app);
    await _see(tester, find.text(T.importar), what: 'Importar progreso');

    await tester.tapFinder(find.text(T.importar));
    await tester.waitFor(find.text(T.importarErrorTitulo));
    expect(
      find.textContaining('está dañado o no es un archivo de progreso'),
      findsOneWidget,
    );
    // No confirmation was offered and nothing was written.
    expect(find.text(T.importarConfirmarTitulo), findsNothing);
    expect(await _attemptCount(app), 0);

    await tester.tapFinder(find.text(T.importarEntendido));
    await tester.waitGone(find.text(T.importarErrorTitulo));

    // A file that is too big is refused the same way.
    store.pickResult = const PickTooLarge();
    await tester.tapFinder(find.text(T.importar));
    await tester.waitFor(find.textContaining('demasiado grande'));
    await tester.tapFinder(find.text(T.importarEntendido));
    expect(await _attemptCount(app), 0);

    // So is a file made with another edition of the question bank, with its
    // own message (and no technical detail on screen).
    final otherEdition = jsonDecode(
      utf8.decode(_fileWithOneMistake(app)),
    ) as Map<String, dynamic>..['edition'] = 'GC-1999-01';
    store.pickResult = PickedBytes(_bytes(otherEdition));
    await tester.tapFinder(find.text(T.importar));
    await tester.waitFor(
      find.textContaining('otra edición del banco de preguntas'),
    );
    expect(find.textContaining('Detalle'), findsNothing);
    await tester.tapFinder(find.text(T.importarEntendido));
    expect(await _attemptCount(app), 0);
    tester.expectNoException('datos_invalido');
  });

  qaScenario(
    'datos_importar',
    'importar reemplaza el progreso y se ve al momento',
    (tester) async {
      final store = _FakeFileStore();
      final app = await launchApp(
        tester,
        overrides: [progressFileStoreProvider.overrideWithValue(store)],
      );
      store.pickResult = PickedBytes(_fileWithOneMistake(app));
      await _openAjustes(app);
      await _see(tester, find.text(T.importar), what: 'Importar progreso');

      await tester.tapFinder(find.text(T.importar));
      await tester.waitFor(find.text(T.importarConfirmarTitulo));
      expect(find.textContaining('1 respuesta'), findsWidgets);
      // Cancelling leaves the progress as it was.
      await tester.tapFinder(find.text('Cancelar'));
      await tester.waitGone(find.text(T.importarConfirmarTitulo));
      expect(await _attemptCount(app), 0);

      await tester.tapFinder(find.text(T.importar));
      await tester.waitFor(find.text(T.importarConfirmarTitulo));
      await tester.tapFinder(find.text(T.importarReemplazar));
      await tester.waitFor(find.text(T.progresoImportado));
      expect(await _attemptCount(app), 1);

      // Inicio shows the imported mistake without restarting the app.
      await tester.tapFinder(find.byTooltip('Atrás'));
      await waitHome(app);
      await tester.waitFor(
        find.text(T.fallosPendientes(1)),
        reason: 'the imported mistake in Fallos',
      );
      tester.expectNoException('datos_importar');
    },
  );
}
