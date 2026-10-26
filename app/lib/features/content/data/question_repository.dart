import '../../../core/database/app_database.dart';
import '../domain/question.dart';

/// The question bank as domain objects.
///
/// The bank is read-only between imports, so [active] is loaded once and kept
/// in memory. A new repository is built when the bootstrap runs again (see
/// `questionRepositoryProvider`), which drops the cache.
class QuestionRepository {
  QuestionRepository(this._db);

  final AppDatabase _db;
  Future<List<Question>>? _active;

  /// Non-retired questions in bank order (tema, then numeric id). The list is
  /// unmodifiable and the same instance on every call.
  Future<List<Question>> active() {
    return _active ??= _db.questionsDao.allActive().then(
      List<Question>.unmodifiable,
      onError: (Object error, StackTrace stack) {
        _active = null; // do not cache a failure
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  /// The questions with these ids **in the requested order**. Retired ones
  /// are included (history and past mocks still show them); unknown ids are
  /// skipped. Not cached.
  Future<List<Question>> byIds(Iterable<String> ids) =>
      _db.questionsDao.byIds(ids);

  /// Non-retired questions of one tema, in bank order.
  Future<List<Question>> byTema(int tema) async => [
    for (final question in await active())
      if (question.tema == tema) question,
  ];
}
