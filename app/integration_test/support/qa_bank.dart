import 'dart:convert';

import 'package:apto_armas/features/content/content_constants.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One question of the bundled bank, as the scenarios need it: the official
/// answer index is how a scenario answers right or wrong without guessing.
class QaQuestion {
  const QaQuestion({
    required this.id,
    required this.tema,
    required this.stem,
    required this.options,
    required this.answer,
  });

  final String id;
  final int tema;
  final String stem;
  final List<String> options;

  /// 0-based index of the official answer.
  final int answer;

  /// An option that is not the official answer.
  int get wrongOption => (answer + 1) % options.length;

  @override
  String toString() => '$id (tema $tema)';
}

/// The real bundled bank (`assets/content/armas/<edition>/questions.json`),
/// read straight from the app's assets, independently of the app's own
/// importer and database.
class QaBank {
  QaBank._(this.questions)
    : _byId = {for (final q in questions) q.id: q},
      _byOptions = _groupByOptions(questions);

  static QaBank? _cache;

  static Future<QaBank> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(
      contentQuestionsAsset(kContentEdition),
    );
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return _cache = QaBank._([
      for (final q in list)
        QaQuestion(
          id: q['id'] as String,
          tema: q['tema'] as int,
          stem: q['stem'] as String,
          options: (q['options'] as List).cast<String>(),
          answer: q['answer'] as int,
        ),
    ]);
  }

  final List<QaQuestion> questions;
  final Map<String, QaQuestion> _byId;
  final Map<String, List<QaQuestion>> _byOptions;

  QaQuestion byId(String id) =>
      _byId[id] ?? (throw StateError('Question $id is not in the bank'));

  int countOfTema(int tema) => questions.where((q) => q.tema == tema).length;

  static String _key(List<String> options) => options.join('\u0001');

  static Map<String, List<QaQuestion>> _groupByOptions(
    List<QaQuestion> questions,
  ) {
    final map = <String, List<QaQuestion>>{};
    for (final q in questions) {
      map.putIfAbsent(_key(q.options), () => []).add(q);
    }
    return map;
  }

  /// The question on screen: the one whose options are [optionTexts] and
  /// whose stem is among [screenTexts] (a few questions share options, seven
  /// pairs share a stem). Null when nothing matches.
  QaQuestion? identify(List<String> optionTexts, Iterable<String> screenTexts) {
    final candidates = _byOptions[_key(optionTexts)];
    if (candidates == null || candidates.isEmpty) return null;
    final texts = screenTexts.toSet();
    final withStem = candidates.where((q) => texts.contains(q.stem)).toList();
    if (withStem.length == 1) return withStem.single;
    if (withStem.isEmpty) return null;
    // Same stem and options: they must at least agree on the answer.
    final answers = withStem.map((q) => q.answer).toSet();
    if (answers.length != 1) {
      throw StateError('Ambiguous question on screen: $withStem');
    }
    return withStem.first;
  }
}
