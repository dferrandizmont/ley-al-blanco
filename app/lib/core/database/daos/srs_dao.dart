import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'srs_dao.g.dart';

/// Raw access to `srs_state`; the Leitner logic and the domain mapping live
/// in `features/srs`.
@DriftAccessor(tables: [SrsState])
class SrsDao extends DatabaseAccessor<AppDatabase> with _$SrsDaoMixin {
  SrsDao(super.db);

  Future<SrsStateRow?> get(String questionId) => (select(
    srsState,
  )..where((t) => t.questionId.equals(questionId))).getSingleOrNull();

  Future<List<SrsStateRow>> all() => (select(
    srsState,
  )..orderBy([(t) => OrderingTerm.asc(t.questionId)])).get();

  /// [all], re-emitted on every change.
  Stream<List<SrsStateRow>> watchAll() => (select(
    srsState,
  )..orderBy([(t) => OrderingTerm.asc(t.questionId)])).watch();

  /// Inserts or replaces the row for `row.questionId`.
  Future<void> upsert(SrsStateRow row) async {
    await into(srsState).insertOnConflictUpdate(row);
  }
}
