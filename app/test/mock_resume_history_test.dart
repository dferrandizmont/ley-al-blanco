import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/format/app_date_format.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'mock_flow_test.dart' show submittedMock;
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

/// Starts a mock through the service, answers the first [right] right and the
/// next [wrong] wrong (the rest blank), hands it in and returns its id.
Future<int> _finishedMock(
  ProviderContainer container, {
  int right = 20,
  int wrong = 0,
}) async {
  final service = container.read(mockServiceProvider);
  final started = await service.startMock(timed: false, rng: Random(3));
  await service.finishMock(
    started.id,
    submittedMock(started, right: right, wrong: wrong),
  );
  return started.id;
}

/// A finished mock that is **not the free one**, as far as the access rules
/// can tell: written straight to the table (through the repository and the
/// DAO, not through an import) after the device's own free mock stamped the
/// fingerprint, so its content does not hash to it. That is all an imported
/// mock is to the rules; the real import (which replaces the whole progress)
/// is covered in `free_mock_hardening_test.dart`.

/// The whole app over an existing [db], so a second call is a "new process"
/// over the same data.
Future<void> _pumpOver(WidgetTester tester, AppDatabase db) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => kTestNow),
        ...databaseTestOverrides(database: db),
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Inicio -> Simulacro -> Empezar. Returns the id of the mock now on screen.
Future<int> _startFromHome(WidgetTester tester) async {
  await _tap(tester, find.text('Simulacro'));
  await _tap(tester, find.text('Empezar'));
  final match = RegExp(r'^/simulacro/(\d+)$').firstMatch(locationOf(tester));
  expect(match, isNotNull, reason: 'on the running mock');
  return int.parse(match!.group(1)!);
}

/// Back, then "Salir": leaves the mock open and lands on Inicio.
Future<void> _leaveMock(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(
    find.textContaining('Podrás retomarlo desde Simulacro'),
    findsOneWidget,
  );
  await tester.tap(find.text('Salir'));
  await tester.pumpAndSettle();
  expect(locationOf(tester), '/');
}

/// The rows ("12. Enunciado...") of the question list of the result.
Finder _questionRows() => find.byWidgetPredicate(
  (w) => w is Text && RegExp(r'^\d+\. ').hasMatch(w.data ?? ''),
);

Set<int> _rowNumbers(WidgetTester tester) => {
  for (final text in tester.widgetList<Text>(_questionRows()))
    int.parse(RegExp(r'^(\d+)\. ').firstMatch(text.data!)!.group(1)!),
};

bool _enabled(WidgetTester tester, String label) =>
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
        .onPressed !=
    null;

