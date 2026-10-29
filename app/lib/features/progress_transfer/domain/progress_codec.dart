import 'dart:convert';
import 'dart:typed_data';

import '../../content/content_constants.dart';
import '../../mock/domain/mock_config.dart';
import '../../quiz/domain/attempt.dart';
import 'progress_snapshot.dart';

/// The progress file: one JSON object (`apto-armas-progress`, version 1).
///
/// ```json
/// {
///   "format": "apto-armas-progress", "version": 1,
///   "edition": "GC-2020-11", "exported_at": "2026-10-20T08:00:00.000Z",
///   "app_version": "0.5.0",
///   "attempts": [{"question_id": "t1-001", "mode": "practice", "selected": 2,
///                 "correct": true, "answered_at": "...Z", "mock_id": null,
///                 "elapsed_ms": 4200}],
///   "srs": [{"question_id": "t1-001", "box": 2, "due_at": "...Z", "reps": 1,
///            "lapses": 0, "last_answered_at": "...Z"}],
///   "mocks": [{"id": 1, "started_at": "...Z", "finished_at": "...Z",
///              "question_ids": ["t1-001", ...], "answers": [2, null, ...],
///              "correct_count": 17, "passed": true, "timed": false,
///              "pass_mark": 16, "flagged": ["t1-004"]}],
///   "settings": {"theme_mode": "dark"}
/// }
/// ```
///
/// Each mock holds exactly the exam's size (20) of different questions and one
/// answer per question. All dates are ISO 8601 in UTC with milliseconds.
/// There is no entitlement,
/// store, account or device data in it, by design.
///
/// A phone with a wrong clock must still be able to migrate: an impossible
/// duration becomes `null`, a mock "finished before it started" finishes when
/// it started, and a record whose date is outside 2020..tomorrow is left out
/// and counted (never an error). Wrong *types* are still refused.
///
/// Both [encode] and [parse] are pure: the app runs them on another isolate.
class ProgressCodec {
  const ProgressCodec._();

  /// Oldest instant any date of the file may have (the app did not exist
  /// before).
  static final DateTime earliest = DateTime.utc(2020);

  /// Latest instant a *past* event may have, from [now]: a day of slack for
  /// a phone clock that was wrong.
  static DateTime latestPast(DateTime now) => now.add(const Duration(days: 1));

  /// Latest due date of a review card.
  static final DateTime latestDue = DateTime.utc(2100);

  static const int maxAttempts = 100000;
  static const int maxSrs = 5000;
  static const int maxMocks = 2000;

  /// Largest mock / attempt-mock id (2^53 - 1, the biggest whole number every
  /// JSON reader keeps exactly).
  static const int maxId = 9007199254740991;
  static const int maxQuestionIdLength = 64;
  static const int maxOptionIndex = 9;
  static const int maxElapsedMs = kMaxAttemptElapsedMs;
  static const int maxReps = 1000000;
  static const int maxBox = 5;

  // ------------------------------------------------------------------ encode

