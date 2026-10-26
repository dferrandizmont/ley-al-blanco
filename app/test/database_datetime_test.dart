import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/db_support.dart';

// Policy (see app_database.dart): UTC ISO 8601 text on disk, local DateTime
// when read. These tests do not depend on the machine's time zone: they
// compare instants.
void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Attempt attempt(String id, DateTime at) => Attempt(
    questionId: id,
    mode: AttemptMode.practice,
    selected: 0,
    correct: true,
    answeredAt: at,
  );

  Future<List<String>> rawAnsweredAt() async => [
    for (final r
        in await db
            .customSelect('SELECT answered_at FROM attempts ORDER BY id')
            .get())
      r.read<String>('answered_at'),
  ];

  test('local and UTC inputs are both stored as UTC text', () async {
    final local = DateTime(2026, 10, 15, 18, 30, 15, 123);
    await db.attemptsDao.insert(attempt('a', local));
    await db.attemptsDao.insert(attempt('b', DateTime.utc(2026, 10, 15, 1)));

    final raw = await rawAnsweredAt();
    expect(raw[0], local.toUtc().toIso8601String());
    expect(raw[1], '2026-10-15T01:00:00.000Z');
    expect(raw, everyElement(endsWith('Z')));
  });

  test('values are read back as local time, same instant', () async {
    final local = DateTime(2026, 10, 15, 18, 30, 15, 123);
    await db.attemptsDao.insert(attempt('a', local));
    final read = (await db.attemptsDao.all()).single.answeredAt;
    expect(read.isUtc, isFalse);
    expect(read.isAtSameMomentAs(local), isTrue);
    expect(read, local);
  });

  test('DST change in Europe/Madrid (2026-10-25) keeps the instants', () async {
    // Clocks go back at 01:00 UTC: 02:30 happens twice in Madrid.
    final firstPass = DateTime.utc(2026, 10, 25, 0, 30); // 02:30 CEST (+02:00)
    final secondPass = DateTime.utc(2026, 10, 25, 1, 30); // 02:30 CET  (+01:00)
    final before = DateTime.utc(2026, 10, 24, 23, 59); // 01:59 CEST
    final after = DateTime.utc(2026, 10, 25, 2, 0); // 03:00 CET

    // Inserted out of order on purpose.
    for (final (i, at) in [secondPass, before, after, firstPass].indexed) {
      await db.attemptsDao.insert(attempt('q$i', at));
    }

    final all = await db.attemptsDao.all();
    expect(all.map((a) => a.answeredAt.toUtc()), [
      before,
      firstPass,
      secondPass,
      after,
    ]);
    // The ambiguous wall-clock times stay distinct: one hour apart.
    expect(
      all[2].answeredAt.difference(all[1].answeredAt),
      const Duration(hours: 1),
    );
  });

  test('stored text sorts chronologically across the DST change', () async {
    final instants = [
      DateTime.utc(2026, 10, 25, 1, 30),
      DateTime.utc(2026, 10, 24, 23, 59),
      DateTime.utc(2026, 10, 25, 0, 30),
    ];
    for (final (i, at) in instants.indexed) {
      await db.attemptsDao.insert(attempt('q$i', at));
    }
    final sorted = [
      for (final r
          in await db
              .customSelect(
                'SELECT answered_at FROM attempts ORDER BY answered_at',
              )
              .get())
        DateTime.parse(r.read<String>('answered_at')),
    ];
    expect(sorted, [...instants]..sort());
  });

  test('mock and SRS dates follow the same policy', () async {
    final start = DateTime(2026, 10, 25, 3, 0);
    final end = start.add(const Duration(minutes: 20));
    final id = await db.mocksDao.create(
      questionIds: ['a'],
      timed: true,
      startedAt: start,
    );
    await db.mocksDao.finish(
      id,
      answers: [0],
      correctCount: 1,
      passed: true,
      finishedAt: end,
    );
    final m = (await db.mocksDao.byId(id))!;
    expect(m.startedAt.isAtSameMomentAs(start), isTrue);
    expect(m.finishedAt!.isAtSameMomentAs(end), isTrue);
    expect(m.startedAt.isUtc, isFalse);

    final raw = await db
        .customSelect('SELECT started_at, finished_at FROM mocks')
        .getSingle();
    expect(raw.read<String>('started_at'), endsWith('Z'));
    expect(raw.read<String>('finished_at'), endsWith('Z'));

    await db.srsDao.upsert(
      SrsStateRow(
        questionId: 'a',
        box: 1,
        dueAt: end,
        reps: 1,
        lapses: 0,
        lastAnsweredAt: start,
      ),
    );
    final srs = (await db.srsDao.get('a'))!;
    expect(srs.dueAt.isAtSameMomentAs(end), isTrue);
    expect(srs.lastAnsweredAt!.isAtSameMomentAs(start), isTrue);
  });
}
