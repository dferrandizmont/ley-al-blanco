import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/domain/mock_result.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/mock_support.dart';
import 'support/screen_support.dart';

/// Simulacro -> Empezar. Returns the mock id.
Future<int> _startMock(WidgetTester tester) async {
  await pushRoute(tester, '/simulacro');
  await tester.tap(find.text('Empezar'));
  await tester.pumpAndSettle();
  final match = RegExp(r'^/simulacro/(\d+)$').firstMatch(locationOf(tester));
  expect(match, isNotNull, reason: 'now on the running mock');
  return int.parse(match!.group(1)!);
}

/// Entregar -> confirm, without waiting for the hand-in to finish (the
/// button shows a spinner that never settles).
Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Entregar'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('hand-in in flight', () {
    testScreen('system back does nothing and the result shows afterwards', (
      tester,
    ) async {
      late GatedMockService gated;
      await pumpFullApp(
        tester,
        overrides: [
          mockServiceProvider.overrideWith(
            (ref) => gated = GatedMockService(realMockService(ref)),
          ),
        ],
      );
      final id = await _startMock(tester);
      final question = containerOf(tester)
          .read(mockControllerProvider(id))
          .requireValue
          .session
          .currentQuestion;
      await tapOption(tester, question.answer);

      await _tapSubmit(tester);
      expect(gated.finishCalls, 1);
      expect(
        containerOf(tester).read(mockControllerProvider(id)).value!.submitting,
        isTrue,
      );

      // System back (and the predictive-back gesture) is ignored: no "Salir"
      // dialog, still on the exam.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('¿Salir del simulacro?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(locationOf(tester), '/simulacro/$id');

      // The close button is disabled too.
      final close = find.byTooltip('Cerrar');
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AlertDialog), findsNothing);

      // The transaction completes: the result is shown, the mock is stored.
      gated.gate.complete();
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/simulacro/$id/resultado');
      expect(find.text('NO APTO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final record = (await containerOf(tester)
          .read(mockRepositoryProvider)
          .byId(id))!;
      expect(record.isFinished, isTrue);
      expect(record.correct, 1);
      expect(record.passMark, 16);
      expect(
        await containerOf(tester).read(attemptRepositoryProvider).all(),
        hasLength(20),
      );
    });

    testScreen('back works again once the hand-in fails', (tester) async {
      late GatedMockService gated;
      await pumpFullApp(
        tester,
        overrides: [
          mockServiceProvider.overrideWith(
            (ref) => gated = GatedMockService(realMockService(ref)),
          ),
        ],
      );
      final id = await _startMock(tester);
      gated.failure = StateError('disk full');
      await _tapSubmit(tester);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AlertDialog), findsNothing);

      gated.gate.complete();
      await tester.pumpAndSettle();
      // A real failure: the generic notice, the exam stays open.
      expect(
        find.text('No se ha podido guardar tu respuesta. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(locationOf(tester), '/simulacro/$id');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir del simulacro?'), findsOneWidget);
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
    });
  });

  testScreen('an already finished mock goes to its result, no error', (
    tester,
  ) async {
    late GatedMockService gated;
    await pumpFullApp(
      tester,
      overrides: [
        mockServiceProvider.overrideWith(
          (ref) => gated = GatedMockService(realMockService(ref)),
        ),
      ],
    );
    final id = await _startMock(tester);
    gated.gate.complete();
    // The mock gets handed in behind the screen's back (e.g. an earlier
    // attempt whose answer was lost).
    final c = containerOf(tester);
    final session = c.read(mockControllerProvider(id)).value!.session.submit();
    await c.read(mockServiceProvider).finishMock(id, session);
    expect(session.mode, AttemptMode.mock);

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(locationOf(tester), '/simulacro/$id/resultado');
    expect(find.textContaining('No se ha podido guardar'), findsNothing);
    expect(find.text('NO APTO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testScreen(
    'the result of an old mock keeps its stored verdict and pass mark',
    (tester) async {
      await pumpFullApp(tester);
      // Handed in when the pass mark was 10: 12 right is APTO, whatever the
      // current exam config (16) says.
      final c = containerOf(tester);
      final started = await c.read(mockServiceProvider).startMock(timed: false);
      final answers = <int?>[
        for (var i = 0; i < started.questions.length; i++)
          i < 12 ? started.questions[i].answer : null,
      ];
      await c
          .read(mockRepositoryProvider)
          .finish(
            started.id,
            const MockResult(
              correct: 12,
              wrong: 8,
              unanswered: 8,
              passed: true,
              passMark: 10,
              perTema: {},
            ),
            answers,
            kTestNow,
          );

      await pushRoute(tester, '/simulacro/${started.id}/resultado');

      expect(find.text('APTO'), findsOneWidget);
      expect(find.text('NO APTO'), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect(
        find.text('La marca indica el aprobado: 10 aciertos.'),
        findsOneWidget,
      );
    },
  );
}