  /// The file bytes (UTF-8 JSON, one line and a final newline).
  ///
  /// Sanitizes what [parse] would skip, so a clock anomaly on the phone that
  /// wrote the file does not cost records on the phone that reads it: dates
  /// are held inside 2020..tomorrow (a due date inside 2020..2100), an
  /// impossible duration is written as `null`, and a mock never finishes
  /// before it started.
  static Uint8List encode(ProgressSnapshot s) {
    final latest = latestPast(s.exportedAt);
    String date(DateTime d, [DateTime? max]) =>
        _isoMs(_clampDate(d, max ?? latest));
    String? dateOrNull(DateTime? d, [DateTime? max]) =>
        d == null ? null : date(d, max);
    int? elapsed(int? ms) =>
        ms != null && ms >= 0 && ms <= maxElapsedMs ? ms : null;

    final map = <String, Object?>{
      'format': kProgressFormat,
      'version': kProgressVersion,
      'edition': s.edition,
      'exported_at': _isoMs(s.exportedAt),
      'app_version': s.appVersion,
      'attempts': [
        for (final a in s.attempts)
          {
            'question_id': a.questionId,
            'mode': a.mode.name,
            'selected': a.selected,
            'correct': a.correct,
            'answered_at': date(a.answeredAt),
            'mock_id': a.mockId,
            'elapsed_ms': elapsed(a.elapsedMs),
          },
      ],
      'srs': [
        for (final c in s.srs)
          {
            'question_id': c.questionId,
            'box': c.box,
            'due_at': date(c.dueAt, latestDue),
            'reps': c.reps,
            'lapses': c.lapses,
            'last_answered_at': dateOrNull(c.lastAnsweredAt),
          },
      ],
      'mocks': [
        for (final m in s.mocks)
          {
            'id': m.id,
            'started_at': date(m.startedAt),
            'finished_at': dateOrNull(_notBefore(m.finishedAt, m.startedAt)),
            'question_ids': m.questionIds,
            'answers': m.answers,
            'correct_count': m.correctCount,
            'passed': m.passed,
            'timed': m.timed,
            'pass_mark': m.passMark,
            'flagged': m.flagged,
          },
      ],
      'settings': {'theme_mode': s.settings.themeMode},
    };
    return Uint8List.fromList(utf8.encode('${jsonEncode(map)}\n'));
  }

  /// [d] as ISO 8601 in UTC with exactly milliseconds (`...:00.123Z`): a
  /// `DateTime` made by the app can carry microseconds, which the file format
  /// does not promise.
  static String _isoMs(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
    d.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();

  /// [d] held inside [earliest]..[max] (never inverted if [max] is older).
  static DateTime _clampDate(DateTime d, DateTime max) {
    final top = max.isBefore(earliest) ? earliest : max;
    if (d.isBefore(earliest)) return earliest;
    if (d.isAfter(top)) return top;
    return d;
  }

  /// [finished] or, when it is before [started], [started].
  static DateTime? _notBefore(DateTime? finished, DateTime started) =>
      finished != null && finished.isBefore(started) ? started : finished;

  // ------------------------------------------------------------------- parse

  /// Reads and validates a progress file **before anything is touched**.
  /// Throws [ProgressImportException] for anything that is not exactly a
  /// version-1 progress file of [edition]: too big, nested too deep, not
  /// JSON, another `format`, a newer version, another bank edition, a wrong
  /// type, a value out of range, a malformed date, a repeated id...
  ///
  /// What a clock anomaly breaks is not an error (see the class comment): the
  /// records with an impossible date are skipped and counted in the snapshot.
  ///
  /// Every mock must have exactly [mockSize] (the exam's size, from the
  /// manifest) different questions and one answer slot per question: the
  /// app only ever writes such mocks, and a file with any other shape is a
  /// fabrication, not an export.
  ///
  /// Unknown extra fields are ignored (never read, so they cannot do
  /// anything). This does not look at the question bank: see [reconcile].
  static ProgressSnapshot parse(
    Uint8List bytes, {
    required DateTime now,
    String edition = kContentEdition,
    int mockSize = MockConfig.defaultSize,
  }) {
    if (bytes.length > kMaxProgressFileBytes) {
      throw const ProgressImportException(ProgressImportError.tooLarge);
    }
    if (_nestingDepth(bytes) > kMaxProgressNesting) {
      throw const ProgressImportException(
        ProgressImportError.tooDeep,
        'nested more than $kMaxProgressNesting levels',
      );
    }
    final Object? decoded;
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('﻿')) text = text.substring(1);
      decoded = jsonDecode(text);
    } on FormatException {
      throw const ProgressImportException(ProgressImportError.notJson);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ProgressImportException(ProgressImportError.notJson);
    }
    final root = decoded;

