import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/application/content_providers.dart';

/// Questions available in Cifras y plazos and its flashcards.
final figuresCountProvider = FutureProvider<int>(
  (ref) async =>
      (await ref.watch(questionsProvider.future))
          .where((q) => q.isFigures)
          .length,
);
