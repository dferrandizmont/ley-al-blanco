import 'dart:async';
import 'dart:math' show Random;

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/application/mock_service.dart';
import 'package:apto_armas/features/mock/domain/mock_result.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/quiz_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

/// A [MockService] whose `finishMock` waits for [gate] (so a test can act
/// while "Entregar" is in flight) and can be told to fail with [failure].
/// Everything else, and the work after the wait, is the real service.
class GatedMockService implements MockService {
  GatedMockService(this.inner);

  final MockService inner;

  /// `finishMock` does not start until this completes.
  final Completer<void> gate = Completer<void>();

  /// When set, `finishMock` throws it after the gate.
  Object? failure;

  /// How many times `finishMock` was entered.
  int finishCalls = 0;

  @override
  Future<StartedMock> startMock({
    required bool timed,
    Random? rng,
    int? replaceUnfinishedId,
  }) => inner.startMock(
    timed: timed,
    rng: rng,
    replaceUnfinishedId: replaceUnfinishedId,
  );

  @override
  Future<MockResult> finishMock(int mockId, QuizSession session) async {
    finishCalls++;
    await gate.future;
    if (failure case final error?) throw error;
    return inner.finishMock(mockId, session);
  }
}

/// Builds the real [MockService] the way `mockServiceProvider` does.
MockService realMockService(Ref ref) => MockService(
  db: ref.watch(appDatabaseProvider),
  mocks: ref.watch(mockRepositoryProvider),
  study: ref.watch(studyServiceProvider),
  loadQuestions: () => ref.read(questionsProvider.future),
  loadConfig: () => ref.read(mockConfigProvider.future),
  loadExclusionGroups: () => ref.read(exclusionGroupsProvider.future),
  clock: ref.watch(clockProvider),
  rng: ref.watch(randomProvider),
);
