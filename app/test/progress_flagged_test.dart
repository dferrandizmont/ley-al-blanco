import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/progress_transfer/application/progress_transfer_providers.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_codec.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_snapshot.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/study_support.dart';

/// The doubtful marks of a mock travel with the progress file (`flagged`, an
/// optional list of question ids per mock; the format stays at version 1).

final DateTime _now = DateTime(2026, 10, 20, 10);

const Map<String, BankQuestion> _bank = {
  't1-001': (options: 3, answer: 0),
  't1-002': (options: 3, answer: 0),
  't2-001': (options: 3, answer: 0),
};

MockEntry _mock({List<String> flagged = const [], bool finished = false}) =>
    MockEntry(
      id: 7,
      startedAt: DateTime(2026, 10, 15, 18),
      finishedAt: finished ? DateTime(2026, 10, 15, 18, 30) : null,
      questionIds: const ['t1-001', 't1-002'],
      answers: const [0, null],
      correctCount: finished ? 1 : null,
      passed: finished ? false : null,
      passMark: finished ? 2 : null,
      timed: true,
      flagged: flagged,
    );

ProgressSnapshot _snapshot(List<MockEntry> mocks) => ProgressSnapshot(
  edition: 'GC-2020-11',
  exportedAt: DateTime(2026, 10, 20, 9, 30),
  appVersion: '0.7.1',
  attempts: const [],
  srs: const [],
  mocks: mocks,
  settings: const ProgressSettings(),
);

Map<String, dynamic> _json(ProgressSnapshot s) =>
    jsonDecode(utf8.decode(ProgressCodec.encode(s))) as Map<String, dynamic>;

