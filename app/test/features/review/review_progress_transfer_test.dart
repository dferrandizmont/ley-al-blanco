import 'dart:async';
import 'dart:convert';

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/progress_transfer/application/progress_transfer_providers.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_codec_runner.dart';
import 'package:apto_armas/features/review/application/review_providers.dart';
import 'package:apto_armas/features/review/data/review_repository.dart';
import 'package:apto_armas/features/review/domain/review_policy.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/settings_support.dart';
import '../../support/study_support.dart';
import 'review_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final pendingCall in ['isAvailable', 'requestReview']) {
    test('import completes while $pendingCall is pending', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<void>();
      final store = FakeStore();
      if (pendingCall == 'isAvailable') {
        store.gate = gate;
      } else {
        store.requestGate = gate;
      }
      var now = DateTime(2026, 10, 1, 12);
      final c = makeStudyContainer(
        clock: () => now,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storeReviewPlatformProvider.overrideWithValue(store),
          progressCodecRunnerProvider.overrideWithValue(
            const InlineProgressCodecRunner(),
          ),
          appInfoProvider.overrideWith(
            (ref) async => const AppInfo(version: '1.2.0'),
          ),
        ],
      );
      await c.read(questionsProvider.future);
      final service = c.read(reviewServiceProvider);
      for (var day = 1; day <= 5; day++) {
        now = DateTime(2026, 10, day, 12);
        await service.recordOpen();
      }
      now = DateTime(2026, 10, 15, 12);
      final db = c.read(appDatabaseProvider);
      final mock = await db.mocksDao.create(
        questionIds: [],
        timed: false,
        startedAt: now,
      );
      await db.mocksDao.finish(
        mock,
        answers: [],
        correctCount: 0,
        passed: true,
        finishedAt: now,
      );
      final transfer = c.read(progressTransferProvider);
      final plan = await transfer.preview(progressFileBytes());
      final asking = service.afterMock(passed: true);
      var finishedAsking = false;
      final completed = asking.then((_) => finishedAsking = true);
      try {
        await (pendingCall == 'isAvailable'
                ? store.checking.future
                : store.requesting.future)
            .timeout(const Duration(seconds: 5));
        await transfer.apply(plan).timeout(const Duration(seconds: 5));
        expect(gate.isCompleted, isFalse);
        expect(finishedAsking, isFalse);
        final state = await c
            .read(reviewRepositoryProvider)
            .load(DateTime.utc(2026, 10, 15));
        expect(state.lastImport, DateTime.utc(2026, 10, 15));
        expect(state.openDays, hasLength(5));
        expect(
          state.requestVersions,
          pendingCall == 'isAvailable' ? isEmpty : ['1.2.0'],
        );
        expect((await db.mocksDao.recent(10)).single.passed, isFalse);
      } finally {
        gate.complete();
        await completed;
      }
      // A completed import still suppresses the pending availability result.
      expect(store.requests, pendingCall == 'isAvailable' ? 0 : 1);
      await service.afterMock(passed: true);
      expect(store.requests, pendingCall == 'isAvailable' ? 0 : 1);
    });
  }
  test(
    'progress export excludes device counters; import only adds silence',
    () async {
      SharedPreferences.setMockInitialValues({legacyReviewVersionKey: '0.9.0'});
      final prefs = await SharedPreferences.getInstance();
      final c = makeStudyContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          progressCodecRunnerProvider.overrideWithValue(
            const InlineProgressCodecRunner(),
          ),
          appInfoProvider.overrideWith(
            (ref) async => const AppInfo(version: '1.2.0'),
          ),
        ],
      );
      await c.read(questionsProvider.future);
      final repository = c.read(reviewRepositoryProvider);
      final initial = const ReviewState()
          .withOpen(DateTime.utc(2026, 10, 1))
          .withRequest(DateTime.utc(2026, 10, 8), '1.1.0');
      await repository.save(initial);
      final transfer = c.read(progressTransferProvider);
      final export = await transfer.buildExport();
      final json = utf8.decode(export.bytes);
      for (final key in [
        reviewStateKey,
        legacyReviewVersionKey,
        'firstOpen',
        'openDays',
        'requestVersions',
        'lastRequest',
        'lastImport',
      ]) {
        expect(json, isNot(contains('"$key"')));
      }
      expect(jsonDecode(json)['settings'], isNot(contains(reviewStateKey)));
      final plan = await transfer.preview(progressFileBytes());
      await transfer.apply(plan);
      final after = await repository.load(DateTime.utc(2026, 10, 15));
      expect(
        after.toJson(),
        initial.withImport(DateTime.utc(2026, 10, 15)).toJson(),
      );
      expect(prefs.getString(legacyReviewVersionKey), '0.9.0');
      final secondExport = await transfer.buildExport();
      expect(utf8.decode(secondExport.bytes), isNot(contains('"lastImport"')));
      expect(
        utf8.decode(secondExport.bytes),
        isNot(contains('"requestVersions"')),
      );
    },
  );
}
