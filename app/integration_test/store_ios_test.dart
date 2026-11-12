import 'dart:io';
import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers.dart' show kTestNow;
import '../test/support/screen_support.dart';
import '../test/support/study_support.dart' show wrongOption;
import 'support/qa_harness.dart' show QaTester;
import 'support/qa_texts.dart' show T;
import 'support/store_demo.dart';

/// Driver of the App Store screenshots taken on a REAL iOS simulator.
///
/// Not run on its own: `tool/screenshots/auto_ios.py` creates the simulator,
/// starts a loopback bridge and runs this file with
/// `--dart-define=SCREENSHOT_BRIDGE=<url>`. Without the bridge the test is
/// skipped, so `flutter test integration_test` (the QA battery) is not
/// affected. The script takes the picture (`simctl io screenshot`) when this
/// test POSTs `capture/<name>` and answers only after saving it; the test
/// stays on the screen until then.
///
/// The five scenes are the five screens of `docs/readme/es/` (home with the
/// chance of passing, mock result, Fallos, a figures card and the glossary),
/// light theme, text scale 1, with the demo data of `support/store_demo.dart`
/// and the fixed clock of Thu 15 Oct 2026 18:30. The pictures are the raw app
/// screen: the shared styler (`store_shots.py`) adds the frame and the title.
/// What is real: the app, the bundled bank and its import, a Drift file in the
/// cache directory (deleted afterwards), the router and every screen. What is
/// replaced (as in the QA battery): the clock, the random source and the
/// preferences, which start empty. Nothing here is part of the production
/// entry point.
const String _bridge = String.fromEnvironment('SCREENSHOT_BRIDGE');

typedef _Scene = Future<void> Function(WidgetTester tester);

const _scenes = <(String, _Scene)>[
  ('01-probabilidad', _sceneHome),
  ('02-simulacro', _sceneMockApto),
  ('03-fallos', _sceneMistakes),
  ('04-tarjetas-cifras', _sceneFiguresCard),
  ('05-glosario', _sceneGlossary),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App Store screenshots in the real iOS simulator',
    (tester) async {
      expect(
        Platform.isIOS,
        isTrue,
        reason: 'Use tool/screenshots/auto_ios.py',
      );
      expect(_bridge, startsWith('http://127.0.0.1:'));
      final base = Uri.parse(_bridge);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      addTearDown(() => client.close(force: true));

      Future<void> capture(String name) async {
        final request = await client.postUrl(base.resolve('capture/$name'));
        final response = await request.close().timeout(
          const Duration(seconds: 90),
        );
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.ok, reason: name);
      }

      for (final (name, scene) in _scenes) {
        final app = await _launch(
          tester,
          figuresDeck: name == '04-tarjetas-cifras',
        );
        try {
          await scene(tester);
          await tester.pumpAndSettle();
          // Let the last animation and the scroll position settle for real.
          await tester.pumpFor(const Duration(milliseconds: 800));
          await capture(name);
        } finally {
          await app.dispose();
        }
      }
    },
    skip: _bridge.isEmpty,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

// ---------------------------------------------------------------------------
// App under test
// ---------------------------------------------------------------------------

class _Running {
  _Running(this.tester, this.dbPath);

  final WidgetTester tester;
  final String dbPath;

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // The providers are disposed: give the database isolate time to close.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$dbPath$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  }
}

/// The clock of the scene under test: fixed, moved only by the mock scene.
DateTime _now = kTestNow;

/// Boots the real app over a fresh database file, empty preferences, the
/// fixed clock and the seed of the store scenes, light theme, text scale 1.
/// [figuresDeck] picks the seed with which the figures deck starts on t4-032.
Future<_Running> _launch(
  WidgetTester tester, {
  bool figuresDeck = false,
}) async {
  _now = kTestNow;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final temp = await tester.runAsync(getTemporaryDirectory) as Directory;
  final prefs =
      await tester.runAsync(SharedPreferences.getInstance) as SharedPreferences;
  await tester.runAsync(prefs.clear);
  final dbPath =
      '${temp.path}${Platform.pathSeparator}'
      'store_${DateTime.now().microsecondsSinceEpoch}.sqlite';

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => _now),
        randomProvider.overrideWithValue(
          Random(figuresDeck ? kDemoFiguresSeed : 7),
        ),
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(
            driftDatabase(
              name: 'apto_store',
              native: DriftNativeOptions(databasePath: () async => dbPath),
            ),
          );
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.waitFor(
    find.byType(TemaCard),
    count: 7,
    timeout: const Duration(seconds: 90),
    reason: 'Inicio (7 temas) after the bootstrap',
  );
  await tester.pumpFor(const Duration(milliseconds: 400));
  return _Running(tester, dbPath);
}

// ---------------------------------------------------------------------------
// Scenes (the five screens of docs/readme/es/)
// ---------------------------------------------------------------------------

/// Records the demo student's attempts (see `support/store_demo.dart`).
Future<void> _seedProgress(WidgetTester tester) async {
  final bank = await bankOf(tester);
  await containerOf(tester)
      .read(studyServiceProvider)
      .recordAnswers(demoProgress(bank));
  await tester.pumpAndSettle();
}

/// Home: chance of passing, daily question, Simulacro and Fallos.
Future<void> _sceneHome(WidgetTester tester) => _seedProgress(tester);

/// A mock handed in with 17 right and 3 wrong (questions 4, 10 and 17) in
/// 20 min 31 s: APTO.
Future<void> _sceneMockApto(WidgetTester tester) async {
  final container = containerOf(tester);
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < 20; i++) {
    controller.goTo(i);
    final q = started.questions[i];
    controller.select(const {3, 9, 16}.contains(i) ? wrongOption(q) : q.answer);
  }
  controller.goTo(0);
  _now = _now.add(kDemoMockTime);
  await controller.submit();
  await controller.pendingSaves;
  await pushRoute(tester, '/simulacro/${started.id}/resultado');
}

/// Fallos: the twenty failed questions of the demo student.
Future<void> _sceneMistakes(WidgetTester tester) async {
  await _seedProgress(tester);
  await pushRoute(tester, '/fallos');
}

/// A figures card with the answer revealed (t4-032, first of 76).
Future<void> _sceneFiguresCard(WidgetTester tester) async {
  await pushRoute(tester, '/cifras/tarjetas');
  await tester.tapText(T.verRespuesta);
  await tester.pumpAndSettle();
}

/// Theory, glossary.
Future<void> _sceneGlossary(WidgetTester tester) =>
    pushRoute(tester, '/teoria/glosario');
