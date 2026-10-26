import 'package:flutter/foundation.dart' show immutable;

import '../../content/domain/question.dart';
import '../../theory/domain/theory.dart' show foldForSearch, searchWords;

/// Shortest single word the search accepts; a lone letter would match the
/// whole bank.
const int kMinSearchWordLength = 2;

/// Whether [query] is worth searching: at least two letters, or several words.
bool isSearchable(String query) {
  final words = searchWords(query);
  return words.length > 1 ||
      (words.length == 1 && words.single.length >= kMinSearchWordLength);
}

/// The bank folded once for searching: each question's stem and options
/// without accents or capitals (the same folding as the glossary). A question
/// matches when **every** word of the query appears in that text.
@immutable
class QuestionSearchIndex {
  QuestionSearchIndex(Iterable<Question> questions)
    : _entries = [
        for (final question in questions)
          (
            question: question,
            text: foldForSearch(
              '${question.stem} ${question.options.join(' ')}',
            ),
          ),
      ];

  final List<({Question question, String text})> _entries;

  /// The questions that match [query], in bank order. Empty for a query that
  /// is not [isSearchable].
  List<Question> search(String query) {
    if (!isSearchable(query)) return const [];
    final words = searchWords(query);
    return [
      for (final entry in _entries)
        if (words.every(entry.text.contains)) entry.question,
    ];
  }
}
