import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/scroll_edge_fade.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mistakes/application/mistakes_providers.dart';
import 'package:apto_armas/features/mistakes/presentation/mistake_sheet.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

/// Plays a whole mock through the controller (no UI) and hands it in: every
/// question right except those in [missIndices].
Future<List<Question>> _playMock(
  ProviderContainer container, {
  required Set<int> missIndices,
}) async {
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false);
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < started.questions.length; i++) {
    controller.goTo(i);
    final q = started.questions[i];
    controller.select(missIndices.contains(i) ? wrongOption(q) : q.answer);
  }
  await controller.submit();
  return started.questions;
}

/// Scrolls the sheet to [label] and taps it.
Future<void> _tapInSheet(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Opens the ficha of [stem]'s row and taps "Practicar esta pregunta".
Future<void> _practiceFromSheet(WidgetTester tester, String stem) async {
  await tester.tap(find.text(stem));
  await tester.pumpAndSettle();
  await _tapInSheet(tester, 'Practicar esta pregunta');
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testScreen('no mistakes: empty state and a disabled "Repasar todos"', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/fallos');
    expect(find.text('No tienes fallos pendientes'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    for (var tema = 1; tema <= 7; tema++) {
      expect(find.text('Tema $tema'), findsOneWidget);
    }
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Repasar todos'),
    );
    expect(button.onPressed, isNull);
  });

  testScreen('filter chips: >= 44 dp touch target, no shadow wrapper', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/fallos');
    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(8));
    for (var i = 0; i < 8; i++) {
      final size = tester.getSize(chips.at(i));
      expect(size.height, greaterThanOrEqualTo(44), reason: 'chip $i');
      expect(size.width, greaterThanOrEqualTo(44), reason: 'chip $i');
    }
    // The look comes from the theme: no hand-made box around the chip.
    expect(
      find.ancestor(
        of: chips.first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).boxShadow != null,
        ),
      ),
      findsNothing,
    );
  });

  testScreen('the list scrolls clear of the floating "Repasar todos"', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await _playMock(
      containerOf(tester),
      missIndices: {for (var i = 0; i < 12; i++) i},
    );
    await tester.pumpAndSettle();
    await pushRoute(tester, '/fallos');

    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(ScrollEdgeFade),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(
      scroll.padding!.resolve(TextDirection.ltr).bottom,
      Sp.floatingClearance,
    );
    final pill = tester.getRect(
      find.widgetWithText(FilledButton, 'Repasar todos'),
    );
    final screen = tester.getRect(find.byType(Scaffold));
    expect(pill.height, 56);
    expect(screen.bottom - pill.bottom, Sp.floatingMargin);
  });

  testScreen('a mock miss shows up, with tema, stem and wrong count', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final questions = await _playMock(containerOf(tester), missIndices: {3});
    await tester.pumpAndSettle();
    final missed = questions[3];

    await pushRoute(tester, '/fallos');
    expect(find.text(missed.stem), findsOneWidget);
    expect(find.text('Tema ${missed.tema}'), findsNWidgets(2)); // chip + row
    expect(find.text('Fallada 1 vez'), findsOneWidget);
    expect(find.text('No tienes fallos pendientes'), findsNothing);
  });

  testScreen('tema filter narrows the list', (tester) async {
    await pumpFullApp(tester);
    final questions = await _playMock(
      containerOf(tester),
      missIndices: {0, 19},
    );
    await tester.pumpAndSettle();
    final first = questions[0]; // lowest tema of the mock
    final last = questions[19]; // highest tema of the mock
    expect(first.tema, isNot(last.tema));

    await pushRoute(tester, '/fallos');
    expect(find.text(first.stem), findsOneWidget);
    expect(find.text(last.stem), findsOneWidget);

    await _tapChip(tester, 'Tema ${last.tema}');
    await tester.pumpAndSettle();
    expect(find.text(last.stem), findsOneWidget);
    expect(find.text(first.stem), findsNothing);

    // A tema without mistakes: empty state; "Todos" brings everything back.
    final other = [for (var t = 1; t <= 7; t++) t]
        .firstWhere((t) => t != first.tema && t != last.tema);
    await _tapChip(tester, 'Tema $other');
    await tester.pumpAndSettle();
    expect(find.text('No tienes fallos pendientes'), findsOneWidget);
    await _tapChip(tester, 'Todos');
    await tester.pumpAndSettle();
    expect(find.text(first.stem), findsOneWidget);
    expect(find.text(last.stem), findsOneWidget);
  });

  testScreen('"Repasar todos" reviews the list; two right in a row clear it', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final c = containerOf(tester);
    final questions = await _playMock(c, missIndices: {5});
    await tester.pumpAndSettle();
    final missed = questions[5];

    await pushRoute(tester, '/fallos');
    await tester.tap(find.text('Repasar todos'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/fallos/repasar');
    expect(find.text('REPASAR FALLOS'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text(missed.stem), findsOneWidget);

    // First right answer: it is still in the list (needs two in a row).
    await tapOption(tester, missed.answer);
    await tapNext(tester, label: 'Terminar');
    expect(find.text('Sesión terminada'), findsOneWidget);
    routerOf(tester).pop(); // back to Fallos
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/fallos');
    expect(find.text(missed.stem), findsOneWidget);
    expect(c.read(mistakesProvider(null)).requireValue.single.currentStreak, 1);

    // Second right answer in a second review: gone.
    await tester.tap(find.text('Repasar todos'));
    await tester.pumpAndSettle();
    await tapOption(tester, missed.answer);
    await tapNext(tester, label: 'Terminar');
    routerOf(tester).pop();
    await tester.pumpAndSettle();
    expect(find.text(missed.stem), findsNothing);
    expect(find.text('No tienes fallos pendientes'), findsOneWidget);
  });

  testScreen('"Repasar todos" keeps the tema filter', (tester) async {
    await pumpFullApp(tester);
    final questions = await _playMock(
      containerOf(tester),
      missIndices: {0, 19},
    );
    await tester.pumpAndSettle();
    final last = questions[19];

    await pushRoute(tester, '/fallos');
    await _tapChip(tester, 'Tema ${last.tema}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repasar todos'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/fallos/repasar?tema=${last.tema}');
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text(last.stem), findsOneWidget);
    expect(find.byType(OptionCard), findsNWidgets(3));
  });

  testScreen('tapping a row opens the review starting at that question, and '
      'the earlier ones follow at the end', (tester) async {
    await pumpFullApp(tester);
    final questions = await _playMock(
      containerOf(tester),
      missIndices: {0, 9, 19},
    );
    await tester.pumpAndSettle();
    final first = questions[0];
    final middle = questions[9];
    final last = questions[19];

    await pushRoute(tester, '/fallos');
    // A row is a button for the screen reader, with a hint.
    final row = find.ancestor(
      of: find.text(middle.stem),
      matching: find.byType(InkWell),
    );
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(middle.stem))),
      findsOneWidget,
    );

    await _practiceFromSheet(tester, middle.stem);
    expect(locationOf(tester), '/fallos/repasar?desde=${middle.id}');
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text(middle.stem), findsOneWidget);

    // The review goes on with the rest and wraps to the first ones.
    await tapOption(tester, middle.answer);
    await tapNext(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text(last.stem), findsOneWidget);
    await tapOption(tester, last.answer);
    await tapNext(tester);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text(first.stem), findsOneWidget);
  });

  testScreen('a row tapped with a tema filter keeps the filter and starts '
      'there', (tester) async {
    await pumpFullApp(tester);
    final questions = await _playMock(
      containerOf(tester),
      missIndices: {0, 19},
    );
    await tester.pumpAndSettle();
    final last = questions[19];

    await pushRoute(tester, '/fallos');
    await _tapChip(tester, 'Tema ${last.tema}');
    await tester.pumpAndSettle();
    await _practiceFromSheet(tester, last.stem);
    expect(
      locationOf(tester),
      '/fallos/repasar?tema=${last.tema}&desde=${last.id}',
    );
    expect(find.text('1 / 1'), findsOneWidget);
  });

  group('ficha de fallo', () {
    Finder sheet() => find.byType(MistakeSheet);

    /// Records a wrong attempt on [q] picking [pick] (null = left blank).
    Future<void> fail(WidgetTester tester, Question q, {int? pick}) async {
      await containerOf(tester).read(studyServiceProvider).recordAnswers([
        Attempt(
          questionId: q.id,
          mode: AttemptMode.practice,
          selected: pick,
          correct: false,
          answeredAt: kTestNow.subtract(const Duration(days: 1)),
        ),
      ]);
      await tester.pumpAndSettle();
    }

    Future<Question> firstOfTema(WidgetTester tester, int tema) async =>
        (await bankOf(tester)).firstWhere((q) => q.tema == tema);

    Future<void> openSheet(WidgetTester tester, Question q) async {
      await pushRoute(tester, '/fallos');
      await tester.tap(find.text(q.stem));
      await tester.pumpAndSettle();
    }

    testScreen('tapping a row opens the ficha instead of the review', (
      tester,
    ) async {
      await pumpFullApp(tester);
      final q = await firstOfTema(tester, 2);
      final picked = wrongOption(q);
      await fail(tester, q, pick: picked);
      await openSheet(tester, q);

      expect(locationOf(tester), '/fallos');
      expect(sheet(), findsOneWidget);
      expect(
        find.descendant(of: sheet(), matching: find.text(q.stem)),
        findsOneWidget,
      );
      expect(find.byType(OptionCard), findsNWidgets(3));
      expect(
        find.text('Tu última respuesta: ${String.fromCharCode(65 + picked)}'),
        findsOneWidget,
      );
      // Right option: check icon; wrong pick: cross icon (not only colour).
      expect(
        find.descendant(
          of: sheet(),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'Correcta$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Incorrecta$')), findsOneWidget);
      expect(find.text('Practicar esta pregunta'), findsOneWidget);
      expect(find.text('Ver la teoría del tema 2'), findsOneWidget);
      for (final label in [
        'Practicar esta pregunta',
        'Ver la teoría del tema 2',
      ]) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
    });

    testScreen('"Practicar esta pregunta" starts the review from it, '
        'keeping the tema filter', (tester) async {
      await pumpFullApp(tester);
      final q = await firstOfTema(tester, 3);
      await fail(tester, q, pick: wrongOption(q));
      await pushRoute(tester, '/fallos');
      await _tapChip(tester, 'Tema 3');
      await _practiceFromSheet(tester, q.stem);
      expect(sheet(), findsNothing);
      expect(locationOf(tester), '/fallos/repasar?tema=3&desde=${q.id}');
    });

    testScreen('"Ver la teoría" opens the tema summary', (tester) async {
      await pumpFullApp(tester);
      final q = await firstOfTema(tester, 2);
      await fail(tester, q, pick: wrongOption(q));
      await openSheet(tester, q);
      await _tapInSheet(tester, 'Ver la teoría del tema 2');
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(locationOf(tester), '/teoria/t2');
    });

    testScreen('a free user: theory of tema 1 opens', (tester) async {
      await pumpFullApp(tester);
      final q = await firstOfTema(tester, 1);
      await fail(tester, q, pick: wrongOption(q));
      await openSheet(tester, q);
      await _tapInSheet(tester, 'Ver la teoría del tema 1');
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/teoria/t1');
    });

    testScreen('a blank mock answer says "Sin responder"', (tester) async {
      await pumpFullApp(tester);
      final q = await firstOfTema(tester, 2);
      await fail(tester, q);
      await openSheet(tester, q);
      expect(find.text('Sin responder'), findsOneWidget);
      expect(find.textContaining('Tu última respuesta'), findsNothing);
    });

    testScreen('the close button dismisses the ficha', (tester) async {
      await pumpFullApp(tester);
      final q = await firstOfTema(tester, 2);
      await fail(tester, q, pick: wrongOption(q));
      await openSheet(tester, q);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(locationOf(tester), '/fallos');
    });

    for (final scale in [1.3, 2.0]) {
      testScreen('no overflow at 320 dp, text x$scale, longest question', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpFullApp(tester);
        int size(Question q) => q.stem.length + q.options.join().length;
        final q = ([
          ...await bankOf(tester),
        ]..sort((a, b) => size(b).compareTo(size(a)))).first;
        await fail(tester, q, pick: wrongOption(q));
        await openSheet(tester, q);
        expect(sheet(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.descendant(
            of: sheet(),
            matching: find.byType(SingleChildScrollView),
          ),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Practicar esta pregunta'), findsOneWidget);
      });
    }
  });

  testScreen('a "desde" that is not a question id, or not in the list, is '
      'ignored', (tester) async {
    await pumpFullApp(tester);
    final questions = await _playMock(containerOf(tester), missIndices: {4});
    await tester.pumpAndSettle();
    for (final bad in ['x', 't9-001', 't1-1', 't3-999']) {
      await openRoute(tester, '/fallos/repasar?desde=$bad');
      expect(find.text('1 / 1'), findsOneWidget, reason: bad);
      expect(find.text(questions[4].stem), findsOneWidget, reason: bad);
    }
  });
}
