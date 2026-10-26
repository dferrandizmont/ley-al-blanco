import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

/// The real bank with the `cifras` flag moved onto the given ids only (the
/// real flags are removed), as a bundle.
FakeAssetBundle _bankFlaggedOnly(Set<String> ids) {
  final json = realQuestionsJson();
  for (final q in json) {
    final flags = (q['flags'] as List).cast<String>().toList()
      ..remove(kFiguresFlag);
    if (ids.contains(q['id'])) flags.add(kFiguresFlag);
    q['flags'] = flags;
  }
  return FakeAssetBundle.edition(json);
}

void main() {
  const figures = FiguresPractice();

  group('the flag in the bank', () {
    test('Question.isFigures reads the pipeline flag and nothing else', () {
      final json = realQuestionsJson();
      final bank = [for (final q in json) Question.fromJson(q)];
      for (final (i, q) in bank.indexed) {
        final flags = (json[i]['flags'] as List).cast<String>();
        expect(q.isFigures, flags.contains('cifras'), reason: q.id);
      }
      final flagged = bank.where((q) => q.isFigures).toList();
      expect(flagged.length, inInclusiveRange(60, 100));
      // The famous traps are in: ages, terms, fines.
      for (final id in ['t4-002', 't5-005', 't5-018', 't3-030', 't6-025']) {
        expect(flagged.map((q) => q.id), contains(id));
      }
      // Whole-bank sanity: it does not flag questions without any figure.
      expect(flagged.map((q) => q.id), isNot(contains('t2-011')));
    });
  });

  group('the mode', () {
    test(
      'a full user practises every flagged question, in bank order',
      () async {
        final c = makeStudyContainer();
        c.listen(practiceControllerProvider(figures), (previous, next) {});
        final bank = await c.read(questionsProvider.future);
        final state = await c.read(practiceControllerProvider(figures).future);
        final expected = [
          for (final q in bank)
            if (q.isFigures) q.id,
        ];
        expect(expected, isNotEmpty);
        expect([for (final q in state.session!.questions) q.id], expected);
        expect(state.session!.mode, figures.mode);
      },
    );

    test('it resumes at the first question never answered', () async {
      final c = makeStudyContainer();
      final bank = await c.read(questionsProvider.future);
      final flagged = [
        for (final q in bank)
          if (q.isFigures) q,
      ];
      await c.read(studyServiceProvider).recordAnswers([
        attemptOn(flagged[0], correct: true),
        attemptOn(flagged[1], correct: false),
      ]);
      await settle();
      c.listen(practiceControllerProvider(figures), (previous, next) {});
      final state = await c.read(practiceControllerProvider(figures).future);
      expect(state.session!.questions.first.id, flagged[2].id);
    });
  });

  group('Inicio', () {
    testScreen('full: the tile counts the questions and opens the mode', (
      tester,
    ) async {
      await pumpFullApp(tester);
      final bank = await bankOf(tester);
      final count = bank.where((q) => q.isFigures).length;
      final tile = find.widgetWithText(ActionCard, 'Cifras y plazos');
      expect(tile, findsOneWidget);
      expect(
        find.text('$count preguntas de plazos, edades e importes'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.lock_rounded)),
        findsNothing,
      );

      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/cifras');
      expect(find.text('CIFRAS Y PLAZOS'), findsOneWidget);
      expect(find.text('1 / $count'), findsOneWidget);
      // The first flagged question of the bank, untouched.
      expect(find.text(bank.firstWhere((q) => q.isFigures).stem), findsOne);
    });

    testScreen('no flagged question in the bank: no tile', (tester) async {
      await pumpFullApp(tester, bundle: _bankFlaggedOnly({}));
      expect(find.text('Cifras y plazos'), findsNothing);
    });
  });
}