    if (root['format'] != kProgressFormat) {
      throw const ProgressImportException(
        ProgressImportError.wrongFormat,
        'format',
      );
    }
    final version = root['version'];
    if (version is int && version > kProgressVersion) {
      throw ProgressImportException(
        ProgressImportError.newerVersion,
        'version $version',
      );
    }
    if (version is! int || version != kProgressVersion) {
      throw const ProgressImportException(
        ProgressImportError.invalid,
        'version',
      );
    }

    final p = _Reader(now);
    final fileEdition = p.string(root, 'edition', 'edition', maxLength: 64);
    if (fileEdition != edition) {
      throw ProgressImportException(
        ProgressImportError.wrongEdition,
        'edition $fileEdition, expected $edition',
      );
    }
    // The export date is only informative: a wrong clock is not a reason to
    // refuse the file.
    DateTime exportedAt;
    try {
      exportedAt = p.date(root, 'exported_at', 'exported_at');
    } on _OutOfRange {
      exportedAt = now;
    }
    final appVersion = p.string(
      root,
      'app_version',
      'app_version',
      maxLength: 64,
    );

    final attemptItems = p.list(root, 'attempts', 'attempts', maxAttempts);
    final attempts = <Attempt>[];
    var skippedAttempts = 0;
    for (final (i, raw) in attemptItems.indexed) {
      try {
        attempts.add(p.attempt(raw, i));
      } on _OutOfRange {
        skippedAttempts++;
      }
    }
    final srsItems = p.list(root, 'srs', 'srs', maxSrs);
    final srsSeen = <String>{};
    final srs = <SrsEntry>[];
    var skippedSrs = 0;
    for (final (i, raw) in srsItems.indexed) {
      try {
        srs.add(p.srsEntry(raw, i, srsSeen));
      } on _OutOfRange {
        skippedSrs++;
      }
    }
    final mockItems = p.list(root, 'mocks', 'mocks', maxMocks);
    final mockIds = <int>{};
    final skippedMockIds = <int>{};
    final mocks = <MockEntry>[];
    for (final (i, raw) in mockItems.indexed) {
      try {
        mocks.add(p.mock(raw, i, mockIds, skippedMockIds, mockSize));
      } on _OutOfRange {
        // Already noted in skippedMockIds by the reader.
      }
    }
    // An attempt of a mock needs that mock in the same file, handed in (the
    // app writes a mock's attempts when it hands it in, never before); one
    // whose mock was skipped for its dates goes with it.
    final unfinishedMockIds = {
      for (final mock in mocks)
        if (!mock.isFinished) mock.id,
    };
    final keptAttempts = <Attempt>[];
    for (final (i, a) in attempts.indexed) {
      final id = a.mockId;
      if (id != null && skippedMockIds.contains(id)) {
        skippedAttempts++;
        continue;
      }
      if (id != null && !mockIds.contains(id)) {
        throw ProgressImportException(
          ProgressImportError.invalid,
          'attempts[$i].mock_id: no mock $id in the file',
        );
      }
      if (id != null && unfinishedMockIds.contains(id)) {
        throw ProgressImportException(
          ProgressImportError.invalid,
          'attempts[$i].mock_id: mock $id is not handed in',
        );
      }
      keptAttempts.add(a);
    }
    final settings = p.settings(root['settings']);

