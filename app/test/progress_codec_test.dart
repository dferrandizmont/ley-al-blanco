import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/features/progress_transfer/domain/progress_codec.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_snapshot.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

/// 20 Oct 2026, 10:00 (local).
final DateTime _now = DateTime(2026, 10, 20, 10);

/// The bank of these tests: question id -> number of options and official
/// answer (option 0 everywhere).
const Map<String, BankQuestion> _bank = {
  't1-001': (options: 3, answer: 0),
  't1-002': (options: 3, answer: 0),
  't2-001': (options: 3, answer: 0),
};

ProgressSnapshot _snapshot({
  List<Attempt>? attempts,
  List<SrsEntry>? srs,
  List<MockEntry>? mocks,
  ProgressSettings settings = const ProgressSettings(themeMode: 'dark'),
}) => ProgressSnapshot(
  edition: 'GC-2020-11',
  exportedAt: DateTime(2026, 10, 20, 9, 30, 15, 250),
  appVersion: '0.5.0',
  attempts:
      attempts ??
      [
        Attempt(
          questionId: 't1-001',
          mode: AttemptMode.practice,
          selected: 2,
          correct: true,
          answeredAt: DateTime(2026, 10, 14, 18, 0, 1, 123),
          elapsedMs: 4200,
        ),
        Attempt(
          questionId: 't1-002',
          mode: AttemptMode.mock,
          selected: null,
          correct: false,
          answeredAt: DateTime(2026, 10, 15, 18, 5),
          mockId: 7,
        ),
      ],
  srs:
      srs ??
      [
        SrsEntry(
          questionId: 't1-001',
          box: 2,
          dueAt: DateTime(2026, 10, 16, 10),
          reps: 1,
          lapses: 0,
          lastAnsweredAt: DateTime(2026, 10, 14, 18),
        ),
      ],
  mocks:
      mocks ??
      [
        MockEntry(
          id: 7,
          startedAt: DateTime(2026, 10, 15, 18),
          finishedAt: DateTime(2026, 10, 15, 18, 30),
          questionIds: const ['t1-001', 't1-002'],
          answers: const [0, null],
          correctCount: 1,
          passed: false,
          timed: true,
          passMark: 2,
        ),
      ],
  settings: settings,
);

Map<String, dynamic> _json([ProgressSnapshot? s]) =>
    jsonDecode(utf8.decode(ProgressCodec.encode(s ?? _snapshot())))
        as Map<String, dynamic>;

