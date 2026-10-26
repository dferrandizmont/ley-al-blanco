import 'package:flutter/foundation.dart' show immutable, listEquals;

/// Flag of the questions whose key is a figure, a term, an age, an amount, a
/// calibre or a fine ("Cifras y plazos" mode). Computed by the content
/// pipeline (`tool/content/cifras_flag.py`), never by hand.
const String kFiguresFlag = 'cifras';

/// One question of the bank, exactly as published in the questionnaire
/// (spec §3.4). The stem, options and [answer] are never altered; our own
/// layer is [explanation], [article], [notice] and [flags].
@immutable
class Question {
  const Question({
    required this.id,
    required this.tema,
    required this.stem,
    required this.options,
    required this.answer,
    required this.edition,
    this.section,
    this.explanation,
    this.article,
    this.notice,
    this.flags = const [],
    this.reviewed = false,
  }) : assert(answer >= 0 && answer < options.length);

  /// Stable across editions, e.g. `t2-017`.
  final String id;

  /// 1..7.
  final int tema;
  final String? section;
  final String stem;

  /// In the questionnaire's A/B/C order. Never shuffled: some options refer
  /// to the others ("Ambas respuestas son correctas").
  final List<String> options;

  /// 0-based index into [options].
  final int answer;

  /// Our own Spanish explanation (null until written and reviewed).
  final String? explanation;

  /// Cited article, e.g. "Art. 3 RD 137/1993".
  final String? article;

  /// Our own legal-reform notice ("Ojo: el cuestionario dice X; tras la
  /// reforma de 2023 el art. Y dice Z"). Shown above the explanation. The
  /// official [answer] is never changed because of it.
  final String? notice;
  final List<String> flags;
  final String edition;
  final bool reviewed;

  bool isCorrect(int selected) => selected == answer;

  /// Whether the question is about figures and terms (see [kFiguresFlag]).
  bool get isFigures => flags.contains(kFiguresFlag);

  /// Parses one entry of `questions.json`. `explanation` and `notice` are
  /// either null (or absent) or a `{"es": "..."}` map.
  factory Question.fromJson(Map<String, dynamic> json) {
    final explanation = json['explanation'];
    final notice = json['notice'];
    return Question(
      id: json['id'] as String,
      tema: json['tema'] as int,
      section: json['section'] as String?,
      stem: json['stem'] as String,
      options: List.unmodifiable((json['options'] as List).cast<String>()),
      answer: json['answer'] as int,
      explanation: explanation is Map ? explanation['es'] as String? : null,
      article: json['article'] as String?,
      notice: notice is Map ? notice['es'] as String? : null,
      flags: List.unmodifiable(
        (json['flags'] as List? ?? const []).cast<String>(),
      ),
      edition: json['edition'] as String,
      reviewed: json['reviewed'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.id == id &&
      other.tema == tema &&
      other.section == section &&
      other.stem == stem &&
      listEquals(other.options, options) &&
      other.answer == answer &&
      other.explanation == explanation &&
      other.article == article &&
      other.notice == notice &&
      listEquals(other.flags, flags) &&
      other.edition == edition &&
      other.reviewed == reviewed;

  @override
  int get hashCode => Object.hash(id, edition, stem, answer);

  @override
  String toString() => 'Question($id)';
}
