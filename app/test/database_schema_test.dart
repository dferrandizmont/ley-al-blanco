import 'dart:convert';
import 'dart:io';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'database_migrations/schema.dart';
import 'support/db_support.dart';

// drift_schemas/app_database/drift_schema_vN.json are the committed schemas
// (written by `dart run drift_dev make-migrations`); the current one is v4
// (v2 added `mocks.pass_mark`, v3 `questions.notice`, v4 `mocks.flagged`).
// If a table changes,
// bump schemaVersion, dump the new version and add a migration step.
void main() {
  final schemaFile = File('drift_schemas/app_database/drift_schema_v4.json');

  test('the app database is at schema v4', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    expect(db.schemaVersion, 4);
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.read<int>('user_version'), 4);
  });

  test('the created database matches the committed v4 schema', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final dump = jsonDecode(schemaFile.readAsStringSync()) as Map;
    final entities = (dump['entities'] as List).cast<Map<String, dynamic>>();
    final tables = entities.where((e) => e['type'] == 'table').toList();
    final indexes = entities.where((e) => e['type'] == 'index').toList();
    expect(tables.map((t) => t['data']['name']).toSet(), {
      'questions',
      'attempts',
      'srs_state',
      'mocks',
      'settings',
    });

    for (final table in tables) {
      final name = table['data']['name'] as String;
      final info = await db.customSelect('PRAGMA table_info($name)').get();
      final actual = {
        for (final r in info)
          r.read<String>('name'): (
            notNull: r.read<int>('notnull') == 1,
            pk: r.read<int>('pk') > 0,
          ),
      };
      final expectedColumns = (table['data']['columns'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        actual.keys.toList(),
        expectedColumns.map((c) => c['name']).toList(),
        reason: 'columns of $name',
      );
      for (final c in expectedColumns) {
        expect(
          actual[c['name']]!.notNull,
          !(c['nullable'] as bool),
          reason: '$name.${c['name']} nullability',
        );
      }
    }

    for (final index in indexes) {
      final table = tables.firstWhere(
        (t) => t['id'] == index['data']['on'],
      )['data']['name'];
      final actual = await db
          .customSelect('PRAGMA index_info(${index['data']['name']})')
          .get();
      expect(
        actual.map((r) => r.read<String>('name')).toList(),
        (index['data']['columns'] as List).map((c) => c['column']).toList(),
        reason: 'index ${index['data']['name']} on $table',
      );
    }
  });

  test('the key columns are what the plan promises', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    Future<Map<String, String>> types(String table) async => {
      for (final r in await db.customSelect('PRAGMA table_info($table)').get())
        r.read<String>('name'): r.read<String>('type'),
    };
    expect(await types('questions'), {
      'id': 'TEXT',
      'tema': 'INTEGER',
      'section': 'TEXT',
      'stem': 'TEXT',
      'options': 'TEXT',
      'answer': 'INTEGER',
      'explanation': 'TEXT',
      'article': 'TEXT',
      'flags': 'TEXT',
      'edition': 'TEXT',
      'reviewed': 'INTEGER',
      'retired': 'INTEGER',
      'notice': 'TEXT',
    });
    expect(
      (await types('attempts')).keys,
      containsAll([
        'question_id',
        'mode',
        'selected',
        'correct',
        'answered_at',
        'mock_id',
        'elapsed_ms',
      ]),
    );
    expect(
      (await types('mocks')).keys,
      containsAll([
        'started_at',
        'finished_at',
        'question_ids',
        'answers',
        'correct_count',
        'passed',
        'timed',
        'pass_mark',
        'flagged',
      ]),
    );
    // Dates are ISO 8601 text.
    expect((await types('attempts'))['answered_at'], 'TEXT');
    expect((await types('srs_state'))['due_at'], 'TEXT');
  });

  // Drift's own verifier: builds each version from its dump and checks the
  // real schema against it.
  group('SchemaVerifier', () {
    late SchemaVerifier verifier;
    setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

    test('a fresh v4 database validates against the dump', () async {
      final connection = await verifier.startAt(4);
      final db = AppDatabase(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);
    });

    test('v1 -> v2 adds mocks.pass_mark and keeps the data', () async {
      final schema = await verifier.schemaAt(1);
      // A finished mock written by a v1 app.
      schema.rawDatabase.execute(
        'INSERT INTO mocks (started_at, finished_at, question_ids, answers, '
        'correct_count, passed, timed) VALUES (?, ?, ?, ?, 1, 1, 0)',
        [
          '2026-10-15T16:30:00.000Z',
          '2026-10-15T16:50:00.000Z',
          '["t1-001"]',
          '[0]',
        ],
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);

      final row = (await db.mocksDao.byId(1))!;
      expect((row.correctCount, row.passed, row.timed), (1, true, false));
      expect(row.questionIds, ['t1-001']);
      // Unknown for the old mock; new ones record it.
      expect(row.passMark, isNull);
      await db.mocksDao.finish(
        1,
        answers: [0],
        correctCount: 1,
        passed: false,
        finishedAt: DateTime.utc(2026, 10, 16),
        passMark: 16,
      );
      expect((await db.mocksDao.byId(1))!.passMark, 16);
    });

    test('v2 -> v3 adds questions.notice (null) and keeps the bank', () async {
      final schema = await verifier.schemaAt(2);
      // A bank row and an attempt written by a v2 app.
      schema.rawDatabase.execute(
        'INSERT INTO questions (id, tema, section, stem, options, answer, '
        'explanation, article, flags, edition, reviewed, retired) '
        'VALUES (?, 1, NULL, ?, ?, 2, ?, ?, ?, ?, 1, 0)',
        [
          't1-001',
          'Enunciado',
          '["a","b","c"]',
          'Explicacion',
          'Art. 1',
          '[]',
          'GC-2020-11',
        ],
      );
      schema.rawDatabase.execute(
        'INSERT INTO attempts (question_id, mode, selected, correct, '
        'answered_at) VALUES (?, ?, 2, 1, ?)',
        ['t1-001', 'practice', '2026-10-15T16:30:00.000Z'],
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);

      final q = (await db.questionsDao.byIds(['t1-001'])).single;
      expect(q.stem, 'Enunciado');
      expect(q.explanation, 'Explicacion');
      expect(q.article, 'Art. 1');
      expect(q.answer, 2);
      expect(q.reviewed, isTrue);
      // Unknown until the next content import fills it.
      expect(q.notice, isNull);
      final attempts = await db.customSelect('SELECT * FROM attempts').get();
      expect(attempts, hasLength(1));

      // The re-import can now carry a notice.
      await db.questionsDao.upsertAll([
        Question(
          id: 't1-001',
          tema: 1,
          stem: 'Enunciado',
          options: const ['a', 'b', 'c'],
          answer: 2,
          edition: 'GC-2020-11',
          notice: 'Ojo: aviso.',
        ),
      ]);
      final after = (await db.questionsDao.byIds(['t1-001'])).single;
      expect(after.notice, 'Ojo: aviso.');
    });

    test('v3 -> v4 adds mocks.flagged (empty) and keeps the mocks', () async {
      final schema = await verifier.schemaAt(3);
      // An open mock and a finished one written by a v3 app.
      schema.rawDatabase.execute(
        'INSERT INTO mocks (started_at, finished_at, question_ids, answers, '
        'correct_count, passed, timed, pass_mark) '
        'VALUES (?, NULL, ?, ?, NULL, NULL, 0, NULL)',
        ['2026-10-15T16:30:00.000Z', '["t1-001","t1-002"]', '[0,null]'],
      );
      schema.rawDatabase.execute(
        'INSERT INTO mocks (started_at, finished_at, question_ids, answers, '
        'correct_count, passed, timed, pass_mark) '
        'VALUES (?, ?, ?, ?, 1, 0, 1, 16)',
        [
          '2026-10-16T16:30:00.000Z',
          '2026-10-16T16:50:00.000Z',
          '["t1-001","t1-002"]',
          '[1,null]',
        ],
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 4);

      final open = (await db.mocksDao.byId(1))!;
      expect(open.questionIds, ['t1-001', 't1-002']);
      expect(open.answers, [0, null]);
      expect(open.finishedAt, isNull);
      expect(open.flagged, isEmpty);
      final done = (await db.mocksDao.byId(2))!;
      expect((done.correctCount, done.passed, done.passMark), (1, false, 16));
      expect(done.flagged, isEmpty);

      // The new column is usable: only the mock's own questions are kept.
      await db.mocksDao.saveFlagged(1, ['t1-002', 't9-999', 't1-002']);
      expect((await db.mocksDao.byId(1))!.flagged, ['t1-002']);
      await db.mocksDao.saveFlagged(1, const []);
      expect((await db.mocksDao.byId(1))!.flagged, isEmpty);
    });
  });
}
