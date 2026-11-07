import 'dart:io';
import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/application/mock_service.dart'
    show StartedMock;
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
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
/// The five scenes are the ones of `test/store/store_screenshots_test.dart`
/// (same demo data, same fixed clock of Thu 15 Oct 2026 18:30, same seeds).
/// What is real: the app, the bundled bank and its import, a Drift file in the
/// cache directory (deleted afterwards), the router and every screen. What is
/// replaced (as in the QA battery): the clock, the random source and the
/// preferences, which start empty. Nothing here is part of the production
/// entry point.
const String _bridge = String.fromEnvironment('SCREENSHOT_BRIDGE');

typedef _Scene = Future<void> Function(WidgetTester tester);

const _scenes = <(String, _Scene)>[
  ('01-preguntas-explicadas', _scenePractice),
  ('02-simulacro', _sceneMockApto),
  ('03-probabilidad', _seedProgress),
  ('04-fallos', _sceneMistakes),
  ('05-gratis', _sceneTheory),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App Store screenshots in the real iOS simulator',
    (tester) async {
      expect(Platform.isIOS, isTrue, reason: 'Use tool/screenshots/auto_ios.py');
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

/// Boots the real app over a fresh database file, empty preferences, the
/// fixed clock and the seed of the store scenes, light theme, text scale 1.
Future<_Running> _launch(WidgetTester tester) async {
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
        clockProvider.overrideWithValue(() => kTestNow),
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
// Scenes (the same as test/store/store_screenshots_test.dart)
// ---------------------------------------------------------------------------

/// Practice screen on t2-010 answered right: verdict, explanation and the
/// article chip in view. The student has done the first 9 questions of tema 2.
Future<void> _scenePractice(WidgetTester tester) async {
  final bank = await bankOf(tester);
  final done = bank
      .where((q) => q.tema == 2)
      .takeWhile((q) => q.id != 't2-010');
  await containerOf(tester).read(studyServiceProvider).recordAnswers([
    for (final q in done)
      attemptOn(
        q,
        correct: true,
        at: kTestNow.subtract(const Duration(days: 3)),
      ),
  ]);
  await tester.pumpAndSettle();
  await pushRoute(tester, '/tema/2');
  final q = containerOf(tester)
      .read(practiceControllerProvider(const TemaPractice(2)))
      .requireValue
      .session!
      .currentQuestion;
  expect(q.id, 't2-010', reason: 'the practice scene is built on t2-010');
  expect(q.explanation, isNotEmpty);
  expect(q.article, isNotNull);
  await tapOption(tester, q.answer);
  await tester.ensureVisible(find.byType(ArticleChip));
  await tester.pumpAndSettle();
}

/// A mock handed in with 18 right and 2 wrong: APTO.
Future<void> _sceneMockApto(WidgetTester tester) async {
  final container = containerOf(tester);
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  await _answerMock(tester, started, right: 18, wrong: 2);
  await pushRoute(tester, '/simulacro/${started.id}/resultado');
}

Future<void> _answerMock(
  WidgetTester tester,
  StartedMock started, {
  required int right,
  required int wrong,
}) async {
  final container = containerOf(tester);
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < right + wrong; i++) {
    controller.goTo(i);
    final q = started.questions[i];
    controller.select(i < right ? q.answer : wrongOption(q));
  }
  controller.goTo(0);
  await controller.submit();
  await controller.pendingSaves;
}

/// A student well on the way: every tema started, none finished, each seen
/// question answered five times over the last five days. Seeded `Random(11)`.
Future<void> _seedProgress(WidgetTester tester) async {
  final bank = await bankOf(tester);
  const coverage = {1: .97, 2: .95, 3: .93, 4: .90, 5: .88, 6: .85, 7: .82};
  final rng = Random(11);
  final attempts = <Attempt>[];
  for (var tema = 1; tema <= 7; tema++) {
    final all = bank.where((q) => q.tema == tema).toList();
    final seen = all.take((all.length * coverage[tema]!).ceil());
    for (final q in seen) {
      final missedEarly = rng.nextDouble() < .04;
      final missedLast = rng.nextDouble() < .025;
      for (final daysAgo in [5, 4, 3, 2, 1]) {
        final correct =
            !((daysAgo == 5 && missedEarly) || (daysAgo == 1 && missedLast));
        attempts.add(
          attemptOn(
            q,
            correct: correct,
            at: kTestNow.subtract(Duration(days: daysAgo)),
          ),
        );
      }
    }
  }
  await containerOf(tester).read(studyServiceProvider).recordAnswers(attempts);
  await tester.pumpAndSettle();
}

/// Fallos: eight failed questions across the seven temas (two in tema 2).
Future<void> _sceneMistakes(WidgetTester tester) async {
  final bank = await bankOf(tester);
  final picks = const [
    (1, 3),
    (2, 8),
    (2, 14),
    (3, 5),
    (4, 9),
    (5, 4),
    (6, 11),
    (7, 6),
  ];
  final attempts = <Attempt>[];
  for (final (tema, n) in picks) {
    final q = bank.where((q) => q.tema == tema).toList()[n];
    attempts.add(
      attemptOn(
        q,
        correct: false,
        at: kTestNow.subtract(Duration(hours: tema)),
      ),
    );
  }
  await containerOf(tester).read(studyServiceProvider).recordAnswers(attempts);
  await tester.pumpAndSettle();
  await pushRoute(tester, '/fallos');
}

Future<void> _sceneTheory(WidgetTester tester) => pushRoute(tester, '/teoria');
