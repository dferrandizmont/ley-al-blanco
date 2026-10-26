import 'dart:convert';
import 'dart:io';

import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/content/domain/same_stem_groups.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(String id, String stem, {int tema = 1}) => Question(
  id: id,
  tema: tema,
  stem: stem,
  options: const ['A', 'B', 'C'],
  answer: 0,
  edition: 'test',
);

List<Question> loadBank() {
  final raw = File('assets/content/armas/GC-2020-11/questions.json')
      .readAsStringSync();
  return (jsonDecode(raw) as List)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  group('normalizeStem', () {
    test('lowercases, folds accents and ñ, drops punctuation', () {
      expect(
        normalizeStem('  ¿Qué AÑO, según el Artículo 3?  '),
        'que ano segun el articulo 3',
      );
    });

    test('collapses whitespace and keeps digits', () {
      expect(normalizeStem('Art.\t5\n  RD 137/1993'), 'art 5 rd 137 1993');
    });
  });

  group('sameStemGroups', () {
    test('groups stems that differ only in case, accents and punctuation', () {
      final groups = sameStemGroups([
        q('a', '¿Cuál es la edad mínima?'),
        q('b', 'cual es la EDAD minima'),
        q('c', 'Otra pregunta distinta.'),
      ]);
      expect(groups, [
        {'a', 'b'},
      ]);
    });

    test('no groups when every stem is different', () {
      expect(sameStemGroups([q('a', 'uno'), q('b', 'dos')]), isEmpty);
    });

    test('three questions with one stem make one group of three', () {
      final groups = sameStemGroups([
        q('a', 'Igual'),
        q('b', 'igual.'),
        q('c', 'IGUAL'),
      ]);
      expect(groups, [
        {'a', 'b', 'c'},
      ]);
    });

    test('the real bank has exactly the 7 known pairs', () {
      final groups = sameStemGroups(loadBank());
      final pairs = groups.map((g) => (g.toList()..sort()).join('/')).toSet();
      expect(pairs, {
        't2-015/t2-016',
        't2-019/t2-021',
        't2-020/t2-023',
        't2-053/t2-057',
        't2-066/t2-067',
        't4-025/t4-026',
        't6-056/t6-057',
      });
      expect(groups.every((g) => g.length == 2), isTrue);
      expect(groups, hasLength(7));
    });
  });
}
