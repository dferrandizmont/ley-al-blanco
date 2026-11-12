import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_mode_setting.dart';
import '../../daily/data/daily_repository.dart';
import '../domain/progress_snapshot.dart';

/// Reads the user's progress out of the Drift database and writes an imported
/// one back, all in one transaction.
///
/// The bank and legacy purchase settings are never transferred.
class ProgressTransferRepository {
  ProgressTransferRepository(this._db);

  final AppDatabase _db;

  /// The daily question state (the streak), read and written like the rest of
  /// the progress.
  DailyRepository get _daily => DailyRepository(_db.settingsDao);

  /// Question id -> number of options and official answer, retired questions
  /// included (history keeps pointing at them).
  Future<Map<String, BankQuestion>> bank() async {
    final rows = await _db.select(_db.questions).get();
    return {
      for (final row in rows)
        row.id: (options: row.options.length, answer: row.answer),
    };
  }

  /// The current progress, read in one transaction so the four tables agree.
  Future<ProgressSnapshot> read({
    required String edition,
    required String appVersion,
    required DateTime exportedAt,
  }) {
    return _db.transaction(() async {
      final attempts = await _db.attemptsDao.all();
      final srsRows = await _db.srsDao.all();
      final mockRows = await (_db.select(
        _db.mocks,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      final settings = _db.settingsDao;
      final theme = await settings.get(ThemeModeSetting.key);
      final daily = await _daily.load();
      return ProgressSnapshot(
        edition: edition,
        exportedAt: exportedAt,
        appVersion: appVersion,
        attempts: attempts,
        srs: [
          for (final r in srsRows)
            SrsEntry(
              questionId: r.questionId,
              box: r.box,
              dueAt: r.dueAt,
              reps: r.reps,
              lapses: r.lapses,
              lastAnsweredAt: r.lastAnsweredAt,
              dueDay: r.dueDay,
            ),
        ],
        mocks: [
          for (final r in mockRows)
            MockEntry(
              id: r.id,
              startedAt: r.startedAt,
              finishedAt: r.finishedAt,
              questionIds: r.questionIds,
              answers: r.answers,
              correctCount: r.correctCount,
              passed: r.passed,
              timed: r.timed,
              passMark: r.passMark,
              flagged: r.flagged,
            ),
        ],
        settings: ProgressSettings(
          themeMode: ProgressSettings.themeModes.contains(theme) ? theme : null,
        ),
        // The daily state travels too (the streak of the question of the
        // day); without it there is nothing to export.
        daily: daily.lastDay == null ? null : daily,
      );
    });
  }

  /// Replaces the progress with [snapshot] in **one transaction**: if any
  /// step fails, everything is rolled back and the previous progress stays
  /// exactly as it was.
  ///
  /// * `attempts`, `srs_state` and `mocks` are emptied and refilled; mocks
  ///   keep their ids (the attempts of a mock point at them) and attempts are
  ///   inserted in the order of the snapshot (oldest first).
  /// The theme comes from the file when present. Old purchase keys remain
  /// untouched in existing databases and are never read or written.
  /// The daily state comes from the file when it has one; a file without it
  /// (written before the daily question travelled) **clears** the streak of
  /// the device: importing replaces the whole progress.
  Future<void> replaceWith(ProgressSnapshot snapshot) {
    return _db.transaction(() async {
      final settings = _db.settingsDao;
      await _db.delete(_db.attempts).go();
      await _db.delete(_db.srsState).go();
      await _db.delete(_db.mocks).go();

      await _db.batch((b) {
        b.insertAll(_db.mocks, [
          for (final m in snapshot.mocks)
            MocksCompanion.insert(
              id: Value(m.id),
              startedAt: m.startedAt,
              finishedAt: Value(m.finishedAt),
              questionIds: m.questionIds,
              answers: m.answers,
              correctCount: Value(m.correctCount),
              passed: Value(m.passed),
              timed: m.timed,
              passMark: Value(m.passMark),
              flagged: Value(m.flagged),
            ),
        ]);
        b.insertAll(_db.attempts, [
          for (final a in snapshot.attempts)
            AttemptsCompanion.insert(
              questionId: a.questionId,
              mode: a.mode,
              selected: Value(a.selected),
              correct: a.correct,
              answeredAt: a.answeredAt,
              mockId: Value(a.mockId),
              elapsedMs: Value(a.elapsedMs),
            ),
        ]);
        // A plain insert (not an upsert): a repeated card must fail the
        // whole import, not silently overwrite.
        b.insertAll(_db.srsState, [
          for (final c in snapshot.srs)
            SrsStateCompanion.insert(
              questionId: c.questionId,
              box: c.box,
              dueAt: c.dueAt,
              reps: c.reps,
              lapses: c.lapses,
              lastAnsweredAt: Value(c.lastAnsweredAt),
              dueDay: Value(c.dueDay),
            ),
        ]);
      });

      final theme = snapshot.settings.themeMode;
      if (theme != null) await settings.set(ThemeModeSetting.key, theme);

      // The daily state: the file's, or none at all (a file without it clears
      // the streak of the device).
      final daily = snapshot.daily;
      if (daily != null && daily.lastDay != null) {
        await _daily.write(daily);
      } else {
        await _daily.remove();
      }
    });
  }
}