    return ProgressSnapshot(
      edition: fileEdition,
      exportedAt: exportedAt,
      appVersion: appVersion,
      attempts: keptAttempts,
      srs: srs,
      mocks: mocks,
      settings: settings,
      skippedAttempts: skippedAttempts,
      skippedSrs: skippedSrs,
      skippedMocks: skippedMockIds.length,
    );
  }

  /// Deepest nesting of `[` and `{` outside strings, scanned on the bytes
  /// (UTF-8 never uses the bytes of these characters inside a multi-byte
  /// one). Cheap, and it runs before `jsonDecode` so a hostile file cannot
  /// make the decoder recurse deeply.
  static int _nestingDepth(Uint8List bytes) {
    var depth = 0;
    var deepest = 0;
    var inString = false;
    var escaped = false;
    for (final b in bytes) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (b == 0x5c) {
          escaped = true;
        } else if (b == 0x22) {
          inString = false;
        }
        continue;
      }
      switch (b) {
        case 0x22: // "
          inString = true;
        case 0x5b || 0x7b: // [ {
          depth++;
          if (depth > deepest) deepest = depth;
        case 0x5d || 0x7d: // ] }
          if (depth > 0) depth--;
      }
    }
    return deepest;
  }

  // --------------------------------------------------------------- reconcile

  /// Checks [snapshot] against the question bank ([bank]: question id -> its
  /// number of options and official answer, retired questions included) and
  /// drops what refers to a question that does not exist: its answers, its
  /// review card, and any mock that includes it (with the answers given in
  /// that mock).
  ///
  /// What the file *claims* about correctness is never trusted: each
  /// attempt's `correct` is recomputed from `selected` and the official
  /// answer, and a finished mock's `correct_count` and `passed` from its
  /// answers and its `pass_mark` (when the file has no pass mark, only the
  /// count is recomputed and `passed` is kept).
  ///
  /// Throws [ProgressImportException] when a selected option does not exist
  /// in a question that does.
  static ProgressImportPlan reconcile(
    ProgressSnapshot snapshot,
    Map<String, BankQuestion> bank,
  ) {
    // Mocks first: a dropped mock takes its answers with it.
    final keptMocks = <MockEntry>[];
    final droppedMockIds = <int>{};
    for (final (i, m) in snapshot.mocks.indexed) {
      if (m.questionIds.any((q) => !bank.containsKey(q))) {
        droppedMockIds.add(m.id);
        continue;
      }
      var right = 0;
      for (final (j, answer) in m.answers.indexed) {
        final question = bank[m.questionIds[j]]!;
        if (answer != null && answer >= question.options) {
          throw ProgressImportException(
            ProgressImportError.invalid,
            'mocks[$i].answers[$j]: option $answer does not exist',
          );
        }
        if (answer != null && answer == question.answer) right++;
      }
      final passMark = m.passMark;
      keptMocks.add(
        m.isFinished
            ? MockEntry(
                id: m.id,
                startedAt: m.startedAt,
                finishedAt: m.finishedAt,
                questionIds: m.questionIds,
                answers: m.answers,
                correctCount: right,
                passed: passMark == null ? m.passed : right >= passMark,
                timed: m.timed,
                passMark: passMark,
                flagged: m.flagged,
              )
            : m,
      );
    }

    final keptAttempts = <Attempt>[];
    var discardedAttempts = snapshot.skippedAttempts;
    for (final (i, a) in snapshot.attempts.indexed) {
      final question = bank[a.questionId];
      if (question == null ||
          (a.mockId != null && droppedMockIds.contains(a.mockId))) {
        discardedAttempts++;
        continue;
      }
      final selected = a.selected;
      if (selected != null && selected >= question.options) {
        throw ProgressImportException(
          ProgressImportError.invalid,
          'attempts[$i].selected: option $selected does not exist',
        );
      }
      final correct = selected != null && selected == question.answer;
      keptAttempts.add(
        correct == a.correct
            ? a
            : Attempt(
                questionId: a.questionId,
                mode: a.mode,
                selected: selected,
                correct: correct,
                answeredAt: a.answeredAt,
                mockId: a.mockId,
                elapsedMs: a.elapsedMs,
              ),
      );
    }

    final keptSrs = [
      for (final c in snapshot.srs)
        if (bank.containsKey(c.questionId)) c,
    ];

    return ProgressImportPlan(
      snapshot: ProgressSnapshot(
        edition: snapshot.edition,
        exportedAt: snapshot.exportedAt,
        appVersion: snapshot.appVersion,
        attempts: keptAttempts,
        srs: keptSrs,
        mocks: keptMocks,
        settings: snapshot.settings,
      ),
      discardedAttempts: discardedAttempts,
      discardedSrs: snapshot.skippedSrs + snapshot.srs.length - keptSrs.length,
      discardedMocks: snapshot.skippedMocks + droppedMockIds.length,
    );
  }
}

