import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/core/widgets/score_ring.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:apto_armas/features/progress/application/progress_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

const _temaTitles = [
  'Funcionamiento y seguridad',
  'Categorías de armas',
  'Circulación, revista y transferencia',
  'Documentación y licencias, Tarjeta Europea',
  'Régimen sancionador',
  'Reparación, prueba y depósito',
  'Armas de colección, definiciones, historia, calibres y munición',
];

void main() {
  testScreen('fresh install: ring, 7 tema cards, counts and footer', (
    tester,
  ) async {
    await pumpFullApp(tester);

    // The ring shows a percentage and its caption.
    expect(find.byType(ScoreRing), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ScoreRing),
        matching: find.textContaining('%'),
      ),
      findsOneWidget,
    );
    expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);

    // Continuar with the daily quota, Simulacro, Fallos and Teoría shortcuts.
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('15 preguntas para hoy'), findsOneWidget);
    expect(find.text('Simulacro'), findsOneWidget);
    expect(find.text('Fallos'), findsOneWidget);
    expect(find.text('Sin fallos pendientes'), findsOneWidget);
    expect(find.text('Teoría'), findsOneWidget);
    expect(find.text('Cifras y plazos'), findsOneWidget);
    expect(find.text('Tarjetas de cifras'), findsOneWidget);
    expect(find.byType(ActionCard), findsNWidgets(5));

    // Seven tema cards with their titles and an empty mastery bar.
    expect(find.byType(TemaCard), findsNWidgets(7));
    for (final title in _temaTitles) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('Dominio 0 %'), findsNWidgets(7));

    // Footer: legal line and bank edition.
    expect(find.textContaining('App independiente y no oficial'), findsOne);
    expect(find.text('Cuestionario GC nov-2020'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testScreen('tapping a tema, Simulacro, Fallos and Continuar navigates', (
    tester,
  ) async {
    await pumpFullApp(tester);

    Future<void> tapAndBack(Finder target, String expected) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(locationOf(tester), expected);
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/');
    }

    await tapAndBack(
      find.text('Circulación, revista y transferencia'),
      '/tema/3',
    );
    await tapAndBack(find.text('Simulacro'), '/simulacro');
    await tapAndBack(find.text('Fallos'), '/fallos');
    await tapAndBack(find.text('Continuar'), '/repaso');
  });

  testScreen('mistakes and tema mistakes show up on Inicio', (tester) async {
    await pumpFullApp(tester);
    final container = containerOf(tester);
    final bank = await bankOf(tester);
    final tema2 = bank.where((q) => q.tema == 2).take(2).toList();
    await container.read(studyServiceProvider).recordAnswers([
      for (final q in tema2) attemptOn(q, correct: false),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('2 fallos pendientes'), findsOneWidget);
    expect(find.text('2 fallos'), findsOneWidget); // on the tema 2 card
  });

  testScreen('the ring keeps its value while recomputing (no loader flash)', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final container = containerOf(tester);
    final bank = await bankOf(tester);
    String ringText() => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(ScoreRing),
            matching: find.textContaining('%'),
          ),
        )
        .data!;

    expect(ringText(), isNotEmpty);
    await container.read(studyServiceProvider).recordAnswers([
      for (final q in bank.where((q) => q.tema == 1).take(10))
        attemptOn(q, correct: true),
    ]);
    // Every frame while the providers recompute still shows a percentage.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('–'), findsNothing, reason: 'frame $i');
      expect(ringText(), contains('%'));
    }
    await tester.pumpAndSettle();
    expect(container.read(passProbabilityProvider).value, isNotNull);
  });

  testScreen('"Continuar" is disabled with a message when the queue is empty', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final container = containerOf(tester);
    final queue = await container.read(dailyQueueProvider.future);
    final bank = await bankOf(tester);
    final byId = {for (final q in bank) q.id: q};
    await container.read(studyServiceProvider).recordAnswers([
      for (final id in queue) attemptOn(byId[id]!, correct: true),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Has terminado el repaso de hoy. Puedes practicar un tema o hacer un '
        'simulacro.',
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNull);
  });

  testScreen('a new day on resume refreshes the daily queue', (tester) async {
    var now = kTestNow;
    await pumpFullApp(tester, clock: () => now);
    final container = containerOf(tester);
    final queue = await container.read(dailyQueueProvider.future);
    final bank = await bankOf(tester);
    final byId = {for (final q in bank) q.id: q};
    await container.read(studyServiceProvider).recordAnswers([
      for (final id in queue) attemptOn(byId[id]!, correct: true, at: kTestNow),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('15 preguntas para hoy'), findsNothing);

    // Next day, app returns to the foreground: the 15 cards are due plus 15
    // new questions.
    now = kTestNow.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('30 preguntas para hoy'), findsOneWidget);
  });

  testScreen('attempts feed the tema summaries', (tester) async {
    await pumpFullApp(tester);
    final container = containerOf(tester);
    final bank = await bankOf(tester);
    await container.read(studyServiceProvider).recordAnswers([
      for (final q in bank.where((q) => q.tema == 7))
        Attempt(
          questionId: q.id,
          mode: AttemptMode.practice,
          selected: q.answer,
          correct: true,
          answeredAt: kTestNow,
        ),
    ]);
    await tester.pumpAndSettle();
    final summaries = container.read(temaSummaryProvider).requireValue;
    expect(summaries, hasLength(7));
    expect(summaries.last.tema, 7);
    expect(summaries.last.coverage, 1);
    // Not 0 % any more: the mastery bar of tema 7 moved.
    expect(find.text('Dominio 0 %'), findsNWidgets(6));
  });
}
