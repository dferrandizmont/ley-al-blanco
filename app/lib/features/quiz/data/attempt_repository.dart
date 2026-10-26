import '../../../core/database/app_database.dart';
import '../domain/attempt.dart';

/// Every answered question, in any mode.
class AttemptRepository {
  AttemptRepository(this._db);

  final AppDatabase _db;

  /// Every attempt, oldest first.
  Future<List<Attempt>> all() => _db.attemptsDao.all();

  /// [all], re-emitted on every change.
  Stream<List<Attempt>> watchAll() => _db.attemptsDao.watchAll();

  /// The attempts on one question, oldest first.
  Future<List<Attempt>> forQuestion(String questionId) =>
      _db.attemptsDao.forQuestion(questionId);

  /// Stores [attempts] in one transaction. Use `StudyService.recordAnswers`
  /// to also update the SRS cards; this is the raw write.
  Future<void> addAll(List<Attempt> attempts) =>
      _db.attemptsDao.insertAll(attempts);
}
