import 'question.dart';

const _accentFolding = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

final _nonAlphanumeric = RegExp('[^a-z0-9]+');

/// Normalises a question stem for comparison: lowercase, Spanish accents and
/// diacritics folded to ASCII (including `ñ` -> `n`), every run of
/// non-alphanumeric characters replaced by one space, then trimmed.
///
/// Two stems that only differ in case, accents, punctuation or whitespace get
/// the same key.
String normalizeStem(String stem) {
  final buffer = StringBuffer();
  for (final rune in stem.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentFolding[char] ?? char);
  }
  return buffer.toString().replaceAll(_nonAlphanumeric, ' ').trim();
}

/// Groups (size >= 2) of question ids whose stems are equal once normalised
/// with [normalizeStem].
///
/// The questionnaire has pairs of questions with the same stem but different
/// options (plan 'Hallazgos del hito 1'). They are distinct questions and are
/// kept, but a mock must never contain two of the same group (plan 2.4); the
/// mock generator receives these groups as its exclusion groups.
///
/// Groups come out in order of first appearance in [questions]; ids inside a
/// group keep the input order.
List<Set<String>> sameStemGroups(Iterable<Question> questions) {
  final byStem = <String, Set<String>>{};
  for (final question in questions) {
    final key = normalizeStem(question.stem);
    if (key.isEmpty) continue;
    byStem.putIfAbsent(key, () => <String>{}).add(question.id);
  }
  return [
    for (final ids in byStem.values)
      if (ids.length >= 2) ids,
  ];
}
