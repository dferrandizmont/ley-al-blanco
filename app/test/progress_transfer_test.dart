import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/theme/theme_mode_setting.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/progress_transfer/application/progress_transfer_providers.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_codec_runner.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_codec.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_snapshot.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:apto_armas/features/srs/domain/srs_card.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/study_support.dart';

/// Export -> import against real in-memory databases and the real bank:
/// round trip, strict refusal without side effects, atomicity and the refresh
/// of the providers.

/// A fresh phone with the bank imported.
Future<ProviderContainer> _app({
  DateTime? now,
  ProgressCodecRunner? runner,
}) async {
  final c = makeStudyContainer(
    now: now,
    overrides: [
      if (runner != null) progressCodecRunnerProvider.overrideWithValue(runner),
    ],
  );
  await c.read(questionsProvider.future);
  return c;
}

AppDatabase _db(ProviderContainer c) => c.read(appDatabaseProvider);

/// Varied progress: answers in the four modes (one blank), a finished and an
/// unfinished mock, review cards and a theme.
Future<void> _seed(ProviderContainer c) async {
  final bank = await c.read(questionsProvider.future);
  final db = _db(c);
  final mockQuestions = [for (final q in bank.take(20)) q.id];
  final mockId = await db.mocksDao.create(
    questionIds: mockQuestions,
    timed: true,
    startedAt: DateTime(2026, 10, 12, 18),
  );
  final answers = <int?>[
    for (final (i, q) in bank.take(20).indexed) i == 3 ? null : q.answer,
  ];
  await db.mocksDao.finish(
    mockId,
    answers: answers,
    correctCount: 19,
    passed: true,
    passMark: 16,
    finishedAt: DateTime(2026, 10, 12, 18, 40, 5, 321),
  );
  // An unfinished one.
  await db.mocksDao.create(
    questionIds: [for (final q in bank.skip(30).take(20)) q.id],
    timed: false,
    startedAt: DateTime(2026, 10, 14, 9),
  );

  await db.attemptsDao.insertAll([
    attemptOn(bank[0], correct: true, at: DateTime(2026, 10, 10, 9, 0, 0, 100)),
    attemptOn(bank[1], correct: false, at: DateTime(2026, 10, 10, 9, 1)),
    attemptOn(
      bank[2],
      correct: false,
      at: DateTime(2026, 10, 11, 20),
      mode: AttemptMode.review,
    ),
    attemptOn(
      bank[3],
      correct: true,
      at: DateTime(2026, 10, 11, 21),
      mode: AttemptMode.srs,
    ),
    for (final (i, q) in bank.take(20).indexed)
      Attempt(
        questionId: q.id,
        mode: AttemptMode.mock,
        selected: i == 3 ? null : q.answer,
        correct: i != 3,
        answeredAt: DateTime(2026, 10, 12, 18, 40, 5, 321),
        mockId: mockId,
        elapsedMs: i == 0 ? 3500 : null,
      ),
  ]);
  final srs = c.read(srsRepositoryProvider);
  for (final (i, q) in bank.take(5).indexed) {
    await srs.upsert(
      SrsCard(
        questionId: q.id,
        box: 1 + i % 5,
        dueAt: DateTime(2026, 10, 16 + i, 10),
        reps: i + 1,
        lapses: i % 2,
        lastAnsweredAt: DateTime(2026, 10, 11, 21, 0, 0, 250),
      ),
    );
  }
  await db.settingsDao.set(ThemeModeSetting.key, 'dark');
}

/// The state of [c]'s progress as the bytes an export would have.
Future<Uint8List> _stateOf(ProviderContainer c) async {
  final snapshot = await c
      .read(progressTransferRepositoryProvider)
      .read(
        edition: 'GC-2020-11',
        appVersion: 't',
        exportedAt: DateTime(2026, 10, 20, 10),
      );
  return ProgressCodec.encode(snapshot);
}

Future<Uint8List> _export(ProviderContainer c) async =>
    (await c.read(progressTransferProvider).buildExport()).bytes;

Future<void> _import(ProviderContainer c, Uint8List bytes) async {
  final transfer = c.read(progressTransferProvider);
  await transfer.apply(await transfer.preview(bytes));
}

/// A second phone with seeded progress.
Future<ProviderContainer> otherWithData() async {
  final o = await _app();
  await _seed(o);
  return o;
}

