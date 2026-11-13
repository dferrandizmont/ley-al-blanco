import 'dart:async';

import 'package:apto_armas/features/review/application/review_providers.dart';

class FakeStore implements StoreReviewPlatform {
  bool available = true;
  String? fail;
  int requests = 0;
  int listings = 0;
  Completer<void>? gate;
  Completer<void>? requestGate;
  final checking = Completer<void>();
  final requesting = Completer<void>();
  @override
  Future<bool> isAvailable() async {
    if (!checking.isCompleted) checking.complete();
    await gate?.future;
    if (fail == 'available') throw StateError('unavailable');
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (!requesting.isCompleted) requesting.complete();
    await requestGate?.future;
    if (fail == 'request') throw StateError('request failed');
  }

  @override
  Future<void> openStoreListing() async {
    listings++;
    if (fail == 'listing') throw StateError('listing failed');
  }
}
