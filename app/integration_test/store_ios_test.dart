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
import '../test/support/study_support.dart' show attemptOn, wrongOption;
import 'support/qa_harness.dart' show QaTester;
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
/// The six scenes are the screens of the App Store listing (a practice
/// question explained, mock result, Teoria, a question with its reform notice,
/// home with the chance of passing and Fallos), light theme, text scale 1, with the demo data of `support/store_demo.dart`
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
  ('01-explicada', _sceneExplained),
  ('02-simulacro', _sceneMockApto),
  ('03-teoria', _sceneTheory),
  ('04-reforma', _sceneReformNotice),
  ('05-probabilidad', _sceneHome),
  ('06-fallos', _sceneMistakes),
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
        final app = await _launch(tester);
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
Future<_Running> _launch(WidgetTester tester) async {
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
        randomProvider.overrideWithValue(Random(7)),
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
// Scenes (the six screens of the App Store listing)
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

/// Teoria: the seven temas, practical exam, AEM and glossary.
Future<void> _sceneTheory(WidgetTester tester) => pushRoute(tester, '/teoria');

/// A tema practice that starts on question [id]: the questions of its tema
/// that come before it are recorded as answered (the practice resumes at the
/// first one never answered), then the official answer is picked. With
/// [showArticle] the card is scrolled down to the cited article; without it
/// the screen stays on top, with the stem and the options in view.
Future<void> _practiceAnswered(
  WidgetTester tester,
  String id, {
  required bool showArticle,
}) async {
  final bank = await bankOf(tester);
  final question = bank.firstWhere((q) => q.id == id);
  final before = bank
      .where((q) => q.tema == question.tema)
      .takeWhile((q) => q.id != id);
  await containerOf(tester).read(studyServiceProvider).recordAnswers([
    for (final q in before)
      attemptOn(
        q,
        correct: true,
        at: kTestNow.subtract(const Duration(days: 1)),
      ),
  ]);
  await pushRoute(tester, '/tema/${question.tema}');
  await tapOption(tester, question.answer);
  await tester.pumpAndSettle();
  final article = find.text(question.article!);
  if (showArticle && article.evaluate().isNotEmpty) {
    await tester.ensureVisible(article.first);
    await tester.pumpAndSettle();
  }
}

/// A practice question answered right, with the verdict, our explanation and
/// its article (t2-010, no reform flag).
Future<void> _sceneExplained(WidgetTester tester) =>
    _practiceAnswered(tester, kDemoExplainedId, showArticle: true);

/// A practice question answered right whose official answer comes from a
/// repealed law: the reform notice shows above the explanation (t5-010).
Future<void> _sceneReformNotice(WidgetTester tester) =>
    _practiceAnswered(tester, kDemoReformId, showArticle: false);
