import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/providers.dart';
import '../data/question_repository.dart';
import '../domain/question.dart';

/// The question bank repository.
///
/// Watches [bootstrapProvider] on purpose: the repository caches the bank, and
/// the bank only changes when the bootstrap (import) runs, so a bootstrap
/// finishing or being invalidated rebuilds the repository with an empty cache.
/// (A repository created while the import is still running never serves its
/// pre-import, possibly empty, snapshot.)
final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  ref.watch(bootstrapProvider);
  return QuestionRepository(ref.watch(appDatabaseProvider));
});

/// The active questions in bank order, once the bootstrap (database + import)
/// has finished. Errors from the bootstrap surface here too.
final questionsProvider = FutureProvider<List<Question>>((ref) async {
  await ref.watch(bootstrapProvider.future);
  return ref.watch(questionRepositoryProvider).active();
});

/// Question id -> tema, for the active bank.
final temaByIdProvider = FutureProvider<Map<String, int>>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  return {for (final question in questions) question.id: question.tema};
});
