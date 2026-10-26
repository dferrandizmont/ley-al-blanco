import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/features/content/content_constants.dart';
import 'package:apto_armas/features/content/data/content_importer.dart';
import 'package:apto_armas/features/content/data/content_manifest.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_test/flutter_test.dart';

import 'support/db_support.dart';

void main() {
  late AppDatabase db;
  final importedAt = DateTime.utc(2026, 10, 19, 8);

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  ContentImporter importerFor(FakeAssetBundle bundle, {DateTime? now}) =>
      ContentImporter(db, bundle, now: () => now ?? importedAt);

  group('real bank', () {
    test('imports 423 questions in 7 temas, no duplicates', () async {
      final result = await importerFor(FakeAssetBundle.real()).importIfNeeded();

      expect(result.status, ImportStatus.imported);
      expect((result.inserted, result.updated, result.retired), (423, 0, 0));
      expect(result.manifest.edition, kContentEdition);

      final all = await db.questionsDao.allActive();
      expect(all, hasLength(423));
      expect(all.map((q) => q.id).toSet(), hasLength(423));
      expect(await db.questionsDao.countByTema(), {
        1: 68,
        2: 67,
        3: 66,
        4: 70,
        5: 66,
        6: 64,
        7: 22,
      });
    });

    test('rows round-trip equal to Question.fromJson', () async {
      await importerFor(FakeAssetBundle.real()).importIfNeeded();
      final expected = {
        for (final j in realQuestionsJson())
          j['id'] as String: Question.fromJson(j),
      };

      final all = await db.questionsDao.allActive();
      for (final q in all) {
        expect(q, expected[q.id], reason: q.id);
      }
      final byId = {for (final q in all) q.id: q};
      expect(byId['t1-001']!.answer, 2);
      expect(byId['t1-004']!.answer, 0);
      expect(byId['t1-001']!.options, hasLength(3));
    });

    test('stores the edition, checksum, source date and import time', () async {
      final result = await importerFor(FakeAssetBundle.real()).importIfNeeded();
      expect(
        await db.settingsDao.get(ContentSettingKeys.edition),
        kContentEdition,
      );
      expect(
        await db.settingsDao.get(ContentSettingKeys.sha256),
        result.manifest.questionsSha256,
      );
      expect(
        await db.settingsDao.get(ContentSettingKeys.retrieved),
        '2026-10-18',
      );
      expect(
        await db.settingsDao.get(ContentSettingKeys.importedAt),
        '2026-10-19T08:00:00.000Z',
      );
    });

    test('re-import is idempotent: upToDate and no writes', () async {
      final bundle = FakeAssetBundle.real();
      await importerFor(bundle).importIfNeeded();
      final before = await db.questionsDao.allActive();

      var writes = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onAllTables(db.allTables))
          .listen((_) => writes++);
      addTearDown(sub.cancel);
      final again = await importerFor(
        bundle,
        now: importedAt.add(const Duration(days: 1)),
      ).importIfNeeded();
      await Future<void>.delayed(Duration.zero);

      expect(again.status, ImportStatus.upToDate);
      expect(again.isUpToDate, isTrue);
      expect(writes, 0);
      expect(await db.questionsDao.allActive(), before);
      expect(
        await db.settingsDao.get(ContentSettingKeys.importedAt),
        '2026-10-19T08:00:00.000Z',
        reason: 'imported_at must not move on an up-to-date launch',
      );
    });

    test('allActive is ordered by tema then numeric id', () async {
      await importerFor(FakeAssetBundle.real()).importIfNeeded();
      final all = await db.questionsDao.allActive();
      int num(Question q) => int.parse(q.id.split('-')[1]);
      for (var i = 1; i < all.length; i++) {
        final a = all[i - 1], b = all[i];
        expect(
          a.tema < b.tema || (a.tema == b.tema && num(a) < num(b)),
          isTrue,
          reason: '${a.id} before ${b.id}',
        );
      }
      expect(
        (await db.questionsDao.byTema(7)).map((q) => q.id).first,
        't7-001',
      );
    });
  });

  group('integrity', () {
    test(
      'a tampered questions.json throws and leaves the DB untouched',
      () async {
        final bytes = realQuestionsBytes();
        // Flip one ASCII letter inside the first stem.
        final i = bytes.indexOf('arma'.codeUnitAt(0), 200);
        bytes[i] = bytes[i] == 0x78 ? 0x79 : 0x78;
        final bundle = FakeAssetBundle({
          ...FakeAssetBundle.real().assets,
          contentQuestionsAsset(kContentEdition): bytes,
        });

        await expectLater(
          importerFor(bundle).importIfNeeded(),
          throwsA(isA<ContentIntegrityException>()),
        );
        expect(await db.questionsDao.allActive(), isEmpty);
        expect(await db.settingsDao.get(ContentSettingKeys.edition), isNull);
        expect(await db.settingsDao.get(ContentSettingKeys.sha256), isNull);
      },
    );

    test('a tampered bank does not touch an already imported one', () async {
      await importerFor(FakeAssetBundle.real()).importIfNeeded();
      final before = await db.questionsDao.allActive();

      final bytes = realQuestionsBytes();
      bytes[bytes.length ~/ 2] ^= 0x01;
      final bundle = FakeAssetBundle({
        ...FakeAssetBundle.real().assets,
        contentQuestionsAsset(kContentEdition): bytes,
      });
      await expectLater(
        importerFor(bundle).importIfNeeded(),
        throwsA(isA<ContentIntegrityException>()),
      );
      expect(await db.questionsDao.allActive(), before);
    });

    test('a count that disagrees with the manifest is rejected', () async {
      final bundle = FakeAssetBundle.edition(realQuestionsJson());
      final manifestKey = contentManifestAsset(kContentEdition);
      final manifest = jsonDecode(
        utf8.decode(bundle.assets[manifestKey]!),
      ) as Map<String, dynamic>;
      manifest['question_count'] = 999;
      bundle.assets[manifestKey] = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      await expectLater(
        importerFor(bundle).importIfNeeded(),
        throwsA(isA<ContentIntegrityException>()),
      );
      expect(await db.questionsDao.allActive(), isEmpty);
    });

    test(
      'duplicate ids, wrong option count and bad answer are rejected',
      () async {
        Future<void> expectRejected(
          void Function(List<Map<String, dynamic>> questions) mutate,
        ) async {
          final questions = realQuestionsJson();
          mutate(questions);
          await expectLater(
            importerFor(FakeAssetBundle.edition(questions)).importIfNeeded(),
            throwsA(isA<ContentIntegrityException>()),
          );
          expect(await db.questionsDao.allActive(), isEmpty);
        }

        await expectRejected((q) => q[1]['id'] = q[0]['id']);
        await expectRejected((q) => (q[0]['options'] as List).removeLast());
        await expectRejected((q) => q[0]['answer'] = 3);
      },
    );
  });

  group('new edition', () {
    test('keeps progress, retires missing ids, never deletes', () async {
      await importerFor(FakeAssetBundle.real()).importIfNeeded();
      const gone = 't1-003';
      const kept = 't1-001';
      final answered = DateTime(2026, 10, 15, 18, 30);
      await db.attemptsDao.insertAll([
        Attempt(
          questionId: gone,
          mode: AttemptMode.practice,
          selected: 1,
          correct: false,
          answeredAt: answered,
        ),
        Attempt(
          questionId: kept,
          mode: AttemptMode.practice,
          selected: 2,
          correct: true,
          answeredAt: answered,
        ),
      ]);
      for (final id in [gone, kept]) {
        await db.srsDao.upsert(
          SrsStateRow(
            questionId: id,
            box: 2,
            dueAt: answered.add(const Duration(days: 1)),
            reps: 1,
            lapses: 0,
            lastAnsweredAt: answered,
          ),
        );
      }

      final next = realQuestionsJson()..removeWhere((q) => q['id'] == gone);
      next.firstWhere((q) => q['id'] == kept)['stem'] = 'Enunciado revisado';
      final result = await importerFor(
        FakeAssetBundle.edition(next),
        now: importedAt.add(const Duration(days: 30)),
      ).importIfNeeded();

      expect(result.status, ImportStatus.imported);
      expect((result.inserted, result.updated, result.retired), (0, 422, 1));

      // Progress for existing ids survives.
      expect(await db.attemptsDao.forQuestion(gone), hasLength(1));
      expect(await db.attemptsDao.forQuestion(kept), hasLength(1));
      expect(await db.srsDao.all(), hasLength(2));

      // The missing id is retired, not deleted.
      final active = await db.questionsDao.allActive();
      expect(active, hasLength(422));
      expect(active.map((q) => q.id), isNot(contains(gone)));
      expect(active.firstWhere((q) => q.id == kept).stem, 'Enunciado revisado');
      expect((await db.questionsDao.byIds([gone])).single.id, gone);
      expect((await db.questionsDao.countByTema())[1], 67);

      // Bringing it back re-activates it.
      final back = await importerFor(
        FakeAssetBundle.real(),
        now: importedAt.add(const Duration(days: 60)),
      ).importIfNeeded();
      expect((back.inserted, back.updated, back.retired), (0, 423, 0));
      expect(await db.questionsDao.allActive(), hasLength(423));
    });

    test('a new edition adds new ids', () async {
      await importerFor(FakeAssetBundle.real()).importIfNeeded();
      final next = realQuestionsJson();
      next.add({...next.last, 'id': 't7-099', 'stem': 'Pregunta nueva'});
      final result = await importerFor(FakeAssetBundle.edition(next))
          .importIfNeeded();
      expect((result.inserted, result.updated, result.retired), (1, 423, 0));
      expect(await db.questionsDao.allActive(), hasLength(424));
    });
  });

  group('manifest', () {
    test('parses the real manifest and ignores unknown keys', () {
      final m = ContentManifest.fromJson(
        jsonDecode(utf8.decode(realManifestBytes())) as Map<String, dynamic>,
      );
      expect(m.edition, 'GC-2020-11');
      expect(m.retrieved, '2026-10-18');
      expect(m.sourceUrl, startsWith('https://web.guardiacivil.es/'));
      expect(m.questionCount, 423);
      expect(m.perTema, {1: 68, 2: 67, 3: 66, 4: 70, 5: 66, 6: 64, 7: 22});
      expect(m.questionsSha256, hasLength(64));
      expect(m.mock, isNull);
    });

    test('accepts the optional mock block', () {
      final json =
          jsonDecode(utf8.decode(realManifestBytes())) as Map<String, dynamic>;
      json['mock'] = {
        'size': 20,
        'pass_mark': 16,
        'distribution': {
          '1': 3,
          '2': 3,
          '3': 3,
          '4': 4,
          '5': 3,
          '6': 3,
          '7': 1,
        },
      };
      final m = ContentManifest.fromJson(json);
      expect(m.mock!.size, 20);
      expect(m.mock!.passMark, 16);
      expect(m.mock!.distribution, {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1});

      json['mock'] = {'size': 10};
      final partial = ContentManifest.fromJson(json).mock!;
      expect(
        (partial.size, partial.passMark, partial.distribution),
        (10, null, null),
      );
    });
  });
}
