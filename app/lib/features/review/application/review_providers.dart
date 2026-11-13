import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../../core/format/civil_day.dart';
import '../../../core/providers.dart';
import '../../mock/application/mock_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../data/review_repository.dart';
import '../domain/review_policy.dart';

abstract class StoreReviewPlatform {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing();
}

class PluginStoreReviewPlatform implements StoreReviewPlatform {
  const PluginStoreReviewPlatform();

  @override
  Future<bool> isAvailable() async =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      await InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() =>
      InAppReview.instance.openStoreListing(appStoreId: '6831621176');
}

final storeReviewPlatformProvider = Provider<StoreReviewPlatform>(
  (ref) => const PluginStoreReviewPlatform(),
);
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(sharedPreferencesProvider)),
);
final reviewServiceProvider = Provider<ReviewService>(ReviewService.new);

class ReviewService {
  ReviewService(this._ref);

  final Ref _ref;
  int _imports = 0;
  DateTime? _quietSince;

  DateTime get _today {
    final now = _ref.read(clockProvider)();
    return civilDay(now, deviceOffsetMinutes(now));
  }

  ReviewRepository get _repository => _ref.read(reviewRepositoryProvider);

  Future<void> recordOpen() async {
    try {
      await _repository.serial(() async {
        final today = _today;
        await _repository.save((await _repository.load(today)).withOpen(today));
      });
    } on Object {
      // Optional counters must never interrupt startup.
    }
  }

  /// Marks the import synchronously, even while a counter write is pending.
  Future<void> beginImport() {
    _imports++;
    return _markImport();
  }

  Future<void> endImport() async {
    try {
      await _markImport();
    } finally {
      _imports--;
    }
  }

  Future<void> _markImport() async {
    _quietSince = _today;
    try {
      await _repository.serial(() async {
        final today = _today;
        await _repository.save(
          (await _repository.load(today)).withImport(today),
        );
      });
    } on Object {
      // Keep the in-memory silence even when persistence fails.
    }
  }

  Future<void> afterMock({required bool passed}) async {
    if (!passed) return;
    try {
      final version = (await _ref.read(appInfoProvider.future)).version;
      final hasMock = (await _ref.read(mockRepositoryProvider).history(1))
          .isNotEmpty;
      bool allowed(ReviewState state) =>
          _ref.mounted &&
          !ReviewPolicy.isQuiet(_today, _quietSince) &&
          ReviewPolicy.shouldAsk(
            state: state,
            today: _today,
            version: version,
            hasFinishedMock: hasMock,
            inFirstUse:
                state.firstOpen == null ||
                daysBetween(state.firstOpen!, _today) <= 0,
            importing: _imports > 0,
          );
      final eligible = await _repository.serial(
        () async => allowed(await _repository.load(_today)),
      );
      if (!eligible) return;
      final platform = _ref.read(storeReviewPlatformProvider);
      // Store calls must never hold the counters queue or block an import.
      if (!await platform.isAvailable() || !_ref.mounted) return;
      final claimed = await _repository.serial(() async {
        final state = await _repository.load(_today);
        if (!allowed(state)) return false;
        // Claim before requesting: a failed request still consumes its slot.
        await _repository.save(state.withRequest(_today, version));
        return true;
      });
      if (!claimed || !_ref.mounted) return;
      // Re-read persisted silence after claiming; an import may have run
      // during availability or the preference write. No await between the
      // final in-memory checks and starting the platform request.
      final state = await _repository.serial(() => _repository.load(_today));
      if (!_ref.mounted ||
          _imports > 0 ||
          ReviewPolicy.isQuiet(_today, _quietSince) ||
          ReviewPolicy.isQuiet(_today, state.lastImport)) {
        return;
      }
      await platform.requestReview();
    } on Object {
      // Store availability, package metadata and storage errors stay silent.
    }
  }

  Future<void> openStoreListing() async {
    try {
      await _ref.read(storeReviewPlatformProvider).openStoreListing();
    } on Object {
      // No usable store on this device.
    }
  }
}