/// A well-formed date that is outside 2020..tomorrow (a wrong phone clock):
/// the record that holds it is skipped instead of failing the import.
class _OutOfRange implements Exception {
  const _OutOfRange();
}

/// Field readers with strict types; malformed dates fail with
/// [ProgressImportError.invalidDateTime], other invalid fields with
/// [ProgressImportError.invalid]. Both errors name the field; well-formed
/// dates outside the allowed range throw [_OutOfRange].
class _Reader {
  _Reader(this.now);

  final DateTime now;

  /// `2026-10-20T08:00:00.000Z` (seconds and the zone are optional in the
  /// text, the T is not).
  static final RegExp _isoDateTime = RegExp(
    r'^(\d{4})-(\d\d)-(\d\d)T([01]\d|2[0-3]):[0-5]\d(:[0-5]\d(\.\d{1,6})?)?'
    r'(Z|[+-](?:[01]\d|2[0-3]):?[0-5]\d)?$',
  );

  Never _fail(
    String where,
    String why, [
    ProgressImportError error = ProgressImportError.invalid,
  ]) => throw ProgressImportException(error, '$where: $why');

  Map<String, dynamic> object(Object? raw, String where) {
    if (raw is! Map<String, dynamic>) _fail(where, 'expected an object');
    return raw;
  }

  List<dynamic> list(
    Map<String, dynamic> map,
    String key,
    String where,
    int max,
  ) {
    final raw = map[key];
    if (raw is! List) _fail(where, 'expected a list');
    if (raw.length > max) _fail(where, 'more than $max items');
    return raw;
  }

  String string(
    Map<String, dynamic> map,
    String key,
    String where, {
    required int maxLength,
  }) {
    final raw = map[key];
    if (raw is! String || raw.trim().isEmpty) {
      _fail(where, 'expected a non-empty text');
    }
    if (raw.length > maxLength) _fail(where, 'longer than $maxLength');
    return raw;
  }

  String questionId(Map<String, dynamic> map, String where) => string(
    map,
    'question_id',
    '$where.question_id',
    maxLength: ProgressCodec.maxQuestionIdLength,
  );

  int integer(
    Map<String, dynamic> map,
    String key,
    String where, {
    required int min,
    required int max,
  }) {
    final raw = map[key];
    if (raw is! int) _fail(where, 'expected a whole number');
    if (raw < min || raw > max) _fail(where, 'out of range $min..$max');
    return raw;
  }

  int? integerOrNull(
    Map<String, dynamic> map,
    String key,
    String where, {
    required int min,
    required int max,
  }) => map[key] == null ? null : integer(map, key, where, min: min, max: max);

  /// Like [integerOrNull] but a number outside [min]..[max] becomes `null`
  /// (a duration measured by a broken clock) instead of an error. A value of
  /// the wrong type is still an error.
  int? integerOrNullLenient(
    Map<String, dynamic> map,
    String key,
    String where, {
    required int min,
    required int max,
  }) {
    final raw = map[key];
    if (raw == null) return null;
    if (raw is! int) _fail(where, 'expected a whole number');
    return raw < min || raw > max ? null : raw;
  }

  bool boolean(Map<String, dynamic> map, String key, String where) {
    final raw = map[key];
    if (raw is! bool) _fail(where, 'expected true or false');
    return raw;
  }

  bool? booleanOrNull(Map<String, dynamic> map, String key, String where) =>
      map[key] == null ? null : boolean(map, key, where);

