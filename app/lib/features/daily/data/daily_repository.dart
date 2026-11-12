import '../../../core/database/daos/settings_dao.dart';
import '../domain/daily_question.dart';

/// Keys of the daily question in the `settings` table. They live on the
/// device: they are never sent anywhere, and they only leave it in the
/// progress file the user exports on purpose.
abstract final class DailySettingKeys {
  /// ISO 8601 date of the last day the question was answered.
  static const lastDay = 'daily.last_day';

  /// Streak that ended on [lastDay] (integer >= 1).
  static const streak = 'daily.streak';

  /// Id of the question answered on [lastDay].
  static const lastQuestion = 'daily.last_question';

  /// ISO 8601 instant (UTC) of the last credited answer.
  static const lastAt = 'daily.last_at';

  /// Offset of the device's zone (in minutes) when that answer was credited.
  static const lastOffset = 'daily.last_offset';
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
      // A missing or unreadable value is "no context": the old streak is
      // kept, with the rules of the progress written before these keys.
      lastAt: _parseInstant(await _settings.get(DailySettingKeys.lastAt)),
      lastOffsetMinutes: int.tryParse(
        await _settings.get(DailySettingKeys.lastOffset) ?? '',
      ),
    );
  }

  /// Stores [progress]: the five keys describe one state and are written
  /// together.
  Future<void> save(DailyProgress progress) async {
    if (progress.lastDay == null) return;
    await _settings.attachedDatabase.transaction(() => write(progress));
  }

  /// Removes the daily state (the five keys): nothing was answered.
  Future<void> clear() async {
    await _settings.attachedDatabase.transaction(remove);
  }

  /// Writes the state without a transaction of its own: only from inside one
  /// (the import writes the whole progress at once).
  Future<void> write(DailyProgress progress) async {
    final lastDay = progress.lastDay;
    if (lastDay == null) return;
    await _settings.set(DailySettingKeys.lastDay, lastDay);
    await _settings.set(DailySettingKeys.streak, '${progress.streak}');
    final question = progress.lastQuestionId;
    if (question != null) {
      await _settings.set(DailySettingKeys.lastQuestion, question);
    } else {
      await _settings.remove(DailySettingKeys.lastQuestion);
    }
    final lastAt = progress.lastAt;
    if (lastAt != null) {
      await _settings.set(
        DailySettingKeys.lastAt,
        lastAt.toUtc().toIso8601String(),
      );
    } else {
      await _settings.remove(DailySettingKeys.lastAt);
    }
    final offset = progress.lastOffsetMinutes;
    if (offset != null) {
      await _settings.set(DailySettingKeys.lastOffset, '$offset');
    } else {
      await _settings.remove(DailySettingKeys.lastOffset);
    }
  }

  /// Removes the five keys without a transaction of its own: only from inside
  /// one.
  Future<void> remove() async {
    await _settings.remove(DailySettingKeys.lastDay);
    await _settings.remove(DailySettingKeys.streak);
    await _settings.remove(DailySettingKeys.lastQuestion);
    await _settings.remove(DailySettingKeys.lastAt);
    await _settings.remove(DailySettingKeys.lastOffset);
  }

  /// An ISO 8601 instant in UTC, or null when the value is missing or
  /// unreadable.
  static DateTime? _parseInstant(String? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }
}
