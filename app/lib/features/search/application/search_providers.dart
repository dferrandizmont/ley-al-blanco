import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/application/content_providers.dart';
import '../../content/domain/question.dart';
import '../domain/question_search.dart';

/// The active bank folded for searching, built once per bank.
final searchIndexProvider = FutureProvider<QuestionSearchIndex>(
  (ref) async => QuestionSearchIndex(await ref.watch(questionsProvider.future)),
);

/// All matches, in bank order.
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<Question>, String>((ref, query) async {
      final index = await ref.watch(searchIndexProvider.future);
      return index.search(query);
    });
