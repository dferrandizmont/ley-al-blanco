import 'dart:io';
import 'dart:math' show Random;

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/router.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qa_bank.dart';

/// Comma-separated scenario ids to run (`--dart-define=QA_ONLY=arranque,ajustes`).
const String kQaOnly = String.fromEnvironment('QA_ONLY');

/// Comma-separated scenario ids to leave out (`--dart-define=QA_SKIP=ajustes`).
const String kQaSkip = String.fromEnvironment('QA_SKIP');

/// Wall clock for the app under test, pinned to 10:00 local today and moving
/// forward in real time, so attempts get increasing timestamps but a scenario
/// can never cross midnight.
class QaClock {
  QaClock() : base = _tenToday();

  final DateTime base;
  final Stopwatch _elapsed = Stopwatch()..start();
  Duration _skipped = Duration.zero;

  static DateTime _tenToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 10);
  }

  DateTime call() => base.add(_elapsed.elapsed + _skipped);

  /// Jumps forward, as if the user came back later (stays before midnight).
  void advance(Duration by) => _skipped += by;
}

/// A running app plus the handles a scenario needs.
///
/// What is real: the Drift database (a fresh file on the device, per
/// scenario), the bundled question bank and its import, SharedPreferences,
/// the router and every screen. What is replaced (and only that): the store
/// source (fixed seed) and the clock ([QaClock]).
class QaApp {
  QaApp._({
    required this.tester,
    required this.bank,
    required this.prefs,
    required this.dbPath,
    required this.clock,
    required this.seed,
    this.extraOverrides = const [],
  });

  final WidgetTester tester;
  final QaBank bank;
  final SharedPreferences prefs;
  final String dbPath;

  /// its support directory, which would leak between scenarios).
  final QaClock clock;
  final int seed;

  /// Extra provider overrides of this launch (e.g. the support address and a
  /// recording launcher, so nothing leaves the app).
  final List<Override> extraOverrides;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(LeyAlBlancoApp)));

  GoRouter get router => container.read(routerProvider);

  /// Current location of the router (e.g. `/tema/1`), including routes
  /// opened with `context.push` (the route information provider only
  /// reflects declarative `go` navigation).
  String get location => router.state.uri.toString();

  /// `context.go(path)`.
  void go(String path) => router.go(path);

  Future<void> _mount() async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        // Failed providers surface their error instead of silently retrying.
        retry: (count, error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          randomProvider.overrideWithValue(Random(seed)),
          clockProvider.overrideWithValue(clock.call),
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(
              driftDatabase(
                name: 'apto_qa',
                native: DriftNativeOptions(databasePath: () async => dbPath),
              ),
            );
            ref.onDispose(db.close);
            return db;
          }),
          ...extraOverrides,
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
    // Let the first frames and the store lookup settle.
    await tester.pumpFor(const Duration(milliseconds: 400));
  }

  Future<void> _unmount() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // The providers are disposed: give the database isolate time to close.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
  }

  /// Reopens the same database and preferences.
  Future<void> restart() async {
    await _unmount();
    await _mount();
  }

  /// Unmounts the app and deletes the scenario's database.
  Future<void> dispose() async {
    try {
      await _unmount();
    } finally {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        try {
          final file = File('$dbPath$suffix');
          if (file.existsSync()) file.deleteSync();
        } on Object {
          // A leftover file in the cache dir is harmless.
        }
      }
    }
  }
}

/// The app being driven by the running scenario (torn down by [qaScenario]).
QaApp? _active;

