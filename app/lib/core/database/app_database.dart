import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The generated part references these.
import '../../features/quiz/domain/attempt.dart';
import 'converters.dart';
import 'daos/attempts_dao.dart';
import 'daos/mocks_dao.dart';
import 'daos/questions_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/srs_dao.dart';
import 'schema_versions.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The on-device database: question bank, attempts, SRS state, mocks and
/// settings. Nothing here ever leaves the phone.
///
/// DateTime policy (`build.yaml`: `store_date_time_values_as_text: true`):
/// every timestamp is stored as ISO 8601 text in **UTC**
/// (`2026-10-25T01:30:00.000Z`) and read back as **local** time. The date
/// columns use [LocalUtcDateTimeConverter], which enforces it, so values sort
/// chronologically in SQL whatever the local offset was at write time (DST).
/// Compare instants (`isAtSameMomentAs`), not `DateTime ==`, which also looks
/// at the isUtc flag.
@DriftDatabase(
  tables: [Questions, Attempts, SrsState, Mocks, Settings],
  daos: [QuestionsDao, AttemptsDao, SrsDao, MocksDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// The app database (a file in the app's documents directory). Tests pass
  /// an in-memory executor: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'apto_armas'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Legacy settings stay in existing databases, unused: purchases.entitlement,
    // purchases.checked_at, purchases.free_mock_used, purchases.free_mock_fingerprint,
    // purchases.free_mock_finished, purchases.soft_tema1_shown,
    // purchases.soft_mock_shown and progress.imported_at. No schema migration
    // or deletion is needed; these keys are no longer read or written.
    // v1 -> v2: `mocks.pass_mark` (the pass mark in force when a mock was
    // handed in; null for mocks finished before).
    // v2 -> v3: `questions.notice` (our legal-reform notice; null until the
    // next content import fills it).
    // v3 -> v4: `mocks.flagged` (the questions the user marked as doubtful;
    // empty for every existing mock).
    // To change the schema: bump
    // [schemaVersion], run `dart run drift_dev make-migrations` (dumps
    // drift_schemas/app_database/drift_schema_vN.json), regenerate the test
    // helpers (`dart run drift_dev schema generate drift_schemas/app_database
    // test/database_migrations/`) and the steps
    // (`dart run drift_dev schema steps drift_schemas/app_database
    // lib/core/database/schema_versions.dart`), then fill in the new step here.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.mocks, schema.mocks.passMark);
      },
      from2To3: (m, schema) async {
        await m.addColumn(schema.questions, schema.questions.notice);
      },
      from3To4: (m, schema) async {
        await m.addColumn(schema.mocks, schema.mocks.flagged);
      },
    ),
  );
}
