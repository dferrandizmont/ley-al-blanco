import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/features/content/data/content_importer.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/db_support.dart';

const Object _absent = Object();

Map<String, dynamic> _json({Object? notice = _absent, Object? explanation}) => {
  'id': 't2-017',
  'tema': 2,
  'type': 'mc3',
  'section': null,
  'stem': 'Enunciado oficial.',
  'options': ['A', 'B', 'C'],
  'answer': 1,
  'explanation': explanation,
  'article': 'Art. 3 RD 137/1993',
  if (!identical(notice, _absent)) 'notice': notice,
  'flags': <String>[],
  'edition': 'GC-2020-11',
  'reviewed': false,
};

void main() {
  group('Question.fromJson notice', () {
    test('parses notice.es next to the explanation and the article', () {
      final q = Question.fromJson(
        _json(
          notice: {'es': 'Ojo: el cuestionario dice X; el art. 5 dice Z.'},
          explanation: {'es': 'Explicación propia.'},
        ),
      );
      expect(q.notice, 'Ojo: el cuestionario dice X; el art. 5 dice Z.');
      expect(q.explanation, 'Explicación propia.');
      expect(q.article, 'Art. 3 RD 137/1993');
      // The official layer is untouched by the notice.
      expect(q.answer, 1);
      expect(q.options, ['A', 'B', 'C']);
    });

    test('null, absent or malformed notice means no notice', () {
      expect(Question.fromJson(_json(notice: null)).notice, isNull);
      expect(Question.fromJson(_json()).notice, isNull);
      expect(Question.fromJson(_json(notice: 'texto suelto')).notice, isNull);
      expect(
        Question.fromJson(_json(notice: <String, dynamic>{})).notice,
        isNull,
      );
    });

    test('the notice takes part in equality', () {
      final a = Question.fromJson(_json(notice: {'es': 'Uno'}));
      expect(a, Question.fromJson(_json(notice: {'es': 'Uno'})));
      expect(a, isNot(Question.fromJson(_json(notice: {'es': 'Dos'}))));
      expect(a, isNot(Question.fromJson(_json())));
    });
  });

  group('importer and database', () {
    late AppDatabase db;
    setUp(() => db = openTestDatabase());
    tearDown(() => db.close());

    test('the importer stores the notice and reads it back', () async {
      final json = realQuestionsJson();
      // What the bank itself carries (independent of its editorial content).
      final bankNotices = {
        for (final q in json)
          if (Question.fromJson(q).notice != null)
            q['id'] as String: Question.fromJson(q).notice,
      };
      final withNotice = json.firstWhere((q) => q['id'] == 't2-017');
      withNotice['notice'] = {'es': 'Ojo: reforma de 2023.'};
      withNotice['flags'] = ['discrepancia_reforma_2023'];

      await ContentImporter(db, FakeAssetBundle.edition(json)).importIfNeeded();

      final all = {for (final q in await db.questionsDao.allActive()) q.id: q};
      expect(all['t2-017']!.notice, 'Ojo: reforma de 2023.');
      expect(all['t2-017']!.flags, ['discrepancia_reforma_2023']);
      // Every other question has exactly the notice the bank gives it (or
      // none): the importer neither drops nor invents notices.
      expect({
        for (final q in all.values)
          if (q.id != 't2-017' && q.notice != null) q.id: q.notice,
      }, {...bankNotices}..remove('t2-017'));
      expect(all, hasLength(json.length));
      // The round trip equals what the JSON parses to.
      expect(all['t2-017'], Question.fromJson(withNotice));
    });

    test('a re-import with a new notice rewrites the row', () async {
      final json = realQuestionsJson();
      await ContentImporter(db, FakeAssetBundle.edition(json)).importIfNeeded();
      final target = json.firstWhere((q) => q['id'] == 't3-005');
      target['notice'] = {'es': 'Ojo: nuevo aviso.'};
      final result = await ContentImporter(
        db,
        FakeAssetBundle.edition(json),
      ).importIfNeeded();
      expect(result.isUpToDate, isFalse);
      final q = (await db.questionsDao.byIds(['t3-005'])).single;
      expect(q.notice, 'Ojo: nuevo aviso.');
    });
  });
}
