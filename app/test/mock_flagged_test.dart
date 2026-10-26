import 'dart:math';

import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

/// «Marcar como dudosa» in the mock: the toggle, the map of questions, the
/// confirmation when handing in and, above all, that the marks are stored with
/// the mock and survive the process being killed.

Future<int> _startMock(ProviderContainer c) async {
  final started = await c
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  c.listen(mockControllerProvider(started.id), (previous, next) {});
  await c.read(mockControllerProvider(started.id).future);
  return started.id;
}

MockController _controller(ProviderContainer c, int id) =>
    c.read(mockControllerProvider(id).notifier);

MockState _state(ProviderContainer c, int id) =>
    c.read(mockControllerProvider(id)).requireValue;

/// Answers question [index] with its first option.
void _answer(ProviderContainer c, int id, int index) {
  _controller(c, id)
    ..goTo(index)
    ..select(0);
}

Future<void> _flag(ProviderContainer c, int id, Iterable<int> indices) async {
  for (final i in indices) {
    _controller(c, id)
      ..goTo(i)
      ..toggleFlag();
  }
}

void main() {
  group('controller', () {
    test(
      'toggling marks the current question and takes the mark off',
      () async {
        final c = makeStudyContainer();
        final id = await _startMock(c);
        expect(_state(c, id).flagged, isEmpty);
        expect(_state(c, id).flaggedCount, 0);

        _controller(c, id).toggleFlag();
        expect(_state(c, id).isFlagged(0), isTrue);
        expect(_state(c, id).isFlagged(1), isFalse);

        await _flag(c, id, [4, 9]);
        expect(_state(c, id).flaggedIndices, {0, 4, 9});
        expect(_state(c, id).flaggedCount, 3);

        _controller(c, id)
          ..goTo(4)
          ..toggleFlag();
        expect(_state(c, id).flaggedIndices, {0, 9});
      },
    );

    test('marking does not change the answers or where you are', () async {
      final c = makeStudyContainer();
      final id = await _startMock(c);
      _answer(c, id, 2);
      _controller(c, id)
        ..goTo(2)
        ..toggleFlag();
      final state = _state(c, id);
      expect(state.session.currentIndex, 2);
      expect(state.session.answeredCount, 1);
      expect(state.session.answers[2], 0);
      expect(state.unansweredCount, 19);
    });

    test('the marks are saved with the mock', () async {
      final c = makeStudyContainer();
      final id = await _startMock(c);
      await _flag(c, id, [3, 7]);
      await _controller(c, id).pendingSaves;

      final record = (await c.read(mockRepositoryProvider).byId(id))!;
      final ids = record.questionIds;
      expect(record.flagged, [ids[3], ids[7]]);

      _controller(c, id)
        ..goTo(3)
        ..toggleFlag();
      await _controller(c, id).pendingSaves;
      expect((await c.read(mockRepositoryProvider).byId(id))!.flagged, [
        ids[7],
      ]);
    });

    test('they survive the process being killed: a new run over the same '
        'database gets them back', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final first = makeStudyContainer(database: db);
      final id = await _startMock(first);
      _answer(first, id, 1);
      await _flag(first, id, [1, 12, 19]);
      await _controller(first, id).pendingSaves;
      final ids = _state(first, id).session.questions.map((q) => q.id).toList();
      first.dispose();

      final second = makeStudyContainer(database: db);
      second.listen(mockControllerProvider(id), (previous, next) {});
      final state = await second.read(mockControllerProvider(id).future);
      expect(state.flagged, {ids[1], ids[12], ids[19]});
      expect(state.flaggedIndices, {1, 12, 19});
      expect(state.session.answeredCount, 1);
      expect(state.isSubmitted, isFalse);
      // And it can go on from there.
      _controller(second, id)
        ..goTo(12)
        ..toggleFlag();
      await _controller(second, id).pendingSaves;
      expect((await second.read(mockRepositoryProvider).byId(id))!.flagged, [
        ids[1],
        ids[19],
      ]);
    });

    test('marks follow the question, not its position', () async {
      final c = makeStudyContainer();
      final id = await _startMock(c);
      await _flag(c, id, [5]);
      await _controller(c, id).pendingSaves;
      final stem = _state(c, id).session.questions[5].id;
      c.invalidate(mockControllerProvider(id));
      final reopened = await c.read(mockControllerProvider(id).future);
      expect(reopened.flagged, {stem});
      expect(reopened.session.questions[5].id, stem);
    });

    test('handing in keeps them and locks them', () async {
      final c = makeStudyContainer();
      final id = await _startMock(c);
      await _flag(c, id, [0, 1]);
      await _controller(c, id).submit();

      final before = _state(c, id).flagged;
      expect(before, hasLength(2));
      _controller(c, id)
        ..goTo(5)
        ..toggleFlag();
      expect(_state(c, id).flagged, before);
      final record = (await c.read(mockRepositoryProvider).byId(id))!;
      expect(record.isFinished, isTrue);
      expect(record.flagged, hasLength(2));
    });
  });

  group('screen', () {
    /// The mock on screen, from a started one.
    Future<(int, ProviderContainer)> open(WidgetTester tester) async {
      await pumpFullApp(tester);
      final container = containerOf(tester);
      final started = await container
          .read(mockServiceProvider)
          .startMock(timed: false, rng: Random(3));
      await pushRoute(tester, '/simulacro/${started.id}');
      return (started.id, container);
    }

    final toggle = find.byKey(const ValueKey('mock-flag-toggle'));

    testScreen('the toggle says what it does, is a toggle and is saved', (
      tester,
    ) async {
      final (id, container) = await open(tester);
      expect(find.text('Marcar como dudosa'), findsOneWidget);
      expect(find.text('Marcada como dudosa'), findsNothing);
      expect(find.byIcon(Icons.outlined_flag_rounded), findsOneWidget);
      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          label: 'Marcar como dudosa',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Marcada como dudosa'), findsOneWidget);
      // Never colour alone: the flag icon is filled and the label changes.
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.outlined_flag_rounded), findsNothing);
      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          label: 'Marcada como dudosa',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await _controller(container, id).pendingSaves;
      final saved = (await container.read(mockRepositoryProvider).byId(id))!;
      expect(saved.flagged, [saved.questionIds.first]);

      // The mark belongs to that question: the next one is not marked, and
      // going back finds it marked.
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar como dudosa'), findsOneWidget);
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Marcada como dudosa'), findsOneWidget);

      // Tap again: the mark goes.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Marcar como dudosa'), findsOneWidget);
      await _controller(container, id).pendingSaves;
      expect(
        (await container.read(mockRepositoryProvider).byId(id))!.flagged,
        isEmpty,
      );
    });

    testScreen('the toggle is a 48 dp target', (tester) async {
      await open(tester);
      final size = tester.getSize(toggle);
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testScreen('the map of questions shows answered, unanswered and doubtful '
        'with an icon each, and a legend', (tester) async {
      final (id, container) = await open(tester);
      _answer(container, id, 0);
      _answer(container, id, 1);
      await _flag(container, id, [1, 5]);
      _controller(container, id).goTo(0);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preguntas'));
      await tester.pumpAndSettle();

      final nav = tester.widget<MockNavigator>(find.byType(MockNavigator));
      expect(nav.answered, {0, 1});
      expect(nav.flagged, {1, 5});
      // One flag badge per doubtful cell, plus the one of the legend.
      expect(
        find.descendant(
          of: find.byType(MockNavigator),
          matching: find.byType(FlagBadge),
        ),
        findsNWidgets(2),
      );
      expect(find.byType(MockNavigatorLegend), findsOneWidget);
      expect(find.text('Respondida'), findsOneWidget);
      expect(find.text('Sin responder'), findsOneWidget);
      expect(find.text('Dudosa'), findsOneWidget);
      expect(find.text('2 dudosas · 18 sin responder'), findsOneWidget);

      // Each cell is spoken with its state.
      Finder cell(String label) => find.bySemanticsLabel(label);
      expect(cell('Pregunta 1, respondida'), findsOneWidget);
      expect(cell('Pregunta 2, respondida, dudosa'), findsOneWidget);
      expect(cell('Pregunta 3, sin responder'), findsOneWidget);
      expect(cell('Pregunta 6, sin responder, dudosa'), findsOneWidget);

      // Tapping a doubtful cell goes there.
      await tester.tap(
        find.descendant(
          of: find.byType(MockNavigator),
          matching: find.text('6'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('6 / 20'), findsOneWidget);
      expect(find.text('Marcada como dudosa'), findsOneWidget);
    });

    testScreen('the map says one doubtful and one blank in the singular', (
      tester,
    ) async {
      final (id, container) = await open(tester);
      for (var i = 0; i < 19; i++) {
        _answer(container, id, i);
      }
      await _flag(container, id, [3]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preguntas'));
      await tester.pumpAndSettle();
      expect(find.text('1 dudosa · 1 sin responder'), findsOneWidget);
    });

    Future<String> submitDialogBody(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Entregar el simulacro?'), findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                w.data != '¿Entregar el simulacro?' &&
                w.data != 'Seguir' &&
                w.data != 'Entregar',
          ),
        ),
      );
      return text.data!;
    }

    testScreen('Entregar warns about doubtful and unanswered questions', (
      tester,
    ) async {
      final (id, container) = await open(tester);
      await _flag(container, id, [2, 3, 4]);
      for (var i = 0; i < 12; i++) {
        _answer(container, id, i);
      }
      _controller(container, id).goTo(0);
      await tester.pumpAndSettle();
      expect(
        await submitDialogBody(tester),
        'Tienes 3 dudosas y 8 sin responder. '
        'Las preguntas sin responder contarán como fallo.',
      );
    });

    testScreen('Entregar with only unanswered questions is as it was', (
      tester,
    ) async {
      final (id, container) = await open(tester);
      for (var i = 0; i < 16; i++) {
        _answer(container, id, i);
      }
      _controller(container, id).goTo(0);
      await tester.pumpAndSettle();
      expect(
        await submitDialogBody(tester),
        'Te quedan 4 preguntas sin responder y contarán como fallo.',
      );
    });

    testScreen('Entregar with everything answered but some doubtful', (
      tester,
    ) async {
      final (id, container) = await open(tester);
      for (var i = 0; i < 20; i++) {
        _answer(container, id, i);
      }
      await _flag(container, id, [7]);
      await tester.pumpAndSettle();
      expect(
        await submitDialogBody(tester),
        'Tienes 1 pregunta dudosa. Puedes revisarla antes de entregar.',
      );
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();

      await _flag(container, id, [7]); // unmarked
      await tester.pumpAndSettle();
      expect(
        await submitDialogBody(tester),
        'Has respondido todas las preguntas.',
      );
    });

    testScreen('the marks are still there after leaving the exam and coming '
        'back to it', (tester) async {
      final (id, container) = await open(tester);
      await _flag(container, id, [0, 8]);
      await _controller(container, id).pendingSaves;

      routerOf(tester).go('/');
      await tester.pumpAndSettle();
      container.invalidate(mockControllerProvider(id));
      await pushRoute(tester, '/simulacro/$id');

      expect(find.text('Marcada como dudosa'), findsOneWidget);
      await tester.tap(find.text('Preguntas'));
      await tester.pumpAndSettle();
      expect(tester.widget<MockNavigator>(find.byType(MockNavigator)).flagged, {
        0,
        8,
      });
    });
  });

  test('MockRecord carries the marks and compares by them', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final c = makeStudyContainer(database: db);
    final id = await _startMock(c);
    final repo = c.read(mockRepositoryProvider);
    final before = (await repo.byId(id))!;
    expect(before.flagged, isEmpty);
    await repo.saveFlagged(id, [before.questionIds[4]]);
    final after = (await repo.byId(id))!;
    expect(after.flagged, [before.questionIds[4]]);
    expect(after, isNot(before));
  });
}