void main() {
  group('data: the mock left open', () {
    test('latestUnfinished: none, the open one, none once handed in', () async {
      final c = makeStudyContainer();
      final repository = c.read(mockRepositoryProvider);
      expect(await repository.latestUnfinished(), isNull);

      final started = await c.read(mockServiceProvider).startMock(timed: true);
      final open = await repository.latestUnfinished();
      expect(open!.id, started.id);
      expect(open.timed, isTrue);
      expect(open.isFinished, isFalse);
      expect(open.answers, everyElement(isNull));

      await c
          .read(mockServiceProvider)
          .finishMock(started.id, submittedMock(started, right: 18, wrong: 2));
      expect(await repository.latestUnfinished(), isNull);
    });

    test('starting another with replaceUnfinishedId replaces only that '
        'mock', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);
      final repository = c.read(mockRepositoryProvider);
      final finished = await _finishedMock(c);
      final first = await service.startMock(timed: false);
      // Without an id a second open mock can exist (installs from before
      // the resume screen have them); the latest is the one to resume.
      final second = await service.startMock(timed: false);
      expect((await repository.latestUnfinished())!.id, second.id);

      final third = await service.startMock(
        timed: false,
        replaceUnfinishedId: second.id,
      );
      expect((await repository.latestUnfinished())!.id, third.id);
      expect(await repository.byId(second.id), isNull, reason: 'the named one');
      // Nothing else is deleted: not an older open mock the user was never
      // shown, and never a finished one.
      expect(await repository.byId(first.id), isNotNull);
      expect((await repository.byId(finished))!.isFinished, isTrue);
      expect(await repository.startedCount(), 3);

      // A finished mock named by mistake is not deleted either.
      await service.startMock(timed: false, replaceUnfinishedId: finished);
      expect((await repository.byId(finished))!.isFinished, isTrue);
    });

    test('a "new process" over the same database finds the open mock with '
        'its answers', () async {
      final db = openTestDatabase();
      addTearDown(db.close);

      final first = makeStudyContainer(database: db);
      final started = await first
          .read(mockServiceProvider)
          .startMock(timed: false);
      final provider = mockControllerProvider(started.id);
      first.listen(provider, (previous, next) {});
      await first.read(provider.future);
      final controller = first.read(provider.notifier)
        ..select(started.questions[0].answer)
        ..next()
        ..select(1)
        ..goTo(7)
        ..select(2);
      await controller.pendingSaves;
      first.dispose(); // the process dies; nothing was handed in

      final second = makeStudyContainer(database: db);
      second.listen(unfinishedMockProvider, (previous, next) {});
      final open = (await second.read(unfinishedMockProvider.future))!;
      expect(open.id, started.id);
      expect(open.answers[0], started.questions[0].answer);
      expect(open.answers[1], 1);
      expect(open.answers[7], 2);
      expect(open.answers.where((a) => a != null), hasLength(3));
      // The controller rebuilds the mock as it was left, not submitted.
      final state = await second.read(
        mockControllerProvider(started.id).future,
      );
      expect(state.isSubmitted, isFalse);
      expect(state.session.answers, open.answers);
      expect(state.session.questions.map((q) => q.id), open.questionIds);
      // And it is still the one mock started.
      expect(await second.read(mockRepositoryProvider).startedCount(), 1);
    });
  });

  group('screens: resume', () {
    testScreen('leaving the exam keeps it open: Inicio and Simulacro offer '
        '"Continuar simulacro" with the answers as they were', (tester) async {
      await pumpFullApp(tester);
      final id = await _startFromHome(tester);
      await tapOption(tester, 1);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tapOption(tester, 2);
      await containerOf(tester)
          .read(mockControllerProvider(id).notifier)
          .pendingSaves;

      await _leaveMock(tester);
      // Inicio: the tile says there is one, and it is not locked.
      expect(find.text('Tienes uno sin entregar'), findsOneWidget);

      await _tap(tester, find.text('Simulacro'));
      expect(locationOf(tester), '/simulacro');
      expect(find.text('Tienes un simulacro sin entregar'), findsOneWidget);
      expect(find.text('2 de 20 respondidas'), findsOneWidget);
      // One primary action: "Continuar simulacro"; starting another is the
      // secondary one.
      expect(
        find.widgetWithText(FilledButton, 'Continuar simulacro'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Empezar otro'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Continuar simulacro'));
      expect(locationOf(tester), '/simulacro/$id');
      expect(find.text('1 / 20'), findsOneWidget);
      expect(optionStates(tester)[1], OptionState.selected);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(optionStates(tester)[2], OptionState.selected);
      // Nothing new was started.
      expect(
        await containerOf(tester).read(mockRepositoryProvider).startedCount(),
        1,
      );
    });

    testWidgets('after the process dies the open mock is still there', (
      tester,
    ) async {
      final db = openTestDatabase();
      try {
        await _pumpOver(tester, db);
        final id = await _startFromHome(tester);
        await tapOption(tester, 0);
        await containerOf(tester)
            .read(mockControllerProvider(id).notifier)
            .pendingSaves;
        // Android kills the app in the background: no "Salir", no dialog.
        await unmountApp(tester);

        await _pumpOver(tester, db);
        expect(find.text('Tienes uno sin entregar'), findsOneWidget);
        await _tap(tester, find.text('Simulacro'));
        expect(find.text('1 de 20 respondidas'), findsOneWidget);
        await _tap(tester, find.text('Continuar simulacro'));
        expect(locationOf(tester), '/simulacro/$id');
        expect(optionStates(tester)[0], OptionState.selected);
      } finally {
        await unmountApp(tester);
        await db.close();
      }
    });

    testScreen('"Empezar otro" asks first and then replaces the open mock', (
      tester,
    ) async {
      await pumpFullApp(tester);
      final first = await _startFromHome(tester);
      await _leaveMock(tester);
      await _tap(tester, find.text('Simulacro'));

      // Cancel: nothing changes.
      await _tap(tester, find.text('Empezar otro'));
      expect(find.text('¿Empezar otro simulacro?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/simulacro');
      final repository = containerOf(tester).read(mockRepositoryProvider);
      expect((await repository.latestUnfinished())!.id, first);

      // Confirm: a new mock, the old one is gone, a single one stays open.
      await _tap(tester, find.text('Empezar otro'));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Empezar otro'),
        ),
      );
      await tester.pumpAndSettle();
      final match = RegExp(r'^/simulacro/(\d+)$')
          .firstMatch(locationOf(tester));
      final second = int.parse(match!.group(1)!);
      expect(second, isNot(first));
      expect((await repository.latestUnfinished())!.id, second);
      expect(await repository.byId(first), isNull);
    });
  });

  group('screens: Tus simulacros and the review', () {
    testScreen('semantic taps open history results and question reviews', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpFullApp(tester);
        final id = await _finishedMock(
          containerOf(tester),
          right: 12,
          wrong: 8,
        );
        await openRoute(tester, '/simulacro');

        await tester.ensureVisible(find.text('12 de 20'));
        await tester.pumpAndSettle();
        final historyNode = tester.getSemantics(
          find.bySemanticsLabel(RegExp(r'^Simulacro del ')),
        );
        expect(
          historyNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        historyNode.owner!.performAction(historyNode.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(locationOf(tester), '/simulacro/$id/resultado');

        await tester.ensureVisible(find.textContaining('13. ').first);
        await tester.pumpAndSettle();
        final questionNode = tester.getSemantics(
          find.bySemanticsLabel(RegExp(r'^13\. ')),
        );
        expect(
          questionNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        questionNode.owner!.performAction(questionNode.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(locationOf(tester), '/simulacro/$id/revision/12?falladas=1');
        expect(find.text('Pregunta 13 de 20'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testScreen('review follows a new index on the same route', (tester) async {
      await pumpFullApp(tester);
      final id = await _finishedMock(containerOf(tester));
      // The exam route of a mock already handed in hands over to its result.
      await openRoute(tester, '/simulacro/$id');
      expect(locationOf(tester), '/simulacro/$id/resultado');
      await openRoute(tester, '/simulacro/$id/revision/0');
      expect(find.text('Pregunta 1 de 20'), findsOneWidget);
      await _tap(tester, find.text('Siguiente'));
      expect(find.text('Pregunta 2 de 20'), findsOneWidget);

      // go_router reuses the review page for another parameter on that route.
      await openRoute(tester, '/simulacro/$id/revision/7');
      expect(locationOf(tester), '/simulacro/$id/revision/7');
      expect(find.text('Pregunta 8 de 20'), findsOneWidget);
    });

    testScreen('full: the finished mocks are listed and each opens its '
        'result', (tester) async {
      await pumpFullApp(tester);
      final c = containerOf(tester);
      final passed = await _finishedMock(c, right: 17, wrong: 3);
      final failed = await _finishedMock(c, right: 12, wrong: 8);
      await openRoute(tester, '/simulacro');

      expect(find.text('TUS SIMULACROS'), findsOneWidget);
      expect(find.text('17 de 20'), findsOneWidget);
      expect(find.text('12 de 20'), findsOneWidget);
      expect(find.text('APTO'), findsOneWidget);
      expect(find.text('NO APTO'), findsOneWidget);
      expect(find.text('15 oct 2026 · 18:30'), findsNWidgets(2));

      await _tap(tester, find.text('12 de 20'));
      expect(locationOf(tester), '/simulacro/$failed/resultado');
      expect(find.text('NO APTO'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // the ring
      // Close goes back to the list, not to Inicio.
      await tester.tap(find.byTooltip('Volver al inicio'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/simulacro');
      await _tap(tester, find.text('17 de 20'));
      expect(locationOf(tester), '/simulacro/$passed/resultado');
    });

    testScreen('no finished mock: heading and empty message', (tester) async {
      await pumpFullApp(tester);
      await openRoute(tester, '/simulacro');
      expect(find.text('TUS SIMULACROS'), findsOneWidget);
      expect(find.text('Aún no has entregado ninguno.'), findsOneWidget);
    });

    testScreen('history shows distinct local times at 320 dp and x2', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      var now = DateTime.utc(2026, 10, 15, 10, 5);
      await pumpFullApp(tester, clock: () => now);
      final first = now.toLocal();
      await _finishedMock(containerOf(tester), right: 17, wrong: 3);
      now = now.add(const Duration(minutes: 37));
      final second = now.toLocal();
      await _finishedMock(containerOf(tester), right: 12, wrong: 8);
      await openRoute(tester, '/simulacro');
      const format = AppDateFormat();
      for (final local in [first, second]) {
        final date = find.text(
          '${format.dayMonthYear(local)} · ${format.time(local)}',
        );
        expect(date, findsOneWidget);
        await tester.ensureVisible(date);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final firstDate = find.text(
        '${format.dayMonthYear(first)} · ${format.time(first)}',
      );
      final secondDate = find.text(
        '${format.dayMonthYear(second)} · ${format.time(second)}',
      );
      expect(
        tester.getTopLeft(secondDate).dy,
        lessThan(tester.getTopLeft(firstDate).dy),
      );
      expect(find.text('Aún no has entregado ninguno.'), findsNothing);
    });

    testScreen('the date and the hour of a mock stay on one line at 320 dp '
        'and x2', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFullApp(tester);
      await _finishedMock(containerOf(tester), right: 17, wrong: 3);
      await openRoute(tester, '/simulacro');

      // The date and the hour, with the dot that joins them.
      final date = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('·'),
      );
      expect(date, findsOneWidget);
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final text = tester.widget<Text>(date).data!;
      final paragraph = tester.renderObject<RenderParagraph>(date);
      // The whole of it is on one line: neither the date nor the hour is
      // split in the middle.
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      expect(boxes, hasLength(1), reason: 'the date is split');
      for (final word in RegExp(r'\S+').allMatches(text)) {
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          ),
          hasLength(1),
          reason: '"${word.group(0)}" is split',
        );
      }
      // The verdict and the score are on the row too, and nothing overflows.
      expect(find.text('17 de 20'), findsOneWidget);
      expect(find.text('APTO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testScreen('the history keeps the verdict on the same row at 390 dp and '
        'x1', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpFullApp(tester);
      await _finishedMock(containerOf(tester), right: 17, wrong: 3);
      await _finishedMock(containerOf(tester), right: 12, wrong: 8);
      await openRoute(tester, '/simulacro');

      const date = '15 oct 2026 · 18:30';
      for (final (verdict, score) in [
        ('APTO', '17 de 20'),
        ('NO APTO', '12 de 20'),
      ]) {
        expect(find.text(verdict), findsOneWidget, reason: verdict);
        expect(find.text(score), findsOneWidget, reason: score);
        // The verdict is at the right of the date, on the same row: it is
        // above the score, which is on the second line of the row.
        expect(
          tester.getCenter(find.text(verdict)).dy,
          lessThan(tester.getCenter(find.text(score)).dy),
          reason: '$verdict is not on the same row as the date',
        );
      }
      expect(find.text(date), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testScreen('the NO APTO row is reorganized at 320 dp and x2, without '
        'splitting any word', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFullApp(tester);
      await _finishedMock(containerOf(tester), right: 12, wrong: 8);
      await openRoute(tester, '/simulacro');

      final verdict = find.text('NO APTO');
      final score = find.text('12 de 20');
      const date = '15 oct 2026 · 18:30';
      expect(verdict, findsOneWidget);
      expect(score, findsOneWidget);
      await tester.ensureVisible(verdict);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The row was reorganized: the verdict is under the date.
      expect(
        tester.getTopLeft(verdict).dy,
        greaterThan(tester.getBottomLeft(find.text(date)).dy),
      );
      // The score and the verdict are whole, and no word is split.
      for (final (finder, text) in [
        (verdict, 'NO APTO'),
        (score, '12 de 20'),
        (find.text(date), date),
      ]) {
        expectWordsNotSplit(tester, finder, text);
        expectWordsInside(tester, finder, text);
      }
    });

    testScreen('result: the 20 questions with "Solo falladas" on by default, '
        'and Anterior / Siguiente through them in the review', (tester) async {
      await pumpFullApp(tester);
      final id = await _finishedMock(containerOf(tester), right: 15, wrong: 4);
      // 15 right, 4 wrong, 1 blank: questions 16..20 are the failed ones.
      await pushRoute(tester, '/simulacro/$id/resultado');

      final chip = find.widgetWithText(FilterChip, 'Solo falladas');
      expect(tester.widget<FilterChip>(chip).selected, isTrue);
      expect(_rowNumbers(tester), {16, 17, 18, 19, 20});
      // Five failed rows plus the close button of the header.
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(5 + 1));

      // Off: all twenty, the right ones with a check (not only colour).
      await _tap(tester, chip);
      expect(tester.widget<FilterChip>(chip).selected, isFalse);
      expect(_rowNumbers(tester), {for (var i = 1; i <= 20; i++) i});
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(15));
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(5 + 1));

      // A right question opens its review; the walk covers all twenty.
      await _tap(tester, find.textContaining('3. ').first);
      expect(locationOf(tester), '/simulacro/$id/revision/2');
      expect(find.text('Pregunta 3 de 20'), findsOneWidget);
      expect(find.text('Correcto'), findsOneWidget);
      await _tap(tester, find.text('Siguiente'));
      expect(find.text('Pregunta 4 de 20'), findsOneWidget);
      await _tap(tester, find.text('Anterior'));
      await _tap(tester, find.text('Anterior'));
      expect(find.text('Pregunta 2 de 20'), findsOneWidget);
      await _tap(tester, find.text('Anterior'));
      expect(find.text('Pregunta 1 de 20'), findsOneWidget);
      expect(_enabled(tester, 'Anterior'), isFalse);
      expect(_enabled(tester, 'Siguiente'), isTrue);

      // Back to the result: the filter turned on again and the review walks
      // only the failed ones.
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      await _tap(tester, chip);
      expect(_rowNumbers(tester), {16, 17, 18, 19, 20});
      await _tap(tester, find.textContaining('16. ').first);
      expect(locationOf(tester), '/simulacro/$id/revision/15?falladas=1');
      expect(find.text('Pregunta 16 de 20'), findsOneWidget);
      expect(_enabled(tester, 'Anterior'), isFalse);
      await _tap(tester, find.text('Siguiente'));
      expect(find.text('Pregunta 17 de 20'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await _tap(tester, find.text('Siguiente'));
      }
      expect(find.text('Pregunta 20 de 20'), findsOneWidget);
      expect(_enabled(tester, 'Siguiente'), isFalse);
      expect(find.text('Sin responder'), findsOneWidget); // the blank one
    });

    testScreen('result: with no failures the filter says so and the other '
        'state shows all twenty', (tester) async {
      await pumpFullApp(tester);
      final id = await _finishedMock(containerOf(tester));
      await pushRoute(tester, '/simulacro/$id/resultado');
      expect(find.text('No has fallado ninguna pregunta.'), findsOneWidget);
      expect(_rowNumbers(tester), isEmpty);
      await _tap(tester, find.widgetWithText(FilterChip, 'Solo falladas'));
      expect(_rowNumbers(tester), {for (var i = 1; i <= 20; i++) i});
      expect(find.byIcon(Icons.close_rounded), findsOneWidget); // header only
    });
  });
}
