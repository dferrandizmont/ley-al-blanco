import 'dart:math';

import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/notice_callout.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/progress/application/progress_providers.dart';
import 'package:apto_armas/features/quiz/application/figures_cards_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:apto_armas/features/quiz/presentation/figures_cards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

const _title = 'Tarjetas de cifras';
const _reveal = 'Ver respuesta';
const _known = 'La sabía';
const _again = 'Repasar otra vez';
const _restart = 'Otra vez con las que repasé';

// Only the flags change: official questions, answers and our explanation
// layer remain the real bank's, including its reform notices.
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

// The access policy settles after the first build (entitlement and free-mock
// streams); a rebuild then would start a new round, so wait for it.
Future<FiguresCardsState> _start(ProviderContainer container) async {
  container.listen(figuresCardsControllerProvider, (previous, next) {});
  await container.read(figuresCardsControllerProvider.future);
  await settle();
  return container.read(figuresCardsControllerProvider.future);
}

FiguresCardsState _state(ProviderContainer container) =>
    container.read(figuresCardsControllerProvider).requireValue;

void _answer(ProviderContainer container, {required bool known}) {
  final controller = container.read(figuresCardsControllerProvider.notifier);
  controller.reveal();
  controller.answer(known: known);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Question _realNoticeQuestion() => realQuestionsJson()
    .map(Question.fromJson)
    .firstWhere(
      (q) =>
          q.isFigures &&
          q.notice != null &&
          q.explanation != null &&
          q.article != null,
    );

void main() {
  group('figures cards deck', () {
    test('full contains exactly every flagged question', () async {
      final c = makeStudyContainer();
      final bank = await c.read(questionsProvider.future);
      final state = await _start(c);
      final expected = bank.where((q) => q.isFigures).toList();
      expect(expected, isNotEmpty);
      expect(state.pending, unorderedEquals(expected));
      expect(state.total, expected.length);
      expect(state.revealed, isFalse);
      expect(state.position, 1);
    });

    test(
      'shuffle uses the injected random and preserves the complete deck',
      () async {
        final c = makeStudyContainer(seed: 17);
        final bank = await c.read(questionsProvider.future);
        final ordered = bank.where((q) => q.isFigures).toList();
        final expected = [...ordered]..shuffle(Random(17));
        final state = await _start(c);
        expect(state.pending, orderedEquals(expected));
        expect(state.pending, isNot(orderedEquals(ordered)));

        final other = makeStudyContainer(seed: 23);
        final otherState = await _start(other);
        expect(otherState.pending, unorderedEquals(state.pending));
        expect(otherState.pending, isNot(orderedEquals(state.pending)));
      },
    );
  });

  group('figures cards round', () {
    test(
      'answer requires reveal; again requeues without advancing progress',
      () async {
        final c = makeStudyContainer(
          bundle: _bankFlaggedOnly({'t4-002', 't5-005'}),
        );
        final initial = await _start(c);
        final controller = c.read(figuresCardsControllerProvider.notifier);
        controller.answer(known: true);
        expect(_state(c), same(initial));
        controller.reveal();
        expect(_state(c).revealed, isTrue);
        expect(_state(c).current, initial.current);
        controller.answer(known: false);
        final repeated = _state(c);
        expect(repeated.pending, [initial.pending.last, initial.current]);
        expect(repeated.reviewed, [initial.current]);
        expect(
          (repeated.completed, repeated.position, repeated.total),
          (0, 1, 2),
        );
        expect(repeated.revealed, isFalse);
      },
    );

    test(
      'first-try score and unique reviewed cards survive repeated laps',
      () async {
        final c = makeStudyContainer(
          bundle: _bankFlaggedOnly({'t4-002', 't5-005', 't5-018'}),
        );
        final initial = await _start(c);
        final repeatedId = initial.current.id;
        _answer(c, known: false);
        _answer(c, known: true);
        _answer(c, known: true);
        expect(_state(c).current.id, repeatedId);
        _answer(c, known: false);
        _answer(c, known: false);
        _answer(c, known: true);
        final finished = _state(c);
        expect(finished.finished, isTrue);
        expect(finished.knownFirstTry, 2);
        expect(finished.total, 3);
        expect(finished.completed, 3);
        expect(finished.seen, hasLength(3));
        expect(finished.reviewed.map((q) => q.id), [repeatedId]);

        c.read(figuresCardsControllerProvider.notifier).restartReviewed();
        final restarted = _state(c);
        expect(restarted.pending.map((q) => q.id), [repeatedId]);
        expect(
          (restarted.total, restarted.completed, restarted.knownFirstTry),
          (1, 0, 0),
        );
        expect(restarted.seen, isEmpty);
        expect(restarted.reviewed, isEmpty);
        expect(restarted.revealed, isFalse);
        _answer(c, known: true);
        expect(_state(c).knownFirstTry, 1);
      },
    );

    test(
      'restart contains each reviewed card once and excludes known cards',
      () async {
        final c = makeStudyContainer(
          bundle: _bankFlaggedOnly({'t4-002', 't5-005', 't5-018'}),
        );
        final initial = await _start(c);
        final reviewed = initial.pending.take(2).toList();
        _answer(c, known: false);
        _answer(c, known: false);
        _answer(c, known: true);
        _answer(c, known: false);
        _answer(c, known: true);
        _answer(c, known: true);
        expect(_state(c).finished, isTrue);
        c.read(figuresCardsControllerProvider.notifier).restartReviewed();
        expect(_state(c).pending, unorderedEquals(reviewed));
        expect(_state(c).total, 2);
        expect(_state(c).knownFirstTry, 0);
      },
    );

    test(
      'reveal, answers and restart never write attempts, SRS or progress',
      () async {
        final c = makeStudyContainer(
          bundle: _bankFlaggedOnly({'t4-002', 't5-005'}),
        );
        final initial = await _start(c);
        // Existing study history must also remain untouched.
        await c.read(studyServiceProvider).recordAnswers([
          attemptOn(initial.current, correct: false),
        ]);
        await settle();
        final attempts = await c.read(attemptsProvider.future);
        final srs = await c.read(srsCardsProvider.future);
        final mastery = await c.read(masteryByIdProvider.future);
        final coverage = await c.read(coverageProvider.future);
        _answer(c, known: false);
        _answer(c, known: true);
        _answer(c, known: true);
        c.read(figuresCardsControllerProvider.notifier).restartReviewed();
        _answer(c, known: true);
        await settle();
        expect(await c.read(attemptsProvider.future), attempts);
        expect(await c.read(srsCardsProvider.future), srs);
        expect(await c.read(masteryByIdProvider.future), mastery);
        expect(await c.read(coverageProvider.future), coverage);
      },
    );
  });

  group('figures cards screen', () {
    testScreen('reveal keeps the real official answer and explanation layer', (
      tester,
    ) async {
      final question = _realNoticeQuestion();
      await pumpFullApp(tester, bundle: _bankFlaggedOnly({question.id}));
      await pushRoute(tester, '/cifras/tarjetas');
      expect(find.text(question.stem), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(question.stem)).style!.fontSize,
        inInclusiveRange(18, 20),
      );
      expect(find.text('La respuesta'), findsNothing);
      expect(find.text(_known), findsNothing);
      expect(find.text(_again), findsNothing);
      await _tap(tester, _reveal);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.text('Correcto'), findsNothing);
      expect(find.text('La respuesta'), findsOneWidget);
      expect(find.text('Respuesta correcta'), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('La respuesta')),
        matchesSemantics(label: 'La respuesta', isHeader: true),
      );
      semantics.dispose();
      final label = tester.widget<Text>(find.text('La respuesta'));
      final context = tester.element(find.text('La respuesta'));
      expect(label.style?.color, isNot(context.colors.correctText));
      expect(label.style?.color, isNot(context.colors.incorrectText));
      final letter = String.fromCharCode(0x41 + question.answer);
      expect(
        find.text('$letter. ${question.options[question.answer]}'),
        findsOneWidget,
      );
      for (final (i, option) in question.options.indexed) {
        if (i != question.answer) {
          expect(
            find.text('${String.fromCharCode(0x41 + i)}. $option'),
            findsNothing,
          );
        }
      }
      expect(find.text(question.explanation!), findsOneWidget);
      expect(
        tester.widget<ArticleChip>(find.byType(ArticleChip)).article,
        question.article,
      );
      expect(
        tester.widget<NoticeCallout>(find.byType(NoticeCallout)).text,
        question.notice,
      );
      await _tap(tester, _again);
      expect(find.text(_reveal), findsOneWidget);
      expect(find.text('La respuesta'), findsNothing);
      await _tap(tester, _reveal);
      await _tap(tester, _known);
      expect(find.text('Sabías 0 de 1 a la primera'), findsOneWidget);
      expect(find.text(_restart), findsOneWidget);
      await _tap(tester, _restart);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text(_reveal), findsOneWidget);
    });

    testScreen('t7-003 reveals only its answer about an earlier date', (
      tester,
    ) async {
      await pumpFullApp(tester, bundle: _bankFlaggedOnly({'t7-003'}));
      await pushRoute(tester, '/cifras/tarjetas');
      final question = _state(containerOf(tester)).current;
      await _tap(tester, _reveal);
      for (final (i, option) in question.options.indexed) {
        expect(
          find.text('${String.fromCharCode(0x41 + i)}. $option'),
          i == question.answer ? findsOneWidget : findsNothing,
        );
      }
      expect(find.text('La respuesta'), findsOneWidget);
      expect(find.text('Respuesta correcta'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    for (final id in ['t2-020', 't5-066']) {
      testScreen('$id reveals all options referenced by the answer', (
        tester,
      ) async {
        await pumpFullApp(tester, bundle: _bankFlaggedOnly({id}));
        await pushRoute(tester, '/cifras/tarjetas');
        final question = _state(containerOf(tester)).current;
        await _tap(tester, _reveal);
        for (final (i, option) in question.options.indexed) {
          final text = find.text('${String.fromCharCode(0x41 + i)}. $option');
          expect(text, findsOneWidget);
          final context = tester.element(text);
          expect(
            tester.widget<Text>(text).style?.color,
            i == question.answer
                ? context.colors.correctText
                : context.colors.textPrimary,
          );
        }
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.text('Correcto'), findsNothing);
        expect(find.text('Respuesta correcta'), findsNothing);
      });
    }

    for (final (answer, showOptions) in [
      ('Las dos anteriores son correctas.', true),
      ('Las tres anteriores son correctas.', true),
      ('Las respuestas anteriores son correctas.', true),
      ('Ninguna de las anteriores.', true),
      ('Ambas son correctas.', true),
      ('Son correctas las dos respuestas anteriores.', true),
      ('  ÁMBAS son correctas.', true),
      ('La fecha es anterior a 1890.', false),
      ('Se aplican ambas condiciones.', false),
      ('Ambasador.', false),
    ]) {
      testScreen('cross-reference prefix: $answer', (tester) async {
        final question = Question(
          id: 'test-reference',
          tema: 1,
          stem: 'Pregunta de prueba',
          options: ['Primera opción.', 'Segunda opción.', answer],
          answer: 2,
          edition: 'test',
          flags: [kFiguresFlag],
        );
        await pumpApp(
          tester,
          const FiguresCardsScreen(),
          overrides: [
            questionsProvider.overrideWith((ref) async => [question]),
          ],
        );
        await _tap(tester, _reveal);
        for (final (i, option) in question.options.indexed) {
          expect(
            find.text('${String.fromCharCode(0x41 + i)}. $option'),
            showOptions || i == question.answer ? findsOneWidget : findsNothing,
          );
        }
      });
    }

    testScreen('all known: score is first-try and restart is hidden', (
      tester,
    ) async {
      await pumpFullApp(tester, bundle: _bankFlaggedOnly({'t4-002'}));
      await pushRoute(tester, '/cifras/tarjetas');
      await _tap(tester, _reveal);
      await _tap(tester, _known);
      expect(find.text('Sabías 1 de 1 a la primera'), findsOneWidget);
      expect(find.text(_restart), findsNothing);
      expect(find.text('Volver'), findsOneWidget);
    });

    testScreen('leaving and reentering begins a new in-memory session', (
      tester,
    ) async {
      await pumpFullApp(tester, bundle: _bankFlaggedOnly({'t4-002', 't5-005'}));
      await pushRoute(tester, '/cifras/tarjetas');
      await _tap(tester, _reveal);
      await _tap(tester, _known);
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/');
      await pushRoute(tester, '/cifras/tarjetas');
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text(_reveal), findsOneWidget);
      final state = _state(containerOf(tester));
      expect(state.seen, isEmpty);
      expect(state.knownFirstTry, 0);
    });
  });

  group('Inicio figures cards tile', () {
    testScreen('full shows count and opens cards', (tester) async {
      await pumpFullApp(tester);
      final bank = await bankOf(tester);
      final count = bank.where((q) => q.isFigures).length;
      final tile = find.widgetWithText(ActionCard, _title);
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            '$count tarjetas: piensa la respuesta y dale la vuelta',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.lock_rounded)),
        findsNothing,
      );
      await _tap(tester, _title);
      expect(locationOf(tester), '/cifras/tarjetas');
      expect(find.text('1 / $count'), findsOneWidget);
    });

    testScreen('no flagged question means no cards tile', (tester) async {
      await pumpFullApp(tester, bundle: _bankFlaggedOnly({}));
      expect(find.widgetWithText(ActionCard, _title), findsNothing);
    });
  });

  for (final dark in [false, true]) {
    testScreen(
      '320x568 at x2, ${dark ? 'dark' : 'light'}: every face scrolls',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final question = _realNoticeQuestion();
        await pumpApp(
          tester,
          const FiguresCardsScreen(),
          dark: dark,
          textScale: 2,
          overrides: [
            questionsProvider.overrideWith((ref) async => [question]),
          ],
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, _reveal);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(question.notice!));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tap(tester, _again);
        expect(tester.takeException(), isNull);
        await _tap(tester, _reveal);
        await _tap(tester, _known);
        expect(find.text('Sabías 0 de 1 a la primera'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tap(tester, _restart);
        expect(find.text('1 / 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
