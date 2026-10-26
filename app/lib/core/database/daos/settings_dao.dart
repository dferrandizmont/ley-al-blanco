import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await into(
      settings,
    ).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  /// Deletes [key] (no-op when unset).
  Future<void> remove(String key) async {
    await (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  /// The value of [key], re-emitted on every change (null while unset).
  Stream<String?> watch(String key) => (select(
    settings,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);
}
