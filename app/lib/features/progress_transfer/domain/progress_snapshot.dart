import 'package:flutter/foundation.dart' show immutable;

import '../../quiz/domain/attempt.dart';

/// `format` of an exported progress file.
const String kProgressFormat = 'apto-armas-progress';

/// The only `version` this build reads and writes.
const int kProgressVersion = 1;

/// Biggest progress file the app reads or writes (10 MiB). A real export is a
/// few hundred KB; anything bigger is not one of ours.
const int kMaxProgressFileBytes = 10 * 1024 * 1024;

/// Deepest nesting of arrays and objects a progress file may have. The real
/// format needs 4 (object > mocks > mock > answers); more is not ours and
/// would only cost the parser.
const int kMaxProgressNesting = 8;

/// Leitner state of one question (a row of `srs_state`).
@immutable
class SrsEntry {
  const SrsEntry({
    required this.questionId,
    required this.box,
    required this.dueAt,
    required this.reps,
    required this.lapses,
    this.lastAnsweredAt,
  });

  final String questionId;

  /// Leitner box, 1..5.
  final int box;
  final DateTime dueAt;
  final int reps;
  final int lapses;
  final DateTime? lastAnsweredAt;
}

/// A mock exam (a row of `mocks`), in progress or finished.
@immutable
class MockEntry {
  const MockEntry({
    required this.id,
    required this.startedAt,
    required this.questionIds,
    required this.answers,
    required this.timed,
    this.finishedAt,
    this.correctCount,
    this.passed,
    this.passMark,
    this.flagged = const [],
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// Exam order.
  final List<String> questionIds;

  /// One slot per question, null = blank.
  final List<int?> answers;
  final int? correctCount;
  final bool? passed;
  final bool timed;
  final int? passMark;

  /// Ids of the questions marked as doubtful (all of them in [questionIds]).
  /// Optional in the file: absent = none.
  final List<String> flagged;

  bool get isFinished => finishedAt != null;
}

/// Preferences included in progress files. Legacy purchase fields are ignored.
@immutable
class ProgressSettings {
  const ProgressSettings({this.themeMode});

  /// `system`, `light` or `dark`; null = the file does not say.
  final String? themeMode;

  static const Set<String> themeModes = {'system', 'light', 'dark'};
}

/// Everything an exported progress file carries (and nothing else).
@immutable
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.edition,
    required this.exportedAt,
    required this.appVersion,
    required this.attempts,
    required this.srs,
    required this.mocks,
    required this.settings,
    this.skippedAttempts = 0,
    this.skippedSrs = 0,
    this.skippedMocks = 0,
  });

  /// Question-bank edition the progress was made on (`GC-2020-11`).
  final String edition;
  final DateTime exportedAt;

  /// Version of the app that wrote the file (informative).
  final String appVersion;

  /// Every answer, oldest first.
  final List<Attempt> attempts;
  final List<SrsEntry> srs;
  final List<MockEntry> mocks;
  final ProgressSettings settings;

  /// Records the parser left out because their dates make no sense (a phone
  /// whose clock was wrong): they do not block the import, they are counted
  /// in [ProgressImportPlan.discardedTotal]. Always 0 for a snapshot built
  /// from the database.
  final int skippedAttempts;
  final int skippedSrs;
  final int skippedMocks;

  /// Answers that were wrong (or blank in a mock).
  int get wrongAttempts => attempts.where((a) => !a.correct).length;

  /// Mocks that were handed in.
  int get finishedMocks => mocks.where((m) => m.isFinished).length;
}

/// Why a file could not be imported. The UI shows one message per value.
enum ProgressImportError {
  /// Bigger than [kMaxProgressFileBytes].
  tooLarge,

  /// Not UTF-8 / JSON, or not a JSON object.
  notJson,

  /// A JSON object that is not a progress file (`format` differs).
  wrongFormat,

  /// Written by a newer version of the app.
  newerVersion,

  /// Made on another edition of the question bank: the answers would point at
  /// other questions.
  wrongEdition,

  /// A field with the wrong type or out of range, an impossible date...
  invalid,
}

/// A file that must not be imported; nothing has been changed.
class ProgressImportException implements Exception {
  const ProgressImportException(this.error, [this.detail]);

  final ProgressImportError error;

  /// Technical hint for support («attempts[3].answered_at»); not localized.
  final String? detail;

  @override
  String toString() =>
      'ProgressImportException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// A question of the bundled bank, as far as importing needs to know it.
typedef BankQuestion = ({int options, int answer});

/// A snapshot checked against the question bank, ready to be written: what
/// is left after dropping what refers to questions the bank does not have
/// (and what the parser skipped for impossible dates).
@immutable
class ProgressImportPlan {
  const ProgressImportPlan({
    required this.snapshot,
    this.discardedAttempts = 0,
    this.discardedSrs = 0,
    this.discardedMocks = 0,
  });

  /// Only data about questions that exist.
  final ProgressSnapshot snapshot;
  final int discardedAttempts;
  final int discardedSrs;
  final int discardedMocks;

  /// Items dropped because their question is not in the bank or their dates
  /// are impossible.
  int get discardedTotal => discardedAttempts + discardedSrs + discardedMocks;
}