Map<String, dynamic> _decode(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

Uint8List _encode(Map<String, dynamic> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

Future<String?> _setting(ProviderContainer c, String key) =>
    _db(c).settingsDao.get(key);

void main() {
  // Two phones = two in-memory databases in one test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('export', () {
    test('the file name carries the date; the file has the documented '
        'header', () async {
      final c = await _app();
      await _seed(c);
      final built = await c.read(progressTransferProvider).buildExport();
      expect(built.fileName, 'ley-al-blanco-progreso-2026-10-15.json');
      final json = _decode(built.bytes);
      expect(json['format'], 'apto-armas-progress');
      expect(json['version'], 1);
      expect(json['edition'], 'GC-2020-11');
      expect(
        DateTime.parse(json['exported_at'] as String).toLocal(),
        kStudyNow,
      );
      expect((json['attempts'] as List).length, 24);
      expect((json['mocks'] as List).length, 2);
      expect((json['srs'] as List).length, 5);
      expect(
        (json['settings'] as Map)['theme_mode'],
        'dark',
        reason: 'the appearance travels',
      );
    });

    test('an empty progress exports as a valid empty file', () async {
      final c = await _app();
      final bytes = await _export(c);
      final plan = await c.read(progressTransferProvider).preview(bytes);
      expect(plan.snapshot.attempts, isEmpty);
      expect(plan.snapshot.mocks, isEmpty);
    });
  });

  group('round trip', () {
    test('export -> import into another phone gives the same state', () async {
      final a = await _app();
      await _seed(a);
      final b = await _app();

      await _import(b, await _export(a));

      expect(await _stateOf(b), await _stateOf(a));
      final db = _db(b);
      expect(await db.attemptsDao.all(), hasLength(24));
      expect(await db.mocksDao.startedCount(), 2);
      expect(await db.srsDao.all(), hasLength(5));
      expect(await _setting(b, ThemeModeSetting.key), 'dark');
    });

    test('mocks keep their ids and their attempts stay linked', () async {
      final a = await _app();
      await _seed(a);
      final b = await _app();
      await _import(b, await _export(a));

      final mocks = await _db(b).mocksDao.recent(10);
      expect(mocks.single.passed, isTrue);
      expect(mocks.single.passMark, 16);
      expect(mocks.single.finishedAt!.millisecond, 321);
      final attempts = await _db(b).attemptsDao.all();
      final inMock = attempts.where((x) => x.mockId == mocks.single.id);
      expect(inMock, hasLength(20));
    });

    test('importing replaces what was there', () async {
      final a = await _app();
      await _seed(a);
      final b = await _app();
      final bank = await b.read(questionsProvider.future);
      await _db(b).attemptsDao.insertAll([
        attemptOn(bank[100], correct: false, at: DateTime(2026, 10, 1)),
      ]);
      await b
          .read(srsRepositoryProvider)
          .upsert(
            SrsCard(
              questionId: bank[100].id,
              box: 3,
              dueAt: DateTime(2026, 11),
              reps: 4,
              lapses: 1,
              lastAnsweredAt: DateTime(2026, 10, 1),
            ),
          );

      await _import(b, await _export(a));

      final attempts = await _db(b).attemptsDao.all();
      expect(attempts.any((x) => x.questionId == bank[100].id), isFalse);
      expect(await _db(b).srsDao.get(bank[100].id), isNull);
      expect(await _stateOf(b), await _stateOf(a));
    });

    test('importing twice is the same as importing once', () async {
      final a = await _app();
      await _seed(a);
      final bytes = await _export(a);
      final b = await _app();
      await _import(b, bytes);
      final once = await _stateOf(b);
      await _import(b, bytes);
      expect(await _stateOf(b), once);
      expect(await _db(b).attemptsDao.all(), hasLength(24));
    });

    test('exporting what was just imported gives the same file', () async {
      final a = await _app();
      await _seed(a);
      final first = await _export(a);
      final b = await _app();
      await _import(b, first);
      expect(await _export(b), first);
    });
  });

  group('refusal changes nothing', () {
    late ProviderContainer c;
    late Uint8List before;

    setUp(() async {
      c = await _app();
      await _seed(c);
      before = await _stateOf(c);
    });

    Future<void> expectRefused(
      Uint8List bytes,
      ProgressImportError error,
    ) async {
      final transfer = c.read(progressTransferProvider);
      await expectLater(
        transfer.preview(bytes),
        throwsA(
          isA<ProgressImportException>().having((e) => e.error, 'error', error),
        ),
      );
      expect(await _stateOf(c), before);
      expect(await _db(c).attemptsDao.all(), hasLength(24));
    }

    test('corrupt file', () async {
      await expectRefused(
        Uint8List.fromList(utf8.encode('{"format": "apto-armas-pro')),
        ProgressImportError.notJson,
      );
    });

    test('unknown version', () async {
      final json = _decode(await _export(c))..['version'] = 2;
      await expectRefused(_encode(json), ProgressImportError.newerVersion);
    });

    test('wrong types', () async {
      final json = _decode(await _export(c));
      ((json['attempts'] as List)[2] as Map)['selected'] = 'dos';
      await expectRefused(_encode(json), ProgressImportError.invalid);
    });

    test('a date that is not a date', () async {
      final json = _decode(await _export(c));
      ((json['mocks'] as List).first as Map)['started_at'] =
          'ayer por la tarde';
      await expectRefused(_encode(json), ProgressImportError.invalidDateTime);
    });

    test('another bank edition', () async {
      final json = _decode(await _export(c))..['edition'] = 'GC-2019-01';
      await expectRefused(_encode(json), ProgressImportError.wrongEdition);
    });

    test('nesting beyond 8 levels', () async {
      await expectRefused(
        Uint8List.fromList(utf8.encode('${'[' * 9}${']' * 9}')),
        ProgressImportError.tooDeep,
      );
    });

    test('a file over the size limit', () async {
      await expectRefused(
        Uint8List(kMaxProgressFileBytes + 1),
        ProgressImportError.tooLarge,
      );
    });

    test('an option that the question does not have', () async {
      final json = _decode(await _export(c));
      ((json['attempts'] as List)[0] as Map)['selected'] = 7;
      await expectRefused(_encode(json), ProgressImportError.invalid);
    });
  });

  group('question ids that are not in the bank', () {
    test('are dropped and counted; the rest is imported', () async {
      final a = await _app();
      await _seed(a);
      final json = _decode(await _export(a));
      final attempts = (json['attempts'] as List).cast<Map<String, dynamic>>();
      attempts[0]['question_id'] = 't9-999';
      attempts[1]['question_id'] = 'inventada';
      final srs = (json['srs'] as List).cast<Map<String, dynamic>>();
      srs[0]['question_id'] = 't9-998';
      // A mock with a question from another edition goes whole, with its
      // attempts (the unfinished one).
      (((json['mocks'] as List)[1] as Map)['question_ids'] as List)[0] = 't9-1';

      final b = await _app();
      final transfer = b.read(progressTransferProvider);
      final plan = await transfer.preview(_encode(json));
      expect(plan.discardedAttempts, 2);
      expect(plan.discardedSrs, 1);
      expect(plan.discardedMocks, 1);
      expect(plan.discardedTotal, 4);

      await transfer.apply(plan);
      expect(await _db(b).attemptsDao.all(), hasLength(22));
      expect(await _db(b).srsDao.all(), hasLength(4));
      expect(await _db(b).mocksDao.startedCount(), 1);
    });
  });

  group('what the file claims is not trusted', () {
    test('correct is recomputed from the answer and the bank', () async {
      final a = await _app();
      await _seed(a);
      final json = _decode(await _export(a));
      final attempts = (json['attempts'] as List).cast<Map<String, dynamic>>();
      // [1] was answered wrong: claim it was right. [0] was right: claim
      // it was wrong.
      expect(attempts[1]['correct'], isFalse);
      attempts[1]['correct'] = true;
      expect(attempts[0]['correct'], isTrue);
      attempts[0]['correct'] = false;

      final b = await _app();
      await _import(b, _encode(json));
      final stored = await _db(b).attemptsDao.all();
      expect(stored[0].correct, isTrue);
      expect(stored[1].correct, isFalse);
    });

    test(
      'a finished mock is rescored with the bank and its pass mark',
      () async {
        final a = await _app();
        await _seed(a);
        final json = _decode(await _export(a));
        final mock = (json['mocks'] as List).first as Map<String, dynamic>;
        expect(mock['correct_count'], 19);
        mock
          ..['correct_count'] = 3
          ..['passed'] = false;

        final b = await _app();
        await _import(b, _encode(json));
        final stored = (await _db(b).mocksDao.recent(5)).single;
        expect(stored.correctCount, 19);
        expect(stored.passed, isTrue, reason: '19 >= pass mark 16');

        mock
          ..['correct_count'] = 20
          ..['passed'] = true
          ..['pass_mark'] = 20;
        final c = await _app();
        await _import(c, _encode(json));
        final lower = (await _db(c).mocksDao.recent(5)).single;
        expect(lower.correctCount, 19);
        expect(lower.passed, isFalse, reason: '19 < pass mark 20');
      },
    );
  });

  group('a wrong clock does not stop a migration', () {
    test('impossible dates and durations are dropped or fixed, and the '
        'rest is imported', () async {
      final a = await _app();
      await _seed(a);
      final json = _decode(await _export(a));
      final attempts = (json['attempts'] as List).cast<Map<String, dynamic>>();
      attempts[0]['answered_at'] = '2015-03-01T10:00:00.000Z';
      // [4] is the first attempt of the mock, with 3500 ms in the seed.
      expect(attempts[4]['elapsed_ms'], 3500);
      attempts[4]['elapsed_ms'] = -40;
      attempts[5]['elapsed_ms'] = 99999999999;
      (json['srs'] as List)[0]['due_at'] = '2999-01-01T00:00:00.000Z';
      final mock = (json['mocks'] as List).first as Map<String, dynamic>;
      mock['finished_at'] = '2026-10-01T00:00:00.000Z'; // before it started

      final b = await _app();
      final transfer = b.read(progressTransferProvider);
      final plan = await transfer.preview(_encode(json));
      expect(plan.discardedAttempts, 1);
      expect(plan.discardedSrs, 1);
      expect(plan.discardedMocks, 0);
      await transfer.apply(plan);

      final stored = await _db(b).attemptsDao.all();
      expect(stored, hasLength(23));
      expect(
        stored.where((x) => x.elapsedMs != null),
        isEmpty,
        reason: 'the only duration of the seed (3500) became null',
      );
      expect(await _db(b).srsDao.all(), hasLength(4));
      final m = (await _db(b).mocksDao.recent(5)).single;
      expect(m.finishedAt, m.startedAt);
    });

    test('a mock with an impossible date takes its attempts with it', () async {
      final a = await _app();
      await _seed(a);
      final json = _decode(await _export(a));
      ((json['mocks'] as List).first as Map)['started_at'] =
          '2001-01-01T00:00:00.000Z';
      final b = await _app();
      final plan = await b
          .read(progressTransferProvider)
          .preview(_encode(json));
      expect(plan.discardedMocks, 1);
      // The 20 attempts of the finished mock (the other mock was unfinished).
      expect(plan.discardedAttempts, 20);
      expect(plan.snapshot.mocks, hasLength(1));
    });
  });

  group('the codec runs on another isolate', () {
    test('the same result as running it inline, errors included', () async {
      final a = await _app();
      await _seed(a);
      final bytes = await _export(a);
      const isolate = IsolateProgressCodecRunner();
      const inline = InlineProgressCodecRunner();
      final now = DateTime(2026, 10, 20);
      final remote = await isolate.parse(bytes, now: now);
      final local = await inline.parse(bytes, now: now);
      expect(remote.attempts, local.attempts);
      expect(remote.mocks.length, local.mocks.length);
      expect(await isolate.encode(remote), await inline.encode(local));
      await expectLater(
        isolate.parse(Uint8List.fromList(utf8.encode('no')), now: now),
        throwsA(
          isA<ProgressImportException>().having(
            (e) => e.error,
            'error',
            ProgressImportError.notJson,
          ),
        ),
      );
    });

    test('an export over the limit says so instead of writing it', () async {
      final c = await _app(runner: const _HugeRunner());
      await expectLater(
        c.read(progressTransferProvider).buildExport(),
        throwsA(isA<ProgressExportTooLargeException>()),
      );
    });
  });

  group('the theme', () {
    test(
      'importing a theme goes straight to it, with no flash of another',
      () async {
        final a = await _app();
        await _seed(a); // theme dark
        final b = await _app();
        await _db(b).settingsDao.set(ThemeModeSetting.key, 'light');
        final seen = <ThemeMode>[];
        b.listen(themeModeProvider, (p, n) => seen.add(n));
        await settle();
        expect(b.read(themeModeProvider), ThemeMode.light);
        seen.clear();

        await _import(b, await _export(a));
        await settle();
        expect(b.read(themeModeProvider), ThemeMode.dark);
        expect(seen, [ThemeMode.dark], reason: 'never back through system');
      },
    );

    test('a file without a theme leaves the current one alone', () async {
      final a = await _app();
      final json = _decode(await _export(a));
      (json['settings'] as Map<String, dynamic>)['theme_mode'] = null;
      final b = await _app();
      await _db(b).settingsDao.set(ThemeModeSetting.key, 'light');
      final seen = <ThemeMode>[];
      b.listen(themeModeProvider, (p, n) => seen.add(n));
      await settle();
      seen.clear();

      await _import(b, _encode(json));
      await settle();
      expect(b.read(themeModeProvider), ThemeMode.light);
      expect(seen, isEmpty);
      expect(await _setting(b, ThemeModeSetting.key), 'light');
    });
  });

  group('atomicity', () {
    test('a failure half way leaves the previous progress untouched', () async {
      final c = await _app();
      await _seed(c);
      final before = await _stateOf(c);
      final theme = await _setting(c, ThemeModeSetting.key);
      final snapshot =
          (await c
                  .read(progressTransferProvider)
                  .preview(await _export(await otherWithData())))
              .snapshot;
      // Two cards for the same question: the third table to be written
      // fails after the other two were already emptied and refilled.
      final broken = ProgressSnapshot(
        edition: snapshot.edition,
        exportedAt: snapshot.exportedAt,
        appVersion: snapshot.appVersion,
        attempts: snapshot.attempts,
        srs: [snapshot.srs.first, snapshot.srs.first],
        mocks: snapshot.mocks,
        settings: const ProgressSettings(themeMode: 'light'),
      );

      await expectLater(
        c.read(progressTransferRepositoryProvider).replaceWith(broken),
        throwsA(anything),
      );

      expect(await _stateOf(c), before);
      expect(await _db(c).attemptsDao.all(), hasLength(24));
      expect(await _setting(c, ThemeModeSetting.key), theme);
      // The settings write comes after the tables: the new theme must not leak.
      expect(await _setting(c, ThemeModeSetting.key), 'dark');
    });
  });

  group('providers refresh without a restart', () {
    test('answers, fallos, review cards, mocks and the theme', () async {
      final a = await _app();
      await _seed(a);
      final b = await _app();
      // Listen so the providers are alive, as the screens do.
      b
        ..listen(themeModeProvider, (p, n) {})
        ..listen(mockHistoryProvider, (p, n) {});
      expect(await b.read(attemptsProvider.future), isEmpty);
      expect(await b.read(srsCardsProvider.future), isEmpty);
      expect(await b.read(mockHistoryProvider.future), isEmpty);
      expect(b.read(themeModeProvider), ThemeMode.system);

      await _import(b, await _export(a));
      await settle();

      expect(await b.read(attemptsProvider.future), hasLength(24));
      expect(await b.read(srsCardsProvider.future), hasLength(5));
      expect(await b.read(mockHistoryProvider.future), hasLength(1));
      expect(b.read(themeModeProvider), ThemeMode.dark);
    });

    test('a mock history of the same size still refreshes', () async {
      // One finished mock before and one after: the count does not change.
      final a = await _app();
      await _seed(a);
      final b = await _app();
      await _seed(b);
      b.listen(mockHistoryProvider, (p, n) {});
      final before = await b.read(mockHistoryProvider.future);
      expect(before, hasLength(1));

      final json = _decode(await _export(a));
      // The score is recomputed on import (19 right): with a higher pass
      // mark the same mock is no longer a pass. It starts earlier than the
      // one `b` made itself: a file's copy of the very mock the device made
      // (same id, start and questions) keeps the device's state instead.
      final mock = (json['mocks'] as List).first as Map;
      mock['started_at'] = '2026-10-12T10:00:00.000Z';
      mock['pass_mark'] = 20;
      await _import(b, _encode(json));
      await settle();

      final after = await b.read(mockHistoryProvider.future);
      expect(after.single.correct, 19);
      expect(after.single.passMark, 20);
      expect(after.single.passed, isFalse);
    });
  });
}

/// A codec whose export is bigger than the import limit.
class _HugeRunner extends InlineProgressCodecRunner {
  const _HugeRunner();

  @override
  Future<Uint8List> encode(ProgressSnapshot snapshot) async =>
      Uint8List(kMaxProgressFileBytes + 1);
}