Uint8List _bytes(Map<String, dynamic> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

ProgressSnapshot _parse(Map<String, dynamic> json) =>
    ProgressCodec.parse(_bytes(json), now: _now, mockSize: 2);

Map<String, dynamic> _mockJson(Map<String, dynamic> json) =>
    ((json['mocks'] as List).single as Map).cast<String, dynamic>();

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('file format', () {
    test('a mock writes its doubtful questions after pass_mark', () {
      final mock = _mockJson(
        _json(
          _snapshot([
            _mock(flagged: ['t1-002']),
          ]),
        ),
      );
      expect(mock.keys.last, 'flagged');
      expect(mock['flagged'], ['t1-002']);
      expect(mock.keys, contains('pass_mark'));
    });

    test('they round-trip, and the version stays 1', () {
      final json = _json(
        _snapshot([
          _mock(flagged: ['t1-001', 't1-002'], finished: true),
        ]),
      );
      expect(json['version'], 1);
      expect(_parse(json).mocks.single.flagged, ['t1-001', 't1-002']);
    });

    test('a file from before the mark has none and is still valid', () {
      final json = _json(_snapshot([_mock()]))
        ..['mocks'] = [
          (_mockJson(_json(_snapshot([_mock()]))))..remove('flagged'),
        ];
      expect(_parse(json).mocks.single.flagged, isEmpty);
    });

    test('ids that are not the mock\'s own, and repeats, are left out', () {
      final json = _json(_snapshot([_mock()]));
      _mockJson(json)['flagged'] = ['t2-001', 't1-002', 't1-002', 'zzz'];
      expect(_parse(json).mocks.single.flagged, ['t1-002']);
    });

    test('wrong types are refused', () {
      for (final bad in <Object?>[
        'nope',
        [1, 2],
        {'a': 1},
      ]) {
        final json = _json(_snapshot([_mock()]));
        _mockJson(json)['flagged'] = bad;
        expect(
          () => _parse(json),
          throwsA(isA<ProgressImportException>()),
          reason: '$bad',
        );
      }
    });

    test('an absurd list is refused instead of parsed', () {
      final json = _json(_snapshot([_mock()]));
      _mockJson(json)['flagged'] = List.filled(500, 't1-001');
      expect(() => _parse(json), throwsA(isA<ProgressImportException>()));
    });

    test('reconcile keeps them for open and finished mocks', () {
      final plan = ProgressCodec.reconcile(
        _snapshot([
          _mock(flagged: ['t1-001']),
          MockEntry(
            id: 8,
            startedAt: DateTime(2026, 10, 16, 18),
            finishedAt: DateTime(2026, 10, 16, 18, 30),
            questionIds: const ['t1-001', 't1-002'],
            answers: const [0, 0],
            correctCount: 2,
            passed: true,
            passMark: 2,
            timed: false,
            flagged: const ['t1-002'],
          ),
        ]),
        _bank,
      );
      expect(plan.snapshot.mocks.map((m) => m.flagged), [
        ['t1-001'],
        ['t1-002'],
      ]);
    });
  });

  group('export and import through the database', () {
    Future<ProviderContainer> app() async {
      final c = makeStudyContainer(overrides: []);
      await c.read(questionsProvider.future);
      return c;
    }

    /// A mock of the bank's questions `skip`..`skip + 20`, with the questions
    /// at `marks` (positions) marked as doubtful.
    Future<int> startMockWithMarks(
      ProviderContainer c, {
      int skip = 0,
      List<int> marks = const [2, 11],
    }) async {
      final db = c.read(appDatabaseProvider);
      final ids = [
        for (final q in (await c.read(
          questionsProvider.future,
        )).skip(skip).take(20))
          q.id,
      ];
      final started = await db.mocksDao.create(
        questionIds: ids,
        timed: false,
        startedAt: DateTime(2026, 10, 12, 18),
      );
      await db.mocksDao.saveFlagged(started, [for (final i in marks) ids[i]]);
      return started;
    }

    test('the marks of an open mock go to another phone and come back '
        'in the same file', () async {
      final a = await app();
      final id = await startMockWithMarks(a);
      final before = (await a.read(appDatabaseProvider).mocksDao.byId(id))!;
      expect(before.flagged, hasLength(2));

      final transferA = a.read(progressTransferProvider);
      final bytes = (await transferA.buildExport()).bytes;
      expect(
        ((jsonDecode(utf8.decode(bytes)) as Map)['mocks'] as List).single
            as Map,
        containsPair('flagged', before.flagged),
      );

      final b = await app();
      final transferB = b.read(progressTransferProvider);
      await transferB.apply(await transferB.preview(bytes));
      final after = (await b.read(appDatabaseProvider).mocksDao.byId(id))!;
      expect(after.flagged, before.flagged);
      expect(after.finishedAt, isNull);

      // Exporting again gives the same marks.
      final again = (await transferB.buildExport()).bytes;
      expect(
        ((jsonDecode(utf8.decode(again)) as Map)['mocks'] as List).single
            as Map,
        containsPair('flagged', before.flagged),
      );
    });

    test('import replaces a local finished mock with the file state', () async {
      final a = await app();
      final id = await startMockWithMarks(a, marks: [2, 11]);
      final bytes =
          (await a.read(progressTransferProvider).buildExport()).bytes;

      // The same mock on phone b (it is b's free mock), handed in, with
      // other marks.
      final b = await app();
      expect(await startMockWithMarks(b, marks: [5]), id);
      final db = b.read(appDatabaseProvider);
      await db.mocksDao.finish(
        id,
        answers: List<int?>.filled(20, 0),
        correctCount: 0,
        passed: false,
        passMark: 16,
        finishedAt: DateTime(2026, 10, 12, 19),
      );
      final transfer = b.read(progressTransferProvider);
      await transfer.apply(await transfer.preview(bytes));

      final after = (await db.mocksDao.byId(id))!;
      expect(after.finishedAt, isNull);
      expect(after.flagged, hasLength(2));
      expect(after.answers, everyElement(isNull));
    });

    test('importing an older file clears the marks along with the rest of '
        'the progress', () async {
      final a = await app();
      await startMockWithMarks(a);
      final bytes =
          (await a.read(progressTransferProvider).buildExport()).bytes;
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      for (final m in json['mocks'] as List) {
        (m as Map).remove('flagged');
      }

      final b = await app();
      final id = await startMockWithMarks(b, skip: 30);
      expect(
        (await b.read(appDatabaseProvider).mocksDao.byId(id))!.flagged,
        isNotEmpty,
      );
      final transfer = b.read(progressTransferProvider);
      await transfer.apply(await transfer.preview(_bytes(json)));
      expect(
        (await b.read(appDatabaseProvider).mocksDao.byId(id))!.flagged,
        isEmpty,
      );
    });
  });
}
