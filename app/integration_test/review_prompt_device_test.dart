import 'dart:io';
import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/format/civil_day.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/review/application/review_providers.dart';
import 'package:apto_armas/features/review/data/review_repository.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/screen_support.dart';
import 'support/qa_harness.dart' show QaTester;

/// Manual check of the iOS rating dialog on a REAL iPhone (development build,
/// where StoreKit always shows it; in TestFlight it never does).
///
/// Run only by hand, with the phone unlocked and watched:
/// `flutter test integration_test/review_prompt_device_test.dart -d UDID
/// --dart-define=REVIEW_PROMPT_DEVICE=1`. Without the define it is skipped,
/// so the QA battery is not affected. It starts a mock from Simulacro,
/// answers the twenty questions right, hands it in with the real button and
/// then waits so the person can see Apple's dialog over the result. The
/// database is a temporary file (deleted afterwards). Review preferences are
/// reset for the test and restored afterwards; an injected clock supplies five
/// distinct open days and seven days since first use before the real hand-in.
const bool _enabled = bool.fromEnvironment('REVIEW_PROMPT_DEVICE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a passed mock asks iOS for the rating dialog',
    (tester) async {
      expect(Platform.isIOS, isTrue);
      final temp = await tester.runAsync(getTemporaryDirectory) as Directory;
      final prefs = await tester.runAsync(
        SharedPreferences.getInstance,
      ) as SharedPreferences;
      final savedReview = prefs.getString(reviewStateKey);
      final savedLegacy = prefs.getString(legacyReviewVersionKey);
      addTearDown(() async {
        for (final entry in {
          reviewStateKey: savedReview,
          legacyReviewVersionKey: savedLegacy,
        }.entries) {
          if (entry.value == null) {
            await prefs.remove(entry.key);
          } else {
            await prefs.setString(entry.key, entry.value!);
          }
        }
      });
      await tester.runAsync(() async {
        await prefs.remove(reviewStateKey);
        await prefs.remove(legacyReviewVersionKey);
      });
      var now = DateTime(2026, 10, 1, 12);
      final dbPath =
          '${temp.path}${Platform.pathSeparator}'
          'review_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      addTearDown(() {
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final file = File('$dbPath$suffix');
          if (file.existsSync()) file.deleteSync();
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          retry: (count, error) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clockProvider.overrideWithValue(() => now),
            randomProvider.overrideWithValue(Random(3)),
            appDatabaseProvider.overrideWith((ref) {
              final db = AppDatabase(
                driftDatabase(
                  name: 'apto_review',
                  native: DriftNativeOptions(databasePath: () async => dbPath),
                ),
              );
              ref.onDispose(db.close);
              return db;
            }),
          ],
          child: const LeyAlBlancoApp(),
        ),
      );
      await tester.waitFor(
        find.byType(TemaCard),
        count: 7,
        timeout: const Duration(seconds: 90),
        reason: 'Inicio after the bootstrap',
      );

      final container = containerOf(tester);
      final review = container.read(reviewServiceProvider);
      await tester.runAsync(() async {
        // Flush the startup opening, then simulate returns on four more days.
        await review.recordOpen();
        for (var day = 2; day <= 5; day++) {
          now = DateTime(2026, 10, day, 12);
          await review.recordOpen();
        }
      });
      now = DateTime(2026, 10, 8, 12);
      final today = civilDay(now, deviceOffsetMinutes(now));
      final repository = container.read(reviewRepositoryProvider);
      final before = await tester.runAsync(() => repository.load(today));
      expect(before!.firstOpen, DateTime.utc(2026, 10, 1));
      expect(before.openDays, hasLength(5));
      expect(before.requestVersions, isEmpty);
      expect(before.lastRequest, isNull);
      expect(before.lastImport, isNull);
      expect(
        await tester.runAsync(
          () => container.read(mockRepositoryProvider).history(1),
        ),
        isEmpty,
      );

      await pushRoute(tester, '/simulacro');
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      final match = RegExp(r'^/simulacro/(\d+)$')
          .firstMatch(locationOf(tester));
      expect(match, isNotNull, reason: 'now on the running mock');
      final mockId = int.parse(match!.group(1)!);

      final controller = container.read(
        mockControllerProvider(mockId).notifier,
      );
      final state = await container.read(mockControllerProvider(mockId).future);
      for (var i = 0; i < state.session.length; i++) {
        controller.goTo(i);
        controller.select(state.session.questions[i].answer);
      }
      controller.goTo(0);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Entregar'),
        ),
      );
      await tester.pumpFor(const Duration(seconds: 3));
      expect(locationOf(tester), endsWith('/resultado'));
      final after = await tester.runAsync(() => repository.load(today));
      final info = await tester.runAsync(
        () => container.read(appInfoProvider.future),
      );
      expect(after!.requestVersions, [info!.version]);
      expect(after.lastRequest, today);
      expect(after.firstOpen, before.firstOpen);
      expect(after.openDays, containsAll(before.openDays));
      expect(prefs.getString(reviewStateKey), isNotNull);
      expect(prefs.getString(legacyReviewVersionKey), isNull);
      final history = await tester.runAsync(
        () => container.read(mockRepositoryProvider).history(1),
      );
      expect(history!.single.id, mockId);
      expect(history.single.isFinished, isTrue);
      expect(history.single.passed, isTrue);

      // Time to look at (and dismiss) Apple's dialog on the phone.
      await tester.pumpFor(const Duration(seconds: 20));
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
