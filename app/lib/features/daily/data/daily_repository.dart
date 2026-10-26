import '../../../core/database/daos/settings_dao.dart';
import '../domain/daily_question.dart';

/// Keys of the daily question in the `settings` table. They live on the
/// device only (never exported, never sent anywhere).
abstract final class DailySettingKeys {
  /// ISO 8601 date of the last day the question was answered.
  static const lastDay = 'daily.last_day';

  /// Streak that ended on [lastDay] (integer >= 1).
  static const streak = 'daily.streak';

  /// Id of the question answered on [lastDay].
  static const lastQuestion = 'daily.last_question';
}

/// Reads and writes [DailyProgress] in the `settings` table.
class DailyRepository {
  DailyRepository(this._settings);

  final SettingsDao _settings;

  /// The stored progress; unreadable values count as "never answered".
  Future<DailyProgress> load() async {
    final lastDay = await _settings.get(DailySettingKeys.lastDay);
    final streak = int.tryParse(
      await _settings.get(DailySettingKeys.streak) ?? '',
    );
    if (parseIsoDay(lastDay) == null || streak == null || streak < 1) {
      return DailyProgress.none;
    }
    return DailyProgress(
      lastDay: lastDay,
      streak: streak,
      lastQuestionId: await _settings.get(DailySettingKeys.lastQuestion),
    );
  }

  Future<void> save(DailyProgress progress) async {
    final lastDay = progress.lastDay;
    if (lastDay == null) return;
    // The three keys describe one state: write them together.
    await _settings.attachedDatabase.transaction(() async {
      await _settings.set(DailySettingKeys.lastDay, lastDay);
      await _settings.set(DailySettingKeys.streak, '${progress.streak}');
      final question = progress.lastQuestionId;
      if (question != null) {
        await _settings.set(DailySettingKeys.lastQuestion, question);
      } else {
        await _settings.remove(DailySettingKeys.lastQuestion);
      }
    });
  }
}
