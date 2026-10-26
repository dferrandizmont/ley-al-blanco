import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/db_support.dart';

Question _q(String id, {int tema = 1, int answer = 0}) => Question(
  id: id,
  tema: tema,
  stem: 'Enunciado $id',
  options: const ['A', 'B', 'C'],
  answer: answer,
  edition: 'GC-2020-11',
  flags: const ['x'],
  explanation: 'Porque si',
  article: 'Art. 1',
  section: 'Seccion',
  reviewed: true,
);

Attempt _a(
  String id,
  DateTime at, {
  AttemptMode mode = AttemptMode.practice,
  bool correct = true,
  int? selected = 0,
  int? mockId,
  int? elapsedMs,
}) => Attempt(
  questionId: id,
  mode: mode,
  selected: selected,
  correct: correct,
  answeredAt: at,
  mockId: mockId,
  elapsedMs: elapsedMs,
);

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  group('QuestionsDao', () {
    test('upsertAll inserts, then updates by id', () async {
      final first = await db.questionsDao.upsertAll([
        _q('t1-001'),
        _q('t1-002'),
      ]);
      expect(first, (inserted: 2, updated: 0));

      final second = await db.questionsDao.upsertAll([
        Question(
          id: 't1-002',
          tema: 1,
          stem: 'Nuevo',
          options: const ['a', 'b', 'c'],
          answer: 1,
          edition: 'GC-2020-11',
        ),
        _q('t1-003'),
      ]);
      expect(second, (inserted: 1, updated: 1));

      final byId = {for (final q in await db.questionsDao.allActive()) q.id: q};
      expect(byId.keys, unorderedEquals(['t1-001', 't1-002', 't1-003']));
      expect(byId['t1-002']!.stem, 'Nuevo');
      expect(byId['t1-002']!.explanation, isNull);
      expect(byId['t1-002']!.flags, isEmpty);
    });

    test('all optional and list fields round-trip', () async {
      await db.questionsDao.upsertAll([_q('t3-001', tema: 3, answer: 2)]);
      final q = (await db.questionsDao.byIds(['t3-001'])).single;
      expect(q, _q('t3-001', tema: 3, answer: 2));
    });

    test('allActive orders by tema, then numeric id', () async {
      await db.questionsDao.upsertAll([
        _q('t2-001', tema: 2),
        _q('t1-010'),
        _q('t1-002'),
        _q('t1-1000'),
        _q('t1-009'),
      ]);
      expect((await db.questionsDao.allActive()).map((q) => q.id), [
        't1-002',
        't1-009',
        't1-010',
        't1-1000',
        't2-001',
      ]);
      expect((await db.questionsDao.byTema(1)).map((q) => q.id), [
        't1-002',
        't1-009',
        't1-010',
        't1-1000',
      ]);
      expect(await db.questionsDao.byTema(5), isEmpty);
    });

    test('byIds preserves the requested order and skips unknown ids', () async {
      await db.questionsDao.upsertAll([
        _q('t1-001'),
        _q('t1-002'),
        _q('t2-001', tema: 2),
      ]);
      expect(
        (await db.questionsDao.byIds(['t2-001', 'nope', 't1-001', 't1-002']))
            .map((q) => q.id),
        ['t2-001', 't1-001', 't1-002'],
      );
      expect(await db.questionsDao.byIds(const []), isEmpty);
    });

    test(
      'markRetiredExcept flags, keeps rows, and counts newly retired',
      () async {
        await db.questionsDao.upsertAll([
          _q('t1-001'),
          _q('t1-002'),
          _q('t1-003'),
        ]);
        expect(await db.questionsDao.markRetiredExcept({'t1-001'}), 2);
        expect(await db.questionsDao.markRetiredExcept({'t1-001'}), 0);
        expect((await db.questionsDao.allActive()).map((q) => q.id), [
          't1-001',
        ]);
        expect((await db.questionsDao.byIds(['t1-002'])), hasLength(1));
        expect(await db.questionsDao.countByTema(), {1: 1});
      },
    );
  });

  group('AttemptsDao', () {
    final t0 = DateTime.utc(2026, 10, 15, 10);

    test('insert and all() return attempts oldest first', () async {
      await db.attemptsDao.insert(
        _a('t1-002', t0.add(const Duration(minutes: 5))),
      );
      await db.attemptsDao.insert(
        _a(
          't1-001',
          t0,
          mode: AttemptMode.mock,
          correct: false,
          selected: null,
          mockId: 7,
          elapsedMs: 1234,
        ),
      );
      final all = await db.attemptsDao.all();
      expect(all.map((a) => a.questionId), ['t1-001', 't1-002']);
      final first = all.first;
      expect(first.mode, AttemptMode.mock);
      expect(first.selected, isNull);
      expect(first.correct, isFalse);
      expect(first.mockId, 7);
      expect(first.elapsedMs, 1234);
      expect(first.answeredAt.isAtSameMomentAs(t0), isTrue);
    });

    test('insertAll keeps insertion order for equal timestamps', () async {
      await db.attemptsDao.insertAll([
        for (var i = 1; i <= 5; i++) _a('t1-00$i', t0),
      ]);
      expect((await db.attemptsDao.all()).map((a) => a.questionId), [
        for (var i = 1; i <= 5; i++) 't1-00$i',
      ]);
      await db.attemptsDao.insertAll(const []);
      expect(await db.attemptsDao.all(), hasLength(5));
    });

    test('forQuestion filters and orders', () async {
      await db.attemptsDao.insertAll([
        _a('t1-001', t0.add(const Duration(days: 2)), correct: true),
        _a('t1-002', t0),
        _a('t1-001', t0, correct: false),
      ]);
      final list = await db.attemptsDao.forQuestion('t1-001');
      expect(list.map((a) => a.correct), [false, true]);
      expect(await db.attemptsDao.forQuestion('zzz'), isEmpty);
    });

    test('watchAll emits on every change', () async {
      final emissions = <int>[];
      final sub = db.attemptsDao.watchAll().listen(
        (l) => emissions.add(l.length),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await db.attemptsDao.insert(_a('t1-001', t0));
      await pumpEventQueue();
      await db.attemptsDao.insert(_a('t1-002', t0));
      await pumpEventQueue();
      expect(emissions, [0, 1, 2]);
    });
  });

  group('MocksDao', () {
    final t0 = DateTime.utc(2026, 10, 15, 10);

    test('create starts an unfinished mock with blank answers', () async {
      final id = await db.mocksDao.create(
        questionIds: ['t1-001', 't2-001', 't3-001'],
        timed: true,
        startedAt: t0,
      );
      final m = (await db.mocksDao.byId(id))!;
      expect(m.questionIds, ['t1-001', 't2-001', 't3-001']);
      expect(m.answers, [null, null, null]);
      expect(m.timed, isTrue);
      expect(m.startedAt.isAtSameMomentAs(t0), isTrue);
      expect(m.finishedAt, isNull);
      expect(m.correctCount, isNull);
      expect(m.passed, isNull);
      expect(await db.mocksDao.recent(10), isEmpty);
      expect(await db.mocksDao.byId(999), isNull);
    });

    test('saveAnswers and finish persist; wrong length is rejected', () async {
      final id = await db.mocksDao.create(
        questionIds: ['a', 'b', 'c'],
        timed: false,
        startedAt: t0,
      );
      await db.mocksDao.saveAnswers(id, [2, null, 0]);
      expect((await db.mocksDao.byId(id))!.answers, [2, null, 0]);

      await expectLater(db.mocksDao.saveAnswers(id, [1]), throwsArgumentError);
      await expectLater(
        db.mocksDao.saveAnswers(404, [1, 1, 1]),
        throwsArgumentError,
      );

      final end = t0.add(const Duration(minutes: 18));
      await db.mocksDao.finish(
        id,
        answers: [2, 1, 0],
        correctCount: 2,
        passed: false,
        finishedAt: end,
      );
      final m = (await db.mocksDao.byId(id))!;
      expect(m.answers, [2, 1, 0]);
      expect(m.correctCount, 2);
      expect(m.passed, isFalse);
      expect(m.finishedAt!.isAtSameMomentAs(end), isTrue);
    });

    test('recent returns finished mocks, newest first, limited', () async {
      Future<int> finished(int offsetMinutes, {bool finish = true}) async {
        final id = await db.mocksDao.create(
          questionIds: ['a'],
          timed: false,
          startedAt: t0.add(Duration(minutes: offsetMinutes)),
        );
        if (finish) {
          await db.mocksDao.finish(
            id,
            answers: [0],
            correctCount: 1,
            passed: true,
            finishedAt: t0.add(Duration(minutes: offsetMinutes + 20)),
          );
        }
        return id;
      }

      final oldest = await finished(0);
      final newest = await finished(120);
      final middle = await finished(60);
      await finished(200, finish: false);

      expect((await db.mocksDao.recent(10)).map((m) => m.id), [
        newest,
        middle,
        oldest,
      ]);
      expect((await db.mocksDao.recent(2)).map((m) => m.id), [newest, middle]);
    });
  });

  group('SettingsDao', () {
    test('get/set overwrite', () async {
      expect(await db.settingsDao.get('k'), isNull);
      await db.settingsDao.set('k', 'v1');
      await db.settingsDao.set('k', 'v2');
      expect(await db.settingsDao.get('k'), 'v2');
      expect(await db.settingsDao.get('other'), isNull);
    });

    test('watch emits the current value and every change', () async {
      final values = <String?>[];
      final sub = db.settingsDao.watch('k').listen(values.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await db.settingsDao.set('k', 'a');
      await pumpEventQueue();
      await db.settingsDao.set('other', 'zzz');
      await db.settingsDao.set('k', 'b');
      await pumpEventQueue();
      expect(values.first, isNull);
      expect(values.last, 'b');
      expect(values, containsAllInOrder([null, 'a', 'b']));
    });
  });

  group('SrsDao', () {
    test('upsert, get and all', () async {
      final due = DateTime.utc(2026, 10, 16, 8);
      expect(await db.srsDao.get('t1-001'), isNull);
      await db.srsDao.upsert(
        SrsStateRow(
          questionId: 't1-001',
          box: 1,
          dueAt: due,
          reps: 1,
          lapses: 0,
          lastAnsweredAt: null,
        ),
      );
      await db.srsDao.upsert(
        SrsStateRow(
          questionId: 't1-001',
          box: 3,
          dueAt: due.add(const Duration(days: 3)),
          reps: 2,
          lapses: 1,
          lastAnsweredAt: due,
        ),
      );
      await db.srsDao.upsert(
        SrsStateRow(
          questionId: 't1-000',
          box: 1,
          dueAt: due,
          reps: 0,
          lapses: 0,
          lastAnsweredAt: null,
        ),
      );

      final row = (await db.srsDao.get('t1-001'))!;
      expect((row.box, row.reps, row.lapses), (3, 2, 1));
      expect(
        row.dueAt.isAtSameMomentAs(due.add(const Duration(days: 3))),
        isTrue,
      );
      expect(row.lastAnsweredAt!.isAtSameMomentAs(due), isTrue);
      expect((await db.srsDao.all()).map((r) => r.questionId), [
        't1-000',
        't1-001',
      ]);
    });
  });
}
