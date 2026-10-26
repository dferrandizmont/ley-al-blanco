import 'package:drift/drift.dart';

import '../../features/quiz/domain/attempt.dart';
import 'converters.dart';

/// The question bank. Rows are only ever inserted/updated by the importer;
/// a question that leaves the current edition is flagged [retired], never
/// deleted, so attempts and SRS state keep pointing at it.
@DataClassName('QuestionRow')
@TableIndex(name: 'questions_tema', columns: {#tema})
class Questions extends Table {
  /// Stable across editions, e.g. `t2-017`.
  TextColumn get id => text()();
  IntColumn get tema => integer()();
  TextColumn get section => text().nullable()();
  TextColumn get stem => text()();

  /// JSON array, questionnaire order (never shuffled).
  TextColumn get options => text().map(const StringListConverter())();
  IntColumn get answer => integer()();
  TextColumn get explanation => text().nullable()();
  TextColumn get article => text().nullable()();

  /// JSON array.
  TextColumn get flags => text().map(const StringListConverter())();
  TextColumn get edition => text()();
  BoolColumn get reviewed => boolean()();

  /// True once the question is no longer in the current edition.
  BoolColumn get retired => boolean().withDefault(const Constant(false))();

  /// Our legal-reform notice, shown above the explanation (schema v3, so it
  /// sits last: an upgraded database appends the column). Null until the
  /// bank is re-imported.
  TextColumn get notice => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Every answered question, in any mode. No hard foreign key to [Questions]:
/// history must survive a question being retired.
@DataClassName('AttemptRow')
@TableIndex(
  name: 'attempts_question_answered',
  columns: {#questionId, #answeredAt},
)
@TableIndex(name: 'attempts_mock', columns: {#mockId})
class Attempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionId => text()();
  TextColumn get mode => textEnum<AttemptMode>()();

  /// 0-based option; null = left blank in a mock.
  IntColumn get selected => integer().nullable()();
  BoolColumn get correct => boolean()();
  DateTimeColumn get answeredAt =>
      dateTime().map(const LocalUtcDateTimeConverter())();
  IntColumn get mockId => integer().nullable()();
  IntColumn get elapsedMs => integer().nullable()();
}

/// Leitner state per question (raw row; the domain mapping lives in
/// `features/srs`).
@DataClassName('SrsStateRow')
class SrsState extends Table {
  TextColumn get questionId => text()();
  IntColumn get box => integer()();
  DateTimeColumn get dueAt =>
      dateTime().map(const LocalUtcDateTimeConverter())();
  IntColumn get reps => integer()();
  IntColumn get lapses => integer()();
  DateTimeColumn get lastAnsweredAt =>
      dateTime().map(const LocalUtcDateTimeConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {questionId};
}

/// A mock exam, from creation (started, unfinished) to the final score.
@DataClassName('MockRow')
class Mocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt =>
      dateTime().map(const LocalUtcDateTimeConverter())();
  DateTimeColumn get finishedAt =>
      dateTime().map(const LocalUtcDateTimeConverter()).nullable()();

  /// JSON array of question ids, in exam order.
  TextColumn get questionIds => text().map(const StringListConverter())();

  /// JSON array, same length as [questionIds]; null = unanswered.
  TextColumn get answers => text().map(const NullableIntListConverter())();
  IntColumn get correctCount => integer().nullable()();
  BoolColumn get passed => boolean().nullable()();
  BoolColumn get timed => boolean()();

  /// The pass mark in force when the mock was handed in (schema v2). Null for
  /// unfinished mocks and for the ones finished before v2, which do not know
  /// it. The verdict of an old mock must not change with a later pass mark.
  IntColumn get passMark => integer().nullable()();

  /// JSON array of the ids of the questions the user marked as doubtful
  /// (schema v4); empty for every mock made before. Ids, not positions, so
  /// the mark follows the question.
  TextColumn get flagged => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
}

/// Key/value app state (content edition and checksum, user preferences).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
