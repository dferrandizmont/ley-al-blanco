import 'dart:math';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/application/study_service.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:apto_armas/features/srs/data/srs_repository.dart';
import 'package:apto_armas/features/srs/domain/srs_card.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'db_support.dart';

/// "Now" of the data-layer tests: Thursday 15 Oct 2026, 18:30 (local).
final DateTime kStudyNow = DateTime(2026, 10, 15, 18, 30);

/// A container with an in-memory database, the real bank, a pinned clock and
/// a seeded random source. Disposed (and the database closed) after the test.
///
ProviderContainer makeStudyContainer({
  DateTime? now,

  /// A clock the test moves (wins over [now]).
  DateTime Function()? clock,
  int seed = 1,
  AssetBundle? bundle,
  List<Override> overrides = const [],

  /// An already open database instead of a fresh in-memory one (the caller
  /// closes it).
  AppDatabase? database,
}) {
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      ...databaseTestOverrides(bundle: bundle, database: database),
      clockProvider.overrideWithValue(clock ?? () => now ?? kStudyNow),
      randomProvider.overrideWithValue(Random(seed)),
      ...overrides,
    ],
  );
  // Riverpod 3 pauses a stream provider nobody listens to, and `read` does not
  // count as listening. In the app the screens watch these; here we stand in
  // for them so `read(x.future)` always sees live data.
  container
    ..listen(attemptsProvider, (previous, next) {})
    ..listen(srsCardsProvider, (previous, next) {})
    ..listen(mockCountProvider, (previous, next) {});
  addTearDown(container.dispose);
  return container;
}

/// Lets Drift's stream queries re-emit and the derived providers invalidate
/// after a write.
Future<void> settle() => pumpEventQueue(times: 50);

/// An attempt on [question]; [correct] picks the official answer or a wrong
/// option.
Attempt attemptOn(
  Question question, {
  required bool correct,
  DateTime? at,
  AttemptMode mode = AttemptMode.practice,
  int? mockId,
}) => Attempt(
  questionId: question.id,
  mode: mode,
  selected: correct ? question.answer : wrongOption(question),
  correct: correct,
  answeredAt: at ?? kStudyNow,
  mockId: mockId,
);

/// An option that is not the official answer.
int wrongOption(Question question) => (question.answer + 1) % 3;

/// An SRS repository whose [failOn]-th `upsert` (1-based) throws, to prove
/// that multi-step writes are atomic.
class FailingSrsRepository extends SrsRepository {
  FailingSrsRepository(super.db, {required this.failOn});

  final int failOn;
  var _calls = 0;

  @override
  Future<void> upsert(SrsCard card) async {
    if (++_calls == failOn) throw StateError('simulated SRS failure');
    return super.upsert(card);
  }
}

/// A [StudyService] on [container]'s database whose SRS write fails on the
/// [failOn]-th card.
StudyService failingStudyService(
  ProviderContainer container, {
  required int failOn,
}) {
  final db = container.read(appDatabaseProvider);
  return StudyService(
    db: db,
    attempts: container.read(attemptRepositoryProvider),
    srs: FailingSrsRepository(db, failOn: failOn),
  );
}
