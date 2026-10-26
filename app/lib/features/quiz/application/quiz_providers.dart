import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../srs/application/srs_providers.dart';
import '../data/attempt_repository.dart';
import '../domain/attempt.dart';
import 'study_service.dart';

final attemptRepositoryProvider = Provider<AttemptRepository>(
  (ref) => AttemptRepository(ref.watch(appDatabaseProvider)),
);

/// Every attempt (all modes), oldest first, re-emitted on each change. All
/// progress state (mastery, Fallos, queue, probability) derives from this.
final attemptsProvider = StreamProvider<List<Attempt>>(
  (ref) => ref.watch(attemptRepositoryProvider).watchAll(),
);

/// The single entry point to record answers from any mode.
final studyServiceProvider = Provider<StudyService>(
  (ref) => StudyService(
    db: ref.watch(appDatabaseProvider),
    attempts: ref.watch(attemptRepositoryProvider),
    srs: ref.watch(srsRepositoryProvider),
  ),
);
