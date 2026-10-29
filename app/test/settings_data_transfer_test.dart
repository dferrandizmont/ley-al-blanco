import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/mock/domain/mock_config.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_codec_runner.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_file_store.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_codec.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_snapshot.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/settings_support.dart';

/// «Tus datos» in Ajustes: export and import of the progress through the
/// system file dialogs (replaced by [FakeProgressFileStore]).

const _exportTitle = 'Exportar progreso';
const _importTitle = 'Importar progreso';

void _phone(WidgetTester tester, {double textScale = 1, Size? size}) {
  tester.view.physicalSize = size ?? const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

Future<void> _pump(
  WidgetTester tester,
  FakeProgressFileStore store, {
  double textScale = 1,
  Size? size,

  ProgressCodecRunner? runner,
}) async {
  _phone(tester, textScale: textScale, size: size);
  await pumpFullApp(
    tester,
    overrides: settingsOverrides(
      launcher: FakeUrlLauncher(),
      fileStore: store,
      codecRunner: runner ?? const InlineProgressCodecRunner(),
    ),
  );
  await openRoute(tester, '/ajustes');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A codec that waits for [gate] before it works: the "working" state stays
/// on screen as long as the test wants.
class _GatedRunner extends ProgressCodecRunner {
  _GatedRunner(this.gate);

  final Completer<void> gate;

  @override
  Future<ProgressSnapshot> parse(
    Uint8List bytes, {
    required DateTime now,
    int mockSize = MockConfig.defaultSize,
  }) async {
    await gate.future;
    return ProgressCodec.parse(bytes, now: now, mockSize: mockSize);
  }

  @override
  Future<Uint8List> encode(ProgressSnapshot snapshot) async {
    await gate.future;
    return ProgressCodec.encode(snapshot);
  }
}

/// A codec whose export is bigger than the import limit.
class _HugeRunner extends InlineProgressCodecRunner {
  const _HugeRunner();

  @override
  Future<Uint8List> encode(ProgressSnapshot snapshot) async =>
      Uint8List(kMaxProgressFileBytes + 1);
}

/// The id of the first bank question of [tema].

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

Future<int> _attemptCount(WidgetTester tester) async =>
    (await containerOf(tester).read(attemptsProvider.future)).length;

void main() {
  group('the section', () {
    testScreen('has the two rows with their explanation', (tester) async {
      await _pump(tester, FakeProgressFileStore());
      expect(find.text('TUS DATOS'), findsOneWidget);
      expect(find.text(_exportTitle), findsOneWidget);
      expect(find.text(_importTitle), findsOneWidget);
      expect(find.textContaining('Tú eliges dónde.'), findsOneWidget);
      expect(
        find.textContaining('Reemplaza el progreso de este móvil.'),
        findsOneWidget,
      );
    });

    testScreen('the rows are buttons for a screen reader, at least 48 dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, FakeProgressFileStore());
      for (final title in [_exportTitle, _importTitle]) {
        final finder = find.bySemanticsLabel(RegExp('^$title'));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(finder),
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: title,
        );
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });

    testScreen('is there for a free user too', (tester) async {
      await _pump(tester, FakeProgressFileStore());
      expect(find.text(_exportTitle), findsOneWidget);
    });

    testScreen('lays out at 320 x 568 with the text x1.3', (tester) async {
      await _pump(
        tester,
        FakeProgressFileStore(),
        textScale: 1.3,
        size: const Size(320, 568),
      );
      await tester.ensureVisible(find.text(_importTitle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('export', () {
    testScreen('saves the file with the date in its name and says so', (
      tester,
    ) async {
      final store = FakeProgressFileStore();
      await _pump(tester, store);
      await _tap(tester, find.text(_exportTitle));

      expect(store.saved, hasLength(1));
      expect(
        store.saved.single.fileName,
        'ley-al-blanco-progreso-2026-10-15.json',
      );
      final json = jsonDecode(
        utf8.decode(store.saved.single.bytes),
      ) as Map<String, dynamic>;
      expect(json['format'], 'apto-armas-progress');
      expect(json['version'], 1);
      expect(json['edition'], 'GC-2020-11');
      expect(find.text('Progreso guardado.'), findsOneWidget);
    });

    testScreen('the user cancelling the dialog says nothing', (tester) async {
      final store = FakeProgressFileStore(saveResult: false);
      await _pump(tester, store);
      await _tap(tester, find.text(_exportTitle));
      expect(store.saved, hasLength(1));
      expect(find.text('Progreso guardado.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testScreen('a failure to save is reported', (tester) async {
      final store = FakeProgressFileStore(saveError: StateError('disco lleno'));
      await _pump(tester, store);
      await _tap(tester, find.text(_exportTitle));
      expect(find.text('No se ha podido guardar el archivo.'), findsOneWidget);
      expect(find.text('Progreso guardado.'), findsNothing);
    });

    testScreen('an export over the import limit has its own message', (
      tester,
    ) async {
      final store = FakeProgressFileStore();
      await _pump(tester, store, runner: const _HugeRunner());
      await _tap(tester, find.text(_exportTitle));
      expect(store.saved, isEmpty, reason: 'nothing is written');
      expect(find.textContaining('más de 10 MB'), findsOneWidget);
      expect(find.text('No se ha podido guardar el archivo.'), findsNothing);
    });

    testScreen('a progress bar shows while the file is built, and the rows '
        'do nothing meanwhile', (tester) async {
      final gate = Completer<void>();
      final store = FakeProgressFileStore();
      await _pump(tester, store, runner: _GatedRunner(gate));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.ensureVisible(find.text(_exportTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_exportTitle));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Importing meanwhile does nothing.
      await tester.tap(find.text(_importTitle));
      await tester.pump(const Duration(milliseconds: 20));
      expect(store.pickCalls, 0);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(store.saved, hasLength(1));
      expect(find.text('Progreso guardado.'), findsOneWidget);
    });

    testScreen('the export has the progress that exists, and no purchase', (
      tester,
    ) async {
      final store = FakeProgressFileStore();
      await _pump(tester, store);
      await _tap(tester, find.text(_exportTitle));
      final text = utf8.decode(store.saved.single.bytes);
      expect(text, isNot(contains('entitlement')));
      expect(text, isNot(contains('full')));
    });
  });

  group('import', () {
    testScreen('cancelling the picker changes nothing and shows nothing', (
      tester,
    ) async {
      final store = FakeProgressFileStore();
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));
      expect(store.pickCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testScreen('a valid file asks first and says what it brings', (
      tester,
    ) async {
      final store = FakeProgressFileStore(
        pickResult: PickedBytes(progressFileBytes(attempts: 6, srs: 2)),
      );
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));

      expect(find.text('¿Reemplazar tu progreso?'), findsOneWidget);
      expect(
        find.textContaining(
          'Reemplaza tu progreso actual por el del archivo. No se puede deshacer.',
        ),
        findsOneWidget,
      );
      expect(find.text('6 respuestas, de ellas 2 falladas'), findsOneWidget);
      expect(find.text('1 simulacro'), findsOneWidget);
      expect(find.text('2 preguntas en el repaso diario'), findsOneWidget);
      expect(find.text('Exportado el 12 oct 2026'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Reemplazar'), findsOneWidget);
      // Nothing was touched yet.
      expect(await _attemptCount(tester), 0);
    });

    testScreen('"Cancelar" leaves everything as it was', (tester) async {
      final store = FakeProgressFileStore(
        pickResult: PickedBytes(progressFileBytes()),
      );
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Progreso importado.'), findsNothing);
      expect(await _attemptCount(tester), 0);
      expect(_themeMode(tester), ThemeMode.system);
    });

    testScreen('"Reemplazar" imports and everything refreshes at once', (
      tester,
    ) async {
      final store = FakeProgressFileStore(
        pickResult: PickedBytes(progressFileBytes(attempts: 6, theme: 'dark')),
      );
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));
      await tester.tap(find.text('Reemplazar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Progreso importado.'), findsOneWidget);
      expect(await _attemptCount(tester), 6);
      // The appearance of the file is applied without restarting.
      expect(_themeMode(tester), ThemeMode.dark);
      final db = containerOf(tester).read(appDatabaseProvider);
      expect(await db.mocksDao.startedCount(), 1);
      expect(await db.srsDao.all(), hasLength(2));
    });

    testScreen('importing with Inicio underneath builds no provider during '
        'a build and Inicio shows the imported mistake', (tester) async {
      final store = FakeProgressFileStore(
        pickResult: PickedBytes(
          progressFileBytes(
            attempts: 1,
            srs: 0,
            edit: (json) => json['mocks'] = <Object?>[],
          ),
        ),
      );
      _phone(tester);
      await pumpFullApp(
        tester,
        overrides: settingsOverrides(
          launcher: FakeUrlLauncher(),
          fileStore: store,
          codecRunner: const InlineProgressCodecRunner(),
        ),
      );
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text(_importTitle));
      await tester.tap(find.text('Reemplazar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_themeMode(tester), ThemeMode.dark);
    });

    testScreen('what refers to unknown questions is dropped and announced', (
      tester,
    ) async {
      final bytes = progressFileBytes(
        attempts: 4,
        edit: (json) {
          final attempts = json['attempts'] as List;
          (attempts[0] as Map)['question_id'] = 't9-999';
          (attempts[1] as Map)['question_id'] = 'xx';
        },
      );
      final store = FakeProgressFileStore(pickResult: PickedBytes(bytes));
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));
      expect(find.text('2 respuestas, de ellas 1 fallada'), findsOneWidget);
      expect(
        find.textContaining('Se ignorarán 2 datos que no se pueden usar'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reemplazar'));
      await tester.pumpAndSettle();
      expect(await _attemptCount(tester), 2);
    });

    Future<void> expectRefused(
      WidgetTester tester,
      PickedProgressFile picked,
      String message,
    ) async {
      final store = FakeProgressFileStore(pickResult: picked);
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));
      expect(find.text('No se puede importar'), findsOneWidget);
      expect(find.textContaining(message), findsOneWidget);
      // No confirmation, nothing written.
      expect(find.text('¿Reemplazar tu progreso?'), findsNothing);
      expect(await _attemptCount(tester), 0);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Progreso importado.'), findsNothing);
    }

    testScreen('a corrupt file is refused', (tester) async {
      await expectRefused(
        tester,
        PickedBytes(Uint8List.fromList(utf8.encode('{"format": "apto'))),
        'está dañado o no es un archivo de progreso',
      );
    });

    testScreen('a file from another app is refused', (tester) async {
      await expectRefused(
        tester,
        PickedBytes(Uint8List.fromList(utf8.encode('{"hola": 1}'))),
        'no es un progreso exportado por Ley al Blanco',
      );
    });

    for (final date in ['2026-02-30T10:00:00Z', '2026-10-15T10:00:00+24:00']) {
      testScreen('invalid date/time has a specific message: $date', (
        tester,
      ) async {
        await expectRefused(
          tester,
          PickedBytes(
            progressFileBytes(
              edit: (j) =>
                  ((j['attempts'] as List).first as Map)['answered_at'] = date,
            ),
          ),
          'fecha u hora no válida',
        );
      });
    }

    testScreen('excessive nesting has a specific message', (tester) async {
      await expectRefused(
        tester,
        PickedBytes(Uint8List.fromList(utf8.encode('${'[' * 9}0${']' * 9}'))),
        'demasiado anidado o dañado',
      );
    });

    testScreen('a newer version is refused and says to update', (tester) async {
      await expectRefused(
        tester,
        PickedBytes(progressFileBytes(edit: (j) => j['version'] = 2)),
        'versión más nueva de Ley al Blanco',
      );
    });

    testScreen('a file with a wrong type is refused and names the field', (
      tester,
    ) async {
      await expectRefused(
        tester,
        PickedBytes(
          progressFileBytes(
            edit: (j) =>
                ((j['attempts'] as List).first as Map)['selected'] = 'a',
          ),
        ),
        'datos que no son válidos',
      );
      // The technical detail (field names, in English) never reaches the UI.
      expect(find.textContaining('attempts'), findsNothing);
      expect(find.textContaining('Detalle'), findsNothing);
    });

    testScreen('a file from another bank edition is refused, with its own '
        'message', (tester) async {
      await expectRefused(
        tester,
        PickedBytes(
          progressFileBytes(edit: (j) => j['edition'] = 'GC-2019-01'),
        ),
        'otra edición del banco de preguntas',
      );
    });

    testScreen('a file that is too big is refused', (tester) async {
      await expectRefused(tester, const PickTooLarge(), 'demasiado grande');
    });

    testScreen('a failing picker is reported as a failure', (tester) async {
      final store = FakeProgressFileStore(pickError: StateError('sin permiso'));
      await _pump(tester, store);
      await _tap(tester, find.text(_importTitle));
      expect(find.text('No se puede importar'), findsOneWidget);
      expect(
        find.textContaining('No se ha podido importar el archivo.'),
        findsOneWidget,
      );
      expect(await _attemptCount(tester), 0);
    });

    testScreen('a progress bar shows while the file is read', (tester) async {
      final gate = Completer<void>();
      final store = FakeProgressFileStore(
        pickResult: PickedBytes(progressFileBytes()),
      );
      await _pump(tester, store, runner: _GatedRunner(gate));
      await tester.ensureVisible(find.text(_importTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_importTitle));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('¿Reemplazar tu progreso?'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('¿Reemplazar tu progreso?'), findsOneWidget);
    });

    testScreen('the dialogs lay out at 320 x 568 with the text x1.3', (
      tester,
    ) async {
      final store = FakeProgressFileStore(
        pickResult: PickedBytes(progressFileBytes(attempts: 120, srs: 40)),
      );
      await _pump(tester, store, textScale: 1.3, size: const Size(320, 568));
      await _tap(tester, find.text(_importTitle));
      expect(find.text('¿Reemplazar tu progreso?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      store.pickResult = PickedBytes(
        progressFileBytes(edit: (j) => j['version'] = 9),
      );
      await _tap(tester, find.text(_importTitle));
      expect(find.text('No se puede importar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