/// Boots LeyAlBlancoApp over a fresh Drift file and cleared preferences.
///
/// * [textScale], [dark], [logicalSize] reproduce accessibility and small
///   screens without touching the app's settings.
Future<QaApp> launchApp(
  WidgetTester tester, {
  double textScale = 1,
  bool dark = false,
  Size? logicalSize,
  int seed = 7,
  List<Override> overrides = const [],
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  if (logicalSize != null) {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(
      logicalSize.width * dpr,
      logicalSize.height * dpr,
    );
  }

  final bank = await tester.runAsync(QaBank.load) as QaBank;
  final temp = await tester.runAsync(getTemporaryDirectory) as Directory;
  final prefs =
      await tester.runAsync(SharedPreferences.getInstance) as SharedPreferences;
  await tester.runAsync(prefs.clear);

  final stamp = DateTime.now().microsecondsSinceEpoch;
  final app = QaApp._(
    tester: tester,
    bank: bank,
    prefs: prefs,
    dbPath:
        '${temp.path}${Platform.pathSeparator}'
        'apto_qa_$stamp.sqlite',
    clock: QaClock(),
    seed: seed,
    extraOverrides: overrides,
  );
  _active = app;
  await app._mount();
  return app;
}

extension QaTester on WidgetTester {
  /// Advances real time (the integration binding delays for real).
  Future<void> pumpFor(Duration duration) async {
    final end = DateTime.now().add(duration);
    do {
      await pump(const Duration(milliseconds: 50));
    } while (DateTime.now().isBefore(end));
  }

  /// Pumps until [finder] matches (exactly [count] times when given).
  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
    String? reason,
    int? count,
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      await pump(const Duration(milliseconds: 50));
      final n = finder.evaluate().length;
      if (count == null ? n > 0 : n == count) return;
      if (!DateTime.now().isBefore(end)) {
        throw TestFailure(
          'Timed out (${timeout.inSeconds}s) waiting for '
          '${reason ?? finder}${count == null ? '' : ' x$count (found $n)'}. '
          'On screen: ${visibleTexts().take(40).join(' | ')}',
        );
      }
    }
  }

  /// Pumps until [condition] holds.
  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 20),
    String reason = 'condition',
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      await pump(const Duration(milliseconds: 50));
      if (condition()) return;
      if (!DateTime.now().isBefore(end)) {
        throw TestFailure(
          'Timed out (${timeout.inSeconds}s) waiting for $reason. '
          'On screen: ${visibleTexts().take(40).join(' | ')}',
        );
      }
    }
  }

  /// Pumps until [finder] matches nothing.
  Future<void> waitGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    String? reason,
  }) => waitUntil(
    () => finder.evaluate().isEmpty,
    timeout: timeout,
    reason: '${reason ?? finder} to disappear',
  );

  /// Taps the first match of [finder] (scrolling it into view) and lets the
  /// UI react for [wait].
  Future<void> tapFinder(
    Finder finder, {
    String? reason,
    Duration wait = const Duration(milliseconds: 450),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await waitFor(finder, reason: reason, timeout: timeout);
    try {
      await ensureVisible(finder.first);
    } on Object {
      // Not in a scrollable: nothing to scroll.
    }
    await pump(const Duration(milliseconds: 150));
    await tap(finder.first, warnIfMissed: false);
    await pumpFor(wait);
  }

  /// Taps the [index]-th visible Text equal to [text].
  Future<void> tapText(
    String text, {
    int index = 0,
    Duration wait = const Duration(milliseconds: 450),
  }) =>
      tapFinder(find.text(text).at(index), reason: 'text "$text"', wait: wait);

  /// The visible Text strings (diagnostics and assertions).
  List<String> visibleTexts() {
    final out = <String>[];
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      final s = widget.data ?? widget.textSpan?.toPlainText();
      if (s != null && s.trim().isNotEmpty) out.add(s.trim());
    }
    return out;
  }

  bool hasText(String text) => find.text(text).evaluate().isNotEmpty;

  /// Android's system back button.
  Future<void> systemBack({
    Duration wait = const Duration(milliseconds: 600),
  }) async {
    await binding.handlePopRoute();
    await pumpFor(wait);
  }

  /// Fails if the framework reported an exception (a RenderFlex overflow, a
  /// build error...) since the last check.
  void expectNoException(String where) {
    final error = takeException();
    if (error != null) {
      throw TestFailure('Framework exception at "$where": $error');
    }
  }
}

/// A filter entry matches a scenario id exactly or as a family prefix
/// (`ajustes` also selects `ajustes_tema`).
bool _matches(String filter, String id) =>
    id == filter || id.startsWith('${filter}_');

/// One QA scenario. Prints machine-readable lines the runner parses:
/// `QA_RESULT|<id>|PASS|<ms>|` or `QA_RESULT|<id>|FAIL|<ms>|<message>`. On a
/// failure it first prints `QA_SHOT|<id>` and waits a moment, so the host
/// script can take a screenshot of the failing screen.
void qaScenario(
  String id,
  String title,
  Future<void> Function(WidgetTester tester) body, {
  Duration timeout = const Duration(minutes: 5),
}) {
  final only = kQaOnly.split(',').where((e) => e.isNotEmpty).toList();
  if (only.isNotEmpty && !only.any((e) => _matches(e, id))) return;
  final skip = kQaSkip.split(',').where((e) => e.isNotEmpty);
  if (skip.any((e) => _matches(e, id))) return;
  testWidgets('$id: $title', (tester) async {
    final stopwatch = Stopwatch()..start();
    // ignore: avoid_print
    print('QA_START|$id|$title');
    _active = null;
    Object? failure;
    try {
      await body(tester);
      tester.expectNoException('end of $id');
    } catch (e, st) {
      failure = e;
      var message = e.toString().replaceAll(RegExp(r'\s*\n\s*'), ' // ');
      try {
        message =
            '$message // SCREEN: ${tester.visibleTexts().take(40).join(' | ')}';
      } on Object {
        // No widget tree to read.
      }
      // ignore: avoid_print
      print('QA_SHOT|$id');
      try {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
      } on Object {
        // The screenshot grace period is best effort.
      }
      // ignore: avoid_print
      print('QA_RESULT|$id|FAIL|${stopwatch.elapsedMilliseconds}|$message');
      // ignore: avoid_print
      print('QA_TRACE|$id|${st.toString().split('\n').take(8).join(' // ')}');
    } finally {
      try {
        tester.platformDispatcher.clearAllTestValues();
        tester.view.reset();
        await _active?.dispose();
      } on Object catch (e) {
        // ignore: avoid_print
        print('QA_TEARDOWN|$id|$e');
      }
      _active = null;
    }
    if (failure == null) {
      // ignore: avoid_print
      print('QA_RESULT|$id|PASS|${stopwatch.elapsedMilliseconds}|');
    } else {
      // ignore: only_throw_errors
      throw failure;
    }
  }, timeout: Timeout(timeout));
}