  /// An ISO 8601 date-time with a time part, between [ProgressCodec.earliest]
  /// and [latest] (default: now plus a day). Returned as local time, like the
  /// database does. A malformed text is an error; a well-formed date outside
  /// that range throws [_OutOfRange] (the caller skips its record).
  DateTime date(
    Map<String, dynamic> map,
    String key,
    String where, {
    DateTime? latest,
  }) {
    final raw = map[key];
    final match = raw is String ? _isoDateTime.firstMatch(raw) : null;
    if (raw is! String || match == null) {
      _fail(
        where,
        'expected an ISO 8601 date and time',
        ProgressImportError.invalidDateTime,
      );
    }
    // DateTime.parse rolls 30 February over to March: check the calendar.
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final inMonth = DateTime.utc(year, month + 1, 0).day;
    if (month < 1 || month > 12 || day < 1 || day > inMonth) {
      _fail(where, 'not a valid date', ProgressImportError.invalidDateTime);
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      _fail(where, 'not a valid date', ProgressImportError.invalidDateTime);
    }
    final utc = parsed.toUtc();
    if (utc.isBefore(ProgressCodec.earliest) ||
        utc.isAfter(latest ?? ProgressCodec.latestPast(now))) {
      throw const _OutOfRange();
    }
    return utc.toLocal();
  }

  DateTime? dateOrNull(
    Map<String, dynamic> map,
    String key,
    String where, {
    DateTime? latest,
  }) => map[key] == null ? null : date(map, key, where, latest: latest);

  Attempt attempt(Object? raw, int index) {
    final where = 'attempts[$index]';
    final m = object(raw, where);
    final modeName = m['mode'];
    final mode = AttemptMode.values
        .where((v) => v.name == modeName)
        .cast<AttemptMode?>()
        .firstOrNull;
    if (mode == null) _fail('$where.mode', 'unknown mode');
    final selected = integerOrNull(
      m,
      'selected',
      '$where.selected',
      min: 0,
      max: ProgressCodec.maxOptionIndex,
    );
    final correct = boolean(m, 'correct', '$where.correct');
    if (selected == null && correct) {
      _fail('$where.correct', 'a blank answer cannot be right');
    }
    return Attempt(
      questionId: questionId(m, where),
      mode: mode,
      selected: selected,
      correct: correct,
      answeredAt: date(m, 'answered_at', '$where.answered_at'),
      mockId: integerOrNull(
        m,
        'mock_id',
        '$where.mock_id',
        min: 1,
        max: ProgressCodec.maxId,
      ),
      elapsedMs: integerOrNullLenient(
        m,
        'elapsed_ms',
        '$where.elapsed_ms',
        min: 0,
        max: ProgressCodec.maxElapsedMs,
      ),
    );
  }

  SrsEntry srsEntry(Object? raw, int index, Set<String> seen) {
    final where = 'srs[$index]';
    final m = object(raw, where);
    final id = questionId(m, where);
    if (!seen.add(id)) _fail('$where.question_id', 'repeated card for $id');
    return SrsEntry(
      questionId: id,
      box: integer(m, 'box', '$where.box', min: 1, max: ProgressCodec.maxBox),
      dueAt: date(
        m,
        'due_at',
        '$where.due_at',
        latest: ProgressCodec.latestDue,
      ),
      reps: integer(
        m,
        'reps',
        '$where.reps',
        min: 0,
        max: ProgressCodec.maxReps,
      ),
      lapses: integer(
        m,
        'lapses',
        '$where.lapses',
        min: 0,
        max: ProgressCodec.maxReps,
      ),
      lastAnsweredAt: dateOrNull(
        m,
        'last_answered_at',
        '$where.last_answered_at',
      ),
    );
  }

