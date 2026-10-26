import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../core/providers.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/same_stem_groups.dart';
import '../../quiz/application/quiz_providers.dart';
import '../data/mock_repository.dart';
import '../domain/mock_config.dart';
import 'mock_service.dart';

final mockRepositoryProvider = Provider<MockRepository>(
  (ref) => MockRepository(ref.watch(appDatabaseProvider)),
);

/// The exam shape: the manifest's optional `mock` block over the defaults
/// (20 questions, pass with 16, proportional split).
final mockConfigProvider = FutureProvider<MockConfig>((ref) async {
  final bootstrap = await ref.watch(bootstrapProvider.future);
  final mock = bootstrap.manifest.mock;
  if (mock == null) return MockConfig();
  return MockConfig.withDefaults(
    size: mock.size,
    passMark: mock.passMark,
    distribution: mock.distribution,
    avoidLastMocks: mock.avoidLastMocks,
  );
});

/// Groups of questions with the same stem; a mock never holds two of one
/// group. Computed once per bank (the provider caches it).
final exclusionGroupsProvider = FutureProvider<List<Set<String>>>((ref) async {
  return sameStemGroups(await ref.watch(questionsProvider.future));
});

final mockServiceProvider = Provider<MockService>((ref) {
  return MockService(
    db: ref.watch(appDatabaseProvider),
    mocks: ref.watch(mockRepositoryProvider),
    study: ref.watch(studyServiceProvider),
    // Read at call time, not watched: the service must not be rebuilt every
    // time the bank providers refresh.
    loadQuestions: () => ref.read(questionsProvider.future),
    loadConfig: () => ref.read(mockConfigProvider.future),
    loadExclusionGroups: () => ref.read(exclusionGroupsProvider.future),
    clock: ref.watch(clockProvider),
    rng: ref.watch(randomProvider),
  );
});

/// Number of finished mocks.
final mockCountProvider = StreamProvider<int>(
  (ref) => ref.watch(mockRepositoryProvider).watchFinishedCount(),
);

/// The latest finished mocks, newest first. Recomputed when the count changes.
final mockHistoryProvider = FutureProvider<List<MockRecord>>((ref) async {
  await ref.watch(mockCountProvider.future);
  return ref.watch(mockRepositoryProvider).history(20);
});

/// The mock left open (never handed in) with the highest id, live; null when
/// there is none. The app keeps at most one open (`MockService.startMock`).
final unfinishedMockProvider = StreamProvider<MockRecord?>(
  (ref) => ref.watch(mockRepositoryProvider).watchLatestUnfinished(),
);

/// Latest open exam, available to everyone.
final resumableMockProvider = Provider<MockRecord?>(
  (ref) => ref.watch(unfinishedMockProvider).value,
);
