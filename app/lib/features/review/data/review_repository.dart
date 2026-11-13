import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/review_policy.dart';

const reviewStateKey = 'review.state';
const legacyReviewVersionKey = 'review_prompt.version';

/// Preferences stay on this device: progress transfers only read Drift.
class ReviewRepository {
  ReviewRepository(this._prefs);

  final SharedPreferences _prefs;
  Future<void> _tail = Future<void>.value();

  /// All read-modify-writes, including migration and imports, share this queue.
  Future<T> serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<ReviewState> load(DateTime today) async {
    final raw = _prefs.getString(reviewStateKey);
    if (raw != null) {
      // Unreadable counters must not reset the lifetime limit: the service
      // catches decoding failures and skips the request.
      return ReviewState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final legacy = _prefs.getString(legacyReviewVersionKey);
    final state = legacy == null
        ? const ReviewState()
        // The old key has no date: wait 90 days from migration conservatively.
        : ReviewState(requestVersions: [legacy], lastRequest: today);
    if (legacy != null) await save(state);
    return state;
  }

  Future<void> save(ReviewState state) async {
    if (!await _prefs.setString(reviewStateKey, jsonEncode(state.toJson()))) {
      throw StateError('Review counters could not be saved');
    }
  }
}
