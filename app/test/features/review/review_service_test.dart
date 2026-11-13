import 'dart:async';
import 'dart:convert';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/format/civil_day.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/review/application/review_providers.dart';
import 'package:apto_armas/features/review/data/review_repository.dart';
import 'package:apto_armas/features/review/domain/review_policy.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/db_support.dart';
import 'review_test_support.dart';

class GatedRepository extends ReviewRepository {
  GatedRepository(super.prefs);
  Completer<void>? gate;
  bool failSave = false;
  final savingRequest = Completer<void>();
  @override
  Future<void> save(ReviewState state) async {
    if (failSave) throw StateError('storage failed');
    if (state.requestVersions.isNotEmpty && gate != null) {
      if (!savingRequest.isCompleted) savingRequest.complete();
      await gate!.future;
    }
    await super.save(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AppDatabase db;
  late FakeStore store;
  late ProviderContainer container;
  late ReviewService service;
  late GatedRepository repository;
  late DateTime now;
  var version = '1.2.0';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = openTestDatabase();
    store = FakeStore();
    now = DateTime(2026, 10, 8, 12);
    version = '1.2.0';
    repository = GatedRepository(prefs);
    container = ProviderContainer(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        storeReviewPlatformProvider.overrideWithValue(store),
        appInfoProvider.overrideWith((ref) async => AppInfo(version: version)),
      ],
    );
    service = container.read(reviewServiceProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<ReviewState> state() => container
      .read(reviewRepositoryProvider)
      .load(civilDay(now, deviceOffsetMinutes(now)));
  Future<void> ready({bool hasMock = true}) async {
    for (var i = 1; i <= 5; i++) {
      now = DateTime(2026, 10, i, 12);
      await service.recordOpen();
    }
    now = DateTime(2026, 10, 8, 12);
    if (hasMock) {
      final id = await db.mocksDao.create(
        questionIds: [],
        timed: false,
        startedAt: now,
      );
      await db.mocksDao.finish(
        id,
        answers: [],
        correctCount: 0,
        passed: true,
        finishedAt: now,
      );
    }
  }

  test(
    'opens use injected civil day, distinct days survive recreation',
    () async {
      await ready();
      await Future.wait([service.recordOpen(), service.recordOpen()]);
      expect((await state()).openDays.length, 6);
      container.invalidate(reviewServiceProvider);
      service = container.read(reviewServiceProvider);
      await service.recordOpen();
      expect((await state()).openDays.length, 6);
      now = DateTime(2026, 10, 1, 23, 59);
      await service.recordOpen();
      expect((await state()).openDays.length, 6);
      expect((await state()).firstOpen, DateTime.utc(2026, 10, 1));
    },
  );
  test(
    'two simultaneous triggers request once and preserve a queued open',
    () async {
      await ready();
      store.gate = Completer<void>();
      final first = service.afterMock(passed: true);
      await store.checking.future;
      final second = service.afterMock(passed: true);
      final open = service.recordOpen();
      await open.timeout(const Duration(seconds: 5));
      expect((await state()).openDays.length, 6);
      store.gate!.complete();
      await Future.wait([first, second, open]);
      expect(store.requests, 1);
      expect((await state()).requestVersions, ['1.2.0']);
      expect((await state()).openDays.length, 6);
    },
  );
  test('rejects failure, first use and missing finished mocks', () async {
    await service.afterMock(passed: true);
    await ready(hasMock: false);
    await service.afterMock(passed: false);
    await service.afterMock(passed: true);
    expect(store.requests, 0);
  });
  test('unavailable store consumes no request', () async {
    await ready();
    store.available = false;
    await service.afterMock(passed: true);
    expect(store.requests, 0);
    expect((await state()).requestVersions, isEmpty);
  });
  for (final failure in ['available', 'request', 'listing']) {
    test(
      'swallows $failure errors and keeps the serial queue usable',
      () async {
        await ready();
        store.fail = failure;
        await service.afterMock(passed: true);
        await service.openStoreListing();
        await service.recordOpen();
        expect((await state()).openDays.length, 6);
        expect(
          (await state()).requestVersions.length,
          failure == 'available' ? 0 : 1,
        );
      },
    );
  }
  test(
    'silence is rechecked when an import starts during isAvailable',
    () async {
      await ready();
      store.gate = Completer<void>();
      final asking = service.afterMock(passed: true);
      await store.checking.future;
      final importing = service.beginImport();
      store.gate!.complete();
      await Future.wait([asking, importing]);
      await service.endImport();
      expect(store.requests, 0);
      expect((await state()).requestVersions, isEmpty);
      container.invalidate(reviewServiceProvider);
      service = container.read(reviewServiceProvider);
      now = DateTime(2026, 10, 14, 23, 59);
      await service.afterMock(passed: true);
      expect(store.requests, 0);
      now = DateTime(2026, 10, 15);
      await service.afterMock(passed: true);
      expect(store.requests, 1);
    },
  );
  test('an active import blocks even if seven days pass meanwhile', () async {
    await ready();
    await service.beginImport();
    now = DateTime(2026, 10, 20);
    await service.afterMock(passed: true);
    expect(store.requests, 0);
    await service.endImport();
    await service.afterMock(passed: true);
    expect(store.requests, 0);
  });
  test(
    'rechecks import immediately before request after preference write',
    () async {
      await ready();
      repository.gate = Completer<void>();
      final asking = service.afterMock(passed: true);
      await repository.savingRequest.future;
      final importing = service.beginImport();
      repository.gate!.complete();
      await Future.wait([asking, importing]);
      await service.endImport();
      expect(store.requests, 0);
    },
  );
  test(
    'migrates old iOS key once and waits ninety days conservatively',
    () async {
      await prefs.setString(legacyReviewVersionKey, '1.0.1');
      await ready();
      expect((await state()).requestVersions, ['1.0.1']);
      await service.afterMock(passed: true);
      expect(store.requests, 0);
      now = DateTime(
        2026,
        12,
        30,
        12,
      ); // 90 civil days after migration on Oct 1.
      await service.afterMock(passed: true);
      expect(store.requests, 1);
      final reloaded = ReviewRepository(prefs);
      expect((await reloaded.load(DateTime.utc(2027))).requestVersions, [
        '1.0.1',
        '1.2.0',
      ]);
    },
  );
  test(
    'new version still waits ninety days; lifetime count survives restart',
    () async {
      await ready();
      await service.afterMock(passed: true);
      version = '1.3.0';
      container.invalidate(appInfoProvider);
      await service.afterMock(passed: true);
      expect(store.requests, 1);
      now = DateTime(2027, 1, 6, 12); // 90 days after Oct 8.
      await service.afterMock(passed: true);
      expect(store.requests, 2);
      container.invalidate(reviewServiceProvider);
      service = container.read(reviewServiceProvider);
      version = '1.4.0';
      container.invalidate(appInfoProvider);
      now = DateTime(2027, 4, 6, 12);
      await service.afterMock(passed: true);
      version = '1.5.0';
      container.invalidate(appInfoProvider);
      now = DateTime(2027, 7, 5, 12);
      await service.afterMock(passed: true);
      expect(store.requests, 3);
      expect((await state()).requestVersions.length, 3);
    },
  );
  test('storage write errors stay silent and do not break the queue', () async {
    await ready();
    repository.failSave = true;
    await service.afterMock(passed: true);
    await service.recordOpen();
    expect(store.requests, 0);
    repository.failSave = false;
    await service.afterMock(passed: true);
    expect(store.requests, 1);
  });
  test(
    'corrupt counters skip requests instead of resetting lifetime count',
    () async {
      await ready();
      await prefs.setString(reviewStateKey, '{broken');
      await service.afterMock(passed: true);
      await service.recordOpen();
      expect(store.requests, 0);
      expect(prefs.getString(reviewStateKey), '{broken');
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('plugin uses in_app_review for $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('dev.britannio.in_app_review');
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'isAvailable' ? true : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const plugin = PluginStoreReviewPlatform();
      expect(await plugin.isAvailable(), isTrue);
      await plugin.requestReview();
      expect(calls, ['isAvailable', 'requestReview']);
    });
  }
  test('unsupported platforms skip automatic requests', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(await const PluginStoreReviewPlatform().isAvailable(), isFalse);
  });
  test('state stored as one JSON value', () async {
    await ready();
    expect(
      jsonDecode(prefs.getString(reviewStateKey)!),
      (await state()).toJson(),
    );
  });
}