  /// Throws [_OutOfRange] (after noting the id in [skippedIds]) when a date of
  /// the mock is impossible: the mock and its attempts are left out.
  MockEntry mock(
    Object? raw,
    int index,
    Set<int> seenIds,
    Set<int> skippedIds,
    int mockSize,
  ) {
    final where = 'mocks[$index]';
    final m = object(raw, where);
    final id = integer(m, 'id', '$where.id', min: 1, max: ProgressCodec.maxId);
    if (!seenIds.add(id)) _fail('$where.id', 'repeated mock $id');

    final idsRaw = m['question_ids'];
    if (idsRaw is! List || idsRaw.length != mockSize) {
      _fail('$where.question_ids', 'expected exactly $mockSize question ids');
    }
    final questionIds = <String>[];
    for (final (i, q) in idsRaw.indexed) {
      if (q is! String ||
          q.isEmpty ||
          q.length > ProgressCodec.maxQuestionIdLength) {
        _fail('$where.question_ids[$i]', 'expected a question id');
      }
      questionIds.add(q);
    }
    if (questionIds.toSet().length != questionIds.length) {
      _fail('$where.question_ids', 'a question appears twice');
    }

    final answersRaw = m['answers'];
    if (answersRaw is! List || answersRaw.length != questionIds.length) {
      _fail('$where.answers', 'expected one answer per question');
    }
    final answers = <int?>[];
    for (final (i, a) in answersRaw.indexed) {
      if (a != null &&
          (a is! int || a < 0 || a > ProgressCodec.maxOptionIndex)) {
        _fail('$where.answers[$i]', 'expected an option or null');
      }
      answers.add(a as int?);
    }

    final DateTime startedAt;
    final DateTime? rawFinishedAt;
    try {
      startedAt = date(m, 'started_at', '$where.started_at');
      rawFinishedAt = dateOrNull(m, 'finished_at', '$where.finished_at');
    } on _OutOfRange {
      skippedIds.add(id);
      rethrow;
    }
    // A clock set back between the start and the end: it finished when it
    // started.
    final finishedAt =
        rawFinishedAt != null && rawFinishedAt.isBefore(startedAt)
        ? startedAt
        : rawFinishedAt;
    final correctCount = integerOrNull(
      m,
      'correct_count',
      '$where.correct_count',
      min: 0,
      max: questionIds.length,
    );
    final passed = booleanOrNull(m, 'passed', '$where.passed');
    if (finishedAt != null && (correctCount == null || passed == null)) {
      _fail(where, 'a finished mock needs correct_count and passed');
    }
    if (finishedAt == null && (correctCount != null || passed != null)) {
      _fail(where, 'an unfinished mock cannot have a result');
    }
    // Optional (files from before the doubtful mark do not have it): a list
    // of ids of this mock's own questions; any other id is left out.
    final flaggedRaw = m['flagged'];
    final flagged = <String>[];
    if (flaggedRaw != null) {
      if (flaggedRaw is! List || flaggedRaw.length > questionIds.length * 2) {
        _fail('$where.flagged', 'expected a list of question ids');
      }
      final own = questionIds.toSet();
      for (final (i, q) in flaggedRaw.indexed) {
        if (q is! String || q.length > ProgressCodec.maxQuestionIdLength) {
          _fail('$where.flagged[$i]', 'expected a question id');
        }
        if (own.contains(q) && !flagged.contains(q)) flagged.add(q);
      }
    }
    return MockEntry(
      id: id,
      startedAt: startedAt,
      finishedAt: finishedAt,
      questionIds: questionIds,
      answers: answers,
      correctCount: correctCount,
      passed: passed,
      flagged: flagged,
      timed: boolean(m, 'timed', '$where.timed'),
      passMark: integerOrNull(
        m,
        'pass_mark',
        '$where.pass_mark',
        min: 0,
        max: questionIds.length,
      ),
    );
  }

  ProgressSettings settings(Object? raw) {
    if (raw == null) return const ProgressSettings();
    final m = object(raw, 'settings');
    final theme = m['theme_mode'];
    if (theme != null &&
        (theme is! String || !ProgressSettings.themeModes.contains(theme))) {
      _fail('settings.theme_mode', 'expected system, light or dark');
    }
    // Purchase/free-mock fields from older exports are intentionally ignored.
    return ProgressSettings(themeMode: theme as String?);
  }
}