Uint8List _bytes(Map<String, dynamic> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

/// The fixtures here are 2-question mocks on a tiny bank, so the "exam size"
/// they parse with is 2 (the real one, 20, is tested on its own below).
const int _fixtureMockSize = 2;

ProgressSnapshot _parse(
  Map<String, dynamic> json, {
  int mockSize = _fixtureMockSize,
}) => ProgressCodec.parse(_bytes(json), now: _now, mockSize: mockSize);

ProgressImportException _failure(
  Map<String, dynamic> json, {
  Uint8List? bytes,
  int mockSize = _fixtureMockSize,
}) {
  try {
    ProgressCodec.parse(bytes ?? _bytes(json), now: _now, mockSize: mockSize);
  } on ProgressImportException catch (e) {
    return e;
  }
  fail('the file was accepted');
}

void main() {
  group('ISO 8601 offsets', () {
    for (final offset in ['+24:00', '-24:00', '+01:60', '+9960']) {
      test('refuses an invalid offset $offset instead of normalizing it', () {
        final json = _json()..['exported_at'] = '2026-10-15T10:00:00$offset';
        expect(_failure(json).error, ProgressImportError.invalidDateTime);
      });
    }
    for (final offset in ['+02:00', '+0200']) {
      test('accepts a valid explicit offset $offset', () {
        final json = _json()..['exported_at'] = '2026-10-15T10:00:00$offset';
        expect(_parse(json).exportedAt.toUtc(), DateTime.utc(2026, 10, 15, 8));
      });
    }
  });

  group('encode', () {
    test('writes the documented shape and only that', () {
      final json = _json();
      expect(json.keys, [
        'format',
        'version',
        'edition',
        'exported_at',
        'app_version',
        'attempts',
        'srs',
        'mocks',
        'settings',
      ]);
      expect(json['format'], 'apto-armas-progress');
      expect(json['version'], 1);
      expect(json['edition'], 'GC-2020-11');
      expect(json['app_version'], '0.5.0');
      // ISO 8601, UTC, milliseconds kept.
      expect(json['exported_at'], matches(RegExp(r'^\d{4}-\d\d-\d\dT.*Z$')));
      final first = (json['attempts'] as List).first as Map<String, dynamic>;
      expect(first.keys, [
        'question_id',
        'mode',
        'selected',
        'correct',
        'answered_at',
        'mock_id',
        'elapsed_ms',
      ]);
      expect(first['answered_at'], endsWith('.123Z'));
      expect(json['settings'], {'theme_mode': 'dark'});
    });

    test('dates carry exactly milliseconds, also when the app had '
        'microseconds', () {
      final json = _json(
        _snapshot(
          attempts: [
            Attempt(
              questionId: 't1-001',
              mode: AttemptMode.practice,
              selected: 2,
              correct: true,
              answeredAt: DateTime(2026, 10, 14, 18, 0, 1, 123, 456),
            ),
          ],
        ),
      );
      final fraction = RegExp(r'\.\d+Z$');
      final answeredAt =
          ((json['attempts'] as List).first as Map)['answered_at'] as String;
      expect(answeredAt, endsWith('.123Z'));
      expect(fraction.firstMatch(answeredAt)!.group(0), hasLength(5));
      expect(
        (json['exported_at'] as String),
        matches(RegExp(r'T\d\d:\d\d:\d\d\.\d{3}Z$')),
      );
    });

    test('never carries anything about purchases', () {
      final text = utf8.decode(ProgressCodec.encode(_snapshot()));
      expect(text, isNot(contains('entitlement')));
      expect(text, isNot(contains('purchase')));
      expect(text, isNot(contains('revenuecat')));
    });

    test('is one line of UTF-8 JSON ending in a newline', () {
      final bytes = ProgressCodec.encode(_snapshot());
      final text = utf8.decode(bytes);
      expect(text.endsWith('}\n'), isTrue);
      expect('\n'.allMatches(text), hasLength(1));
    });
  });

  group('parse: what is accepted', () {
    test('round trip keeps every value (dates to the millisecond)', () {
      final original = _snapshot();
      final back = ProgressCodec.parse(
        ProgressCodec.encode(original),
        now: _now,
        mockSize: _fixtureMockSize,
      );
      expect(back.edition, original.edition);
      expect(back.appVersion, original.appVersion);
      expect(back.exportedAt, original.exportedAt);
      expect(back.attempts, original.attempts);
      expect(back.attempts.first.answeredAt.millisecond, 123);
      expect(back.srs.single.questionId, 't1-001');
      expect(back.srs.single.box, 2);
      expect(back.srs.single.dueAt, DateTime(2026, 10, 16, 10));
      final mock = back.mocks.single;
      expect(mock.id, 7);
      expect(mock.questionIds, ['t1-001', 't1-002']);
      expect(mock.answers, [0, null]);
      expect(mock.correctCount, 1);
      expect(mock.passed, isFalse);
      expect(mock.timed, isTrue);
      expect(mock.passMark, 2);
      expect(back.settings.themeMode, 'dark');
      // Re-encoding the parsed file gives the same bytes.
      expect(ProgressCodec.encode(back), ProgressCodec.encode(original));
    });

    test('an empty progress is valid', () {
      final s = _snapshot(attempts: [], srs: [], mocks: []);
      final back = ProgressCodec.parse(ProgressCodec.encode(s), now: _now);
      expect(back.attempts, isEmpty);
      expect(back.srs, isEmpty);
      expect(back.mocks, isEmpty);
    });

    test('an unfinished mock round-trips', () {
      final s = _snapshot(
        attempts: [],
        srs: [],
        mocks: [
          MockEntry(
            id: 3,
            startedAt: DateTime(2026, 10, 15, 18),
            questionIds: const ['t1-001'],
            answers: const [null],
            timed: false,
          ),
        ],
      );
      final back = ProgressCodec.parse(
        ProgressCodec.encode(s),
        now: _now,
        mockSize: 1,
      );
      expect(back.mocks.single.isFinished, isFalse);
      expect(back.mocks.single.correctCount, isNull);
    });

    test('a missing settings block means defaults; a BOM is tolerated', () {
      final json = _json()..remove('settings');
      final back = _parse(json);
      expect(back.settings.themeMode, isNull);
      final withBom = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ..._bytes(_json()),
      ]);
      expect(
        ProgressCodec.parse(
          withBom,
          now: _now,
          mockSize: _fixtureMockSize,
        ).attempts,
        hasLength(2),
      );
    });

    test('extra fields are ignored, never read', () {
      final json = _json()
        ..['entitlement'] = 'full'
        ..['whatever'] = {'a': 1};
      (json['settings'] as Map<String, dynamic>)['entitlement'] = 'full';
      final back = _parse(json);
      expect(back.attempts, hasLength(2));
    });
  });

  group('parse: what is refused', () {
    test('a file over the size limit, before reading it', () {
      final big = Uint8List(kMaxProgressFileBytes + 1);
      final e = _failure({}, bytes: big);
      expect(e.error, ProgressImportError.tooLarge);
      // Exactly at the limit is judged by its content (here: not JSON).
      final ok = Uint8List(kMaxProgressFileBytes);
      expect(_failure({}, bytes: ok).error, ProgressImportError.notJson);
    });

    test('corrupt, truncated, empty and non-object files', () {
      final good = ProgressCodec.encode(_snapshot());
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList(utf8.encode('esto no es json')),
        good.sublist(0, good.length ~/ 2),
        Uint8List.fromList([0xFF, 0xFE, 0x00, 0xC3, 0x28]), // not UTF-8
        Uint8List.fromList(utf8.encode('[1,2,3]')),
        Uint8List.fromList(utf8.encode('"texto"')),
        Uint8List.fromList(utf8.encode('null')),
      ]) {
        expect(
          _failure({}, bytes: bytes).error,
          ProgressImportError.notJson,
          reason: '${bytes.length} bytes',
        );
      }
    });

    test('another format', () {
      expect(
        _failure({'format': 'otra-app', 'version': 1}).error,
        ProgressImportError.wrongFormat,
      );
      expect(_failure({}).error, ProgressImportError.wrongFormat);
      expect(
        _failure(_json()..['format'] = null).error,
        ProgressImportError.wrongFormat,
      );
    });

    test('a newer version is told apart from a broken one', () {
      expect(
        _failure(_json()..['version'] = 2).error,
        ProgressImportError.newerVersion,
      );
      for (final bad in [0, -1, '1', 1.0, null, true]) {
        expect(
          _failure(_json()..['version'] = bad).error,
          ProgressImportError.invalid,
          reason: '$bad',
        );
      }
    });

    // Each case edits a valid file; malformed dates must yield
    // `invalidDateTime`, other fields `invalid`. Both errors name the field.
    final cases = <String, (void Function(Map<String, dynamic>), String)>{
      'edition missing': ((j) => j.remove('edition'), 'edition'),
      'edition not text': ((j) => j['edition'] = 5, 'edition'),
      'exported_at not a date': (
        (j) => j['exported_at'] = 'ayer',
        'exported_at',
      ),
      'exported_at without time': (
        (j) => j['exported_at'] = '2026-10-20',
        'exported_at',
      ),
      'date that does not exist': (
        (j) => _attempt(j)['answered_at'] = '2026-02-30T10:00:00Z',
        'answered_at',
      ),
      'attempts not a list': ((j) => j['attempts'] = {}, 'attempts'),
      'attempt not an object': ((j) => j['attempts'] = [1], 'attempts[0]'),
      'attempt unknown mode': ((j) => _attempt(j)['mode'] = 'cheat', 'mode'),
      'selected as text': ((j) => _attempt(j)['selected'] = '2', 'selected'),
      'selected as a decimal': (
        (j) => _attempt(j)['selected'] = 1.5,
        'selected',
      ),
      'selected negative': ((j) => _attempt(j)['selected'] = -1, 'selected'),
      'selected huge': ((j) => _attempt(j)['selected'] = 10, 'selected'),
      'correct as a number': ((j) => _attempt(j)['correct'] = 1, 'correct'),
      'blank answer marked right': (
        (j) {
          _attempt(j)['selected'] = null;
          _attempt(j)['correct'] = true;
        },
        'correct',
      ),
      'question id empty': ((j) => _attempt(j)['question_id'] = '', 'question'),
      'question id not text': (
        (j) => _attempt(j)['question_id'] = 5,
        'question_id',
      ),
      'question id enormous': (
        (j) => _attempt(j)['question_id'] = 'x' * 65,
        'question_id',
      ),
      'elapsed as text': ((j) => _attempt(j)['elapsed_ms'] = '5', 'elapsed'),
      'mock_id zero': ((j) => _attempt(j)['mock_id'] = 0, 'mock_id'),
      'mock_id above 2^53': (
        (j) => _attempt(j)['mock_id'] = 9007199254740992,
        'mock_id',
      ),
      'mock id above 2^53': (
        (j) => _mock(j)['id'] = 9007199254740992,
        'mocks[0].id',
      ),
      'mock_id pointing nowhere': (
        (j) => _attempt(j)['mock_id'] = 99,
        'no mock 99',
      ),
      'srs box 0': ((j) => _srs(j)['box'] = 0, 'box'),
      'srs box 6': ((j) => _srs(j)['box'] = 6, 'box'),
      'srs negative reps': ((j) => _srs(j)['reps'] = -1, 'reps'),
      'srs lapses as text': ((j) => _srs(j)['lapses'] = '0', 'lapses'),
      'srs repeated card': (
        (j) => (j['srs'] as List).add(Map.of(_srs(j))),
        'repeated card',
      ),
      'mock repeated id': (
        (j) => (j['mocks'] as List).add(Map.of(_mock(j))),
        'repeated mock',
      ),
      'mock answers shorter than questions': (
        (j) => _mock(j)['answers'] = [0],
        'answers',
      ),
      'mock answer out of range': (
        (j) => _mock(j)['answers'] = [0, 12],
        'answers[1]',
      ),
      'mock question twice': (
        (j) => _mock(j)['question_ids'] = ['t1-001', 't1-001'],
        'twice',
      ),
      'mock without questions': (
        (j) {
          _mock(j)['question_ids'] = [];
          _mock(j)['answers'] = [];
        },
        'question_ids',
      ),
      'finished mock without result': (
        (j) => _mock(j)['passed'] = null,
        'finished mock',
      ),
      'unfinished mock with result': (
        (j) => _mock(j)['finished_at'] = null,
        'unfinished',
      ),
      'correct_count above the questions': (
        (j) => _mock(j)['correct_count'] = 3,
        'correct_count',
      ),
      'timed not a bool': ((j) => _mock(j)['timed'] = 'si', 'timed'),
      'settings not an object': ((j) => j['settings'] = [], 'settings'),
      'unknown theme': (
        (j) => (j['settings'] as Map)['theme_mode'] = 'sepia',
        'theme_mode',
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final json = _json();
        entry.value.$1(json);
        final e = _failure(json);
        expect(
          e.error,
          entry.value.$2.contains('_at')
              ? ProgressImportError.invalidDateTime
              : ProgressImportError.invalid,
        );
        expect(e.detail, contains(entry.value.$2));
      });
    }

    test('another bank edition, with its own error', () {
      final e = _failure(_json()..['edition'] = 'GC-2019-01');
      expect(e.error, ProgressImportError.wrongEdition);
      expect(e.detail, contains('GC-2019-01'));
      // The edition the caller expects is the one that counts.
      final ok = ProgressCodec.parse(
        _bytes(_json()..['edition'] = 'GC-2019-01'),
        now: _now,
        edition: 'GC-2019-01',
        mockSize: _fixtureMockSize,
      );
      expect(ok.edition, 'GC-2019-01');
    });

    test('nesting deeper than 8 levels, before decoding', () {
      final deep = '${'[' * 9}${']' * 9}';
      final e = _failure({}, bytes: Uint8List.fromList(utf8.encode(deep)));
      expect(e.error, ProgressImportError.tooDeep);
      expect(e.detail, contains('nested'));
      // Brackets inside strings do not count, and 8 levels are fine.
      final shallow = _json()..['app_version'] = '[[[[[[[[[[[[{{{{{{{{{';
      expect(_parse(shallow).attempts, hasLength(2));
      final text = utf8.encode('${'[' * 8}${']' * 8}');
      expect(
        _failure({}, bytes: Uint8List.fromList(text)).error,
        ProgressImportError.notJson,
        reason: '8 levels pass the scan and fail later: not an object',
      );
    });

    test('the real file nests 4 levels at most', () {
      final text = utf8.decode(ProgressCodec.encode(_snapshot()));
      var depth = 0;
      var deepest = 0;
      for (final c in text.split('')) {
        if (c == '[' || c == '{') deepest = ++depth > deepest ? depth : deepest;
        if (c == ']' || c == '}') depth--;
      }
      expect(deepest, lessThanOrEqualTo(kMaxProgressNesting));
    });

    test('too many items', () {
      final json = _json();
      json['srs'] = List.filled(ProgressCodec.maxSrs + 1, <String, dynamic>{});
      final e = _failure(json);
      expect(e.error, ProgressImportError.invalid);
      expect(e.detail, contains('more than'));
    });
  });

  group('a wrong clock does not block the import', () {
    test('an impossible duration becomes null, a wrong type still fails', () {
      for (final bad in [-5, 90000000, 1 << 40]) {
        final json = _json();
        _attempt(json)['elapsed_ms'] = bad;
        expect(_parse(json).attempts.first.elapsedMs, isNull, reason: '$bad');
      }
      final ok = _json();
      _attempt(ok)['elapsed_ms'] = 0;
      expect(_parse(ok).attempts.first.elapsedMs, 0);
      final wrong = _json();
      _attempt(wrong)['elapsed_ms'] = 'mucho';
      expect(_failure(wrong).error, ProgressImportError.invalid);
    });

    test('an attempt dated outside 2020..tomorrow is skipped and counted', () {
      for (final bad in ['2015-01-01T00:00:00Z', '2031-01-01T00:00:00Z']) {
        final json = _json();
        _attempt(json)['answered_at'] = bad;
        final snap = _parse(json);
        expect(snap.attempts, hasLength(1), reason: bad);
        expect(snap.skippedAttempts, 1, reason: bad);
      }
      // Tomorrow is still fine (a phone a few hours ahead).
      final json = _json();
      _attempt(json)['answered_at'] = '2026-10-21T08:00:00Z';
      expect(_parse(json).skippedAttempts, 0);
    });

    test('a card with a due date outside 2020..2100 is skipped', () {
      final json = _json();
      _srs(json)['due_at'] = '3000-01-01T00:00:00Z';
      final snap = _parse(json);
      expect(snap.srs, isEmpty);
      expect(snap.skippedSrs, 1);
      final lastAnswered = _json();
      _srs(lastAnswered)['last_answered_at'] = '2031-01-01T00:00:00Z';
      expect(_parse(lastAnswered).skippedSrs, 1);
    });

    test('a mock finished before it started finishes when it started', () {
      final json = _json();
      _mock(json)['finished_at'] = '2026-10-14T00:00:00Z';
      final mock = _parse(json).mocks.single;
      expect(mock.finishedAt, mock.startedAt);
      expect(mock.isFinished, isTrue);
    });

    test('a mock with an impossible date goes with its attempts', () {
      final json = _json();
      _mock(json)['started_at'] = '2015-01-01T00:00:00Z';
      final snap = _parse(json);
      expect(snap.mocks, isEmpty);
      expect(snap.skippedMocks, 1);
      // The attempt of that mock (and nothing else) goes with it.
      expect(snap.attempts.map((a) => a.questionId), ['t1-001']);
      expect(snap.skippedAttempts, 1);
      final plan = ProgressCodec.reconcile(snap, _bank);
      expect(plan.discardedMocks, 1);
      expect(plan.discardedAttempts, 1);
      expect(plan.discardedTotal, 2);
    });

    test('a wrong export date falls back to now', () {
      final json = _json()..['exported_at'] = '2031-01-01T00:00:00Z';
      expect(_parse(json).exportedAt, _now);
    });

    test('a mock id up to 2^53 - 1 is fine and stays linked', () {
      final json = _json();
      _mock(json)['id'] = 9007199254740991;
      _attempt(json)['mock_id'] = null;
      ((json['attempts'] as List)[1] as Map)['mock_id'] = 9007199254740991;
      final snap = _parse(json);
      expect(snap.mocks.single.id, 9007199254740991);
      expect(snap.attempts.last.mockId, 9007199254740991);
    });

    test('encode holds the dates and durations a file can carry', () {
      final snap = _snapshot(
        attempts: [
          Attempt(
            questionId: 't1-001',
            mode: AttemptMode.practice,
            selected: 0,
            correct: true,
            answeredAt: DateTime(2019, 5, 1),
            elapsedMs: -3,
          ),
          Attempt(
            questionId: 't1-001',
            mode: AttemptMode.practice,
            selected: 0,
            correct: true,
            answeredAt: DateTime(2030, 5, 1),
            elapsedMs: ProgressCodec.maxElapsedMs + 1,
          ),
        ],
        srs: [
          SrsEntry(
            questionId: 't1-001',
            box: 1,
            dueAt: DateTime(2200),
            reps: 1,
            lapses: 0,
          ),
        ],
        mocks: [
          MockEntry(
            id: 7,
            startedAt: DateTime(2026, 10, 15, 18),
            finishedAt: DateTime(2026, 10, 15, 17),
            questionIds: const ['t1-001'],
            answers: const [0],
            correctCount: 1,
            passed: true,
            timed: false,
            passMark: 1,
          ),
        ],
      );
      final json = _json(snap);
      final attempts = (json['attempts'] as List).cast<Map<String, dynamic>>();
      expect(attempts[0]['answered_at'], '2020-01-01T00:00:00.000Z');
      expect(attempts[0]['elapsed_ms'], isNull);
      // Tomorrow of the export date at most.
      expect(
        DateTime.parse(attempts[1]['answered_at'] as String),
        DateTime(2026, 10, 21, 9, 30, 15, 250).toUtc(),
      );
      expect(attempts[1]['elapsed_ms'], isNull);
      expect(_srs(json)['due_at'], '2100-01-01T00:00:00.000Z');
      final mock = _mock(json);
      expect(mock['finished_at'], mock['started_at']);
      // And all of it imports back without skipping a thing.
      final back = _parse(json, mockSize: 1);
      expect(back.skippedAttempts + back.skippedSrs + back.skippedMocks, 0);
    });
  });

  group('the composition of a mock', () {
    /// A file whose only mock has [n] questions (and as many answers unless
    /// [answers] says otherwise), written by hand.
    Map<String, dynamic> fileWith(int n, {int? answers, List<String>? ids}) {
      final json = _json();
      final mock = _mock(json);
      mock['question_ids'] = ids ?? [for (var i = 0; i < n; i++) 'q-$i'];
      mock['answers'] = List<int?>.filled(answers ?? n, null);
      mock['correct_count'] = 0;
      mock['pass_mark'] = 1;
      return json;
    }

    test('the exam size (20) is what the codec asks for by default', () {
      final ok = ProgressCodec.parse(_bytes(fileWith(20)), now: _now);
      expect(ok.mocks.single.questionIds, hasLength(20));
    });

    test('200, 21, 19, 2 and 0 questions are refused with the default '
        'size', () {
      for (final n in [200, 21, 19, 2, 0]) {
        final e = _failure(fileWith(n), mockSize: 20);
        expect(e.error, ProgressImportError.invalid, reason: '$n');
        expect(e.detail, contains('mocks[0].question_ids'), reason: '$n');
        expect(e.detail, contains('exactly 20'), reason: '$n');
      }
    });

    test('the size comes from the manifest: another exam size is honoured', () {
      expect(
        ProgressCodec.parse(
          _bytes(fileWith(30)),
          now: _now,
          mockSize: 30,
        ).mocks.single.questionIds,
        hasLength(30),
      );
      expect(
        _failure(fileWith(20), mockSize: 30).error,
        ProgressImportError.invalid,
      );
    });

    test('a repeated question is refused even at the right size', () {
      final ids = [for (var i = 0; i < 19; i++) 'q-$i', 'q-0'];
      final e = _failure(fileWith(20, ids: ids), mockSize: 20);
      expect(e.error, ProgressImportError.invalid);
      expect(e.detail, contains('twice'));
    });

    test('answers must be as many as the questions', () {
      for (final answers in [19, 21, 0]) {
        final e = _failure(fileWith(20, answers: answers), mockSize: 20);
        expect(e.error, ProgressImportError.invalid, reason: '$answers');
        expect(e.detail, contains('mocks[0].answers'), reason: '$answers');
      }
    });

    test('an unfinished mock is held to the same size', () {
      final json = fileWith(5)
        ..['mocks'] = [
          {
            ..._mock(fileWith(5)),
            'finished_at': null,
            'correct_count': null,
            'passed': null,
          },
        ];
      expect(_failure(json, mockSize: 20).error, ProgressImportError.invalid);
    });
  });

  group('reconcile', () {
    test('keeps everything when the bank knows every question', () {
      final plan = ProgressCodec.reconcile(_snapshot(), _bank);
      expect(plan.discardedTotal, 0);
      expect(plan.snapshot.attempts, hasLength(2));
      expect(plan.snapshot.srs, hasLength(1));
      expect(plan.snapshot.mocks, hasLength(1));
    });

    test('drops and counts what refers to unknown questions', () {
      final snap = _snapshot(
        attempts: [
          _attemptOn('t1-001'),
          _attemptOn('t9-999'),
          _attemptOn('t9-998'),
        ],
        srs: [
          SrsEntry(
            questionId: 't1-001',
            box: 1,
            dueAt: DateTime(2026, 10, 16),
            reps: 1,
            lapses: 0,
          ),
          SrsEntry(
            questionId: 'zzz',
            box: 1,
            dueAt: DateTime(2026, 10, 16),
            reps: 1,
            lapses: 0,
          ),
        ],
        mocks: [],
      );
      final plan = ProgressCodec.reconcile(snap, _bank);
      expect(plan.snapshot.attempts.map((a) => a.questionId), ['t1-001']);
      expect(plan.snapshot.srs.map((c) => c.questionId), ['t1-001']);
      expect(plan.discardedAttempts, 2);
      expect(plan.discardedSrs, 1);
      expect(plan.discardedMocks, 0);
      expect(plan.discardedTotal, 3);
    });

    test('a mock with an unknown question goes with its attempts', () {
      final snap = _snapshot(
        attempts: [
          _attemptOn('t1-001', mockId: 7),
          _attemptOn('t1-002', mockId: 7),
          _attemptOn('t1-002'),
        ],
        srs: [],
        mocks: [
          MockEntry(
            id: 7,
            startedAt: DateTime(2026, 10, 15, 18),
            questionIds: const ['t1-001', 't9-999'],
            answers: const [0, 1],
            timed: false,
          ),
        ],
      );
      final plan = ProgressCodec.reconcile(snap, _bank);
      expect(plan.snapshot.mocks, isEmpty);
      expect(plan.discardedMocks, 1);
      expect(plan.snapshot.attempts, hasLength(1));
      expect(plan.snapshot.attempts.single.mockId, isNull);
      expect(plan.discardedAttempts, 2);
    });

    test('correct is recomputed from the selected option and the bank', () {
      final snap = _snapshot(
        attempts: [
          // Claims right, picked a wrong option.
          _attemptOn('t1-001', selected: 2).copyForTest(correct: true),
          // Claims wrong, picked the official answer.
          _attemptOn('t1-002').copyForTest(correct: false),
          // Blank stays wrong.
          Attempt(
            questionId: 't2-001',
            mode: AttemptMode.mock,
            selected: null,
            correct: false,
            answeredAt: DateTime(2026, 10, 15, 18),
            mockId: 7,
          ),
        ],
        srs: [],
        mocks: [
          MockEntry(
            id: 7,
            startedAt: DateTime(2026, 10, 15, 18),
            questionIds: const ['t2-001'],
            answers: const [null],
            timed: false,
          ),
        ],
      );
      final plan = ProgressCodec.reconcile(snap, _bank);
      expect(plan.snapshot.attempts.map((a) => a.correct), [
        false,
        true,
        false,
      ]);
      expect(plan.discardedTotal, 0);
    });

    test('a finished mock is rescored with the bank and its pass mark', () {
      MockEntry mock({int? passMark, bool passed = false}) => MockEntry(
        id: 1,
        startedAt: DateTime(2026, 10, 15, 18),
        finishedAt: DateTime(2026, 10, 15, 18, 30),
        questionIds: const ['t1-001', 't1-002', 't2-001'],
        // Right, wrong, blank.
        answers: const [0, 1, null],
        correctCount: 3, // a lie
        passed: passed,
        timed: false,
        passMark: passMark,
      );
      MockEntry rescored(MockEntry m) => ProgressCodec.reconcile(
        _snapshot(attempts: [], srs: [], mocks: [m]),
        _bank,
      ).snapshot.mocks.single;

      final low = rescored(mock(passMark: 2, passed: true));
      expect(low.correctCount, 1);
      expect(low.passed, isFalse, reason: '1 < 2');
      final high = rescored(mock(passMark: 1));
      expect(high.correctCount, 1);
      expect(high.passed, isTrue, reason: '1 >= 1');
      // No pass mark in the file: the count is recomputed, the verdict kept.
      final unknown = rescored(mock(passed: true));
      expect(unknown.correctCount, 1);
      expect(unknown.passed, isTrue);
      expect(unknown.passMark, isNull);
    });

    test('an unfinished mock is left as it is', () {
      final m = MockEntry(
        id: 1,
        startedAt: DateTime(2026, 10, 15, 18),
        questionIds: const ['t1-001'],
        answers: const [0],
        timed: false,
      );
      final out = ProgressCodec.reconcile(
        _snapshot(attempts: [], srs: [], mocks: [m]),
        _bank,
      ).snapshot.mocks.single;
      expect(out.isFinished, isFalse);
      expect(out.correctCount, isNull);
      expect(out.passed, isNull);
    });

    test('an option that the question does not have is refused', () {
      final snap = _snapshot(
        attempts: [_attemptOn('t1-001', selected: 3)],
        srs: [],
        mocks: [],
      );
      expect(
        () => ProgressCodec.reconcile(snap, _bank),
        throwsA(
          isA<ProgressImportException>().having(
            (e) => e.error,
            'error',
            ProgressImportError.invalid,
          ),
        ),
      );
      final mock = _snapshot(
        attempts: [],
        srs: [],
        mocks: [
          MockEntry(
            id: 1,
            startedAt: DateTime(2026, 10, 15, 18),
            questionIds: const ['t1-001'],
            answers: const [5],
            timed: false,
          ),
        ],
      );
      expect(
        () => ProgressCodec.reconcile(mock, _bank),
        throwsA(isA<ProgressImportException>()),
      );
    });
  });
}

extension on Attempt {
  Attempt copyForTest({required bool correct}) => Attempt(
    questionId: questionId,
    mode: mode,
    selected: selected,
    correct: correct,
    answeredAt: answeredAt,
    mockId: mockId,
    elapsedMs: elapsedMs,
  );
}

Attempt _attemptOn(String id, {int? mockId, int selected = 0}) => Attempt(
  questionId: id,
  mode: mockId == null ? AttemptMode.practice : AttemptMode.mock,
  selected: selected,
  correct: selected == 0,
  answeredAt: DateTime(2026, 10, 15, 18),
  mockId: mockId,
);

Map<String, dynamic> _attempt(Map<String, dynamic> json) =>
    (json['attempts'] as List).first as Map<String, dynamic>;

Map<String, dynamic> _srs(Map<String, dynamic> json) =>
    (json['srs'] as List).first as Map<String, dynamic>;

Map<String, dynamic> _mock(Map<String, dynamic> json) =>
    (json['mocks'] as List).first as Map<String, dynamic>;
