import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/application/content_providers.dart';
import '../../quiz/application/quiz_providers.dart';
import '../domain/mistakes.dart';

/// All current failures, optionally limited to one tema; retired ids excluded.
final mistakesProvider = FutureProvider.family<List<MistakeEntry>, int?>((
  ref,
  tema,
) async {
  final temaById = await ref.watch(temaByIdProvider.future);
  final attempts = await ref.watch(attemptsProvider.future);
  return mistakes(
    attempts,
    temaById: temaById,
    tema: tema,
  ).where((entry) => temaById.containsKey(entry.questionId)).toList();
});
