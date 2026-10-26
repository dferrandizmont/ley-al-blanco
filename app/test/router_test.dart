import 'dart:math' show Random;

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/core/router.dart';
import 'package:apto_armas/features/mock/domain/mock_config.dart';
import 'package:apto_armas/features/mock/domain/mock_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/db_support.dart';
import 'support/theory_support.dart';

void main() {
  late ProviderContainer container;

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    AssetBundle? bundle,
    List<Override> overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...databaseTestOverrides(bundle: bundle),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LeyAlBlancoApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container.read(routerProvider);
  }

  String location(GoRouter router) =>
      router.routeInformationProvider.value.uri.toString();

  testWidgets('starts on /', (tester) async {
    final router = await pumpRouter(tester);
    expect(location(router), '/');
    expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);
  });

  testWidgets('an unknown path falls back to / without an error page', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    router.go('/no-such-screen');
    await tester.pumpAndSettle();
    expect(location(router), '/');
    expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a foreign-scheme URI (content://, file://) falls back to /', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    router.go('content://media/external/images/1');
    await tester.pumpAndSettle();
    expect(location(router), '/');
    expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every study route builds its screen', (tester) async {
    final router = await pumpRouter(tester);
    // Secondary screens keep an app bar with the title; the question screens
    // carry it as the overline of the question card.
    final appBarTitles = {'/fallos': 'Fallos', '/simulacro': 'Simulacro'};
    for (final entry in appBarTitles.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(location(router), entry.key);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
        reason: entry.key,
      );
    }
    final cardTitles = {
      '/tema/5': 'TEMA 5 · RÉGIMEN SANCIONADOR',
      '/repaso': 'REPASO DEL DÍA',
      // Nothing failed yet: the empty state stands in for the question.
      '/fallos/repasar': 'No hay fallos que repasar',
      '/fallos/repasar?tema=3': 'No hay fallos que repasar',
      // A mock that does not exist has no failures to review.
      '/simulacro/9999/repasar': 'No hay fallos que repasar',
    };
    for (final entry in cardTitles.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(location(router), entry.key);
      expect(find.byType(AppBar), findsNothing, reason: entry.key);
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('a bad tema or id goes back to /', (tester) async {
    final router = await pumpRouter(tester);
    for (final bad in [
      '/tema/0',
      '/tema/8',
      '/tema/x',
      '/simulacro/abc',
      '/simulacro/-1',
      '/simulacro/abc/repasar',
      '/simulacro/-1/repasar',
    ]) {
      router.go(bad);
      await tester.pumpAndSettle();
      expect(location(router), '/', reason: bad);
    }
    // A bad tema filter in /fallos/repasar is ignored (every mistake).
    router.go('/fallos/repasar?tema=99');
    await tester.pumpAndSettle();
    expect(find.text('No hay fallos que repasar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// Two finished mocks on the phone (what a refunded purchase leaves): ids 1
  /// (the first one made here, so the free one) and 2. Real exams (20
  /// questions in the manifest's split), like the app generates them.
  Future<void> seedTwoMocks() async {
    final db = container.read(appDatabaseProvider);
    final bank = await container.read(questionsProvider.future);
    for (final day in [0, 1]) {
      final exam = generateMock(
        questions: bank,
        config: MockConfig(),
        rng: Random(day + 1),
      );
      final id = await db.mocksDao.create(
        questionIds: [for (final q in exam) q.id],
        timed: false,
        startedAt: DateTime(2026, 10, 10 + day),
      );
      await db.mocksDao.finish(
        id,
        answers: List<int?>.filled(20, null),
        correctCount: 0,
        passed: false,
        passMark: 16,
        finishedAt: DateTime(2026, 10, 10 + day, 1),
      );
    }
  }

  testWidgets('a user opens every mock', (tester) async {
    final router = await pumpRouter(tester);
    await seedTwoMocks();
    router.go('/simulacro/2/resultado');
    await tester.pumpAndSettle();
    expect(location(router), '/simulacro/2/resultado');
    // Where each one ends up, exactly: the review of a question reached by
    // hand hands over to the result; the failures review stays put.
    for (final (open, lands) in [
      ('/simulacro/2/revision/0', '/simulacro/2/resultado'),
      ('/simulacro/2/repasar', '/simulacro/2/repasar'),
    ]) {
      router.go(open);
      await tester.pumpAndSettle();
      expect(location(router), lands, reason: open);
    }
  });

  testWidgets('/teoria builds its screen (empty state without theory)', (
    tester,
  ) async {
    final router = await pumpRouter(
      tester,
      bundle: theoryBundle(includeManifestField: false, includeAsset: false),
    );
    router.go('/teoria');
    await tester.pumpAndSettle();
    expect(location(router), '/teoria');
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Teoría')),
      findsOneWidget,
    );
    expect(find.text('La teoría no está disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/teoria/:id opens valid documents and rejects bad ids', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    for (final open in [
      for (var tema = 1; tema <= 7; tema++) 't$tema',
      'practica',
      'aem',
      'glosario',
    ]) {
      router.go('/teoria/$open');
      await tester.pumpAndSettle();
      expect(location(router), '/teoria/$open');
    }
    for (final bad in ['t0', 't8', 'abc']) {
      router.go('/teoria/$bad');
      await tester.pumpAndSettle();
      expect(location(router), '/teoria', reason: bad);
    }
    expect(tester.takeException(), isNull);
  });

  test('createRouter honours the initial location', () {
    final router = createRouter(initialLocation: '/');
    addTearDown(router.dispose);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });
}
