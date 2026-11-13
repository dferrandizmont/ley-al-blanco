import '../../../core/format/civil_day.dart';

/// Device-local history. Civil dates are UTC midnights, never instants.
class ReviewState {
  const ReviewState({
    this.firstOpen,
    this.openDays = const {},
    this.requestVersions = const [],
    this.lastRequest,
    this.lastImport,
  });

  final DateTime? firstOpen;
  final Set<String> openDays;
  final List<String> requestVersions;
  final DateTime? lastRequest;
  final DateTime? lastImport;

  ReviewState withOpen(DateTime day) => ReviewState(
    firstOpen: firstOpen ?? day,
    openDays: {...openDays, isoDayOf(day)},
    requestVersions: requestVersions,
    lastRequest: lastRequest,
    lastImport: lastImport,
  );

  ReviewState withRequest(DateTime day, String version) => ReviewState(
    firstOpen: firstOpen,
    openDays: openDays,
    requestVersions: [...requestVersions, version],
    lastRequest: day,
    lastImport: lastImport,
  );

  ReviewState withImport(DateTime day) => ReviewState(
    firstOpen: firstOpen,
    openDays: openDays,
    requestVersions: requestVersions,
    lastRequest: lastRequest,
    lastImport: day,
  );

  Map<String, Object?> toJson() => {
    'firstOpen': firstOpen == null ? null : isoDayOf(firstOpen!),
    'openDays': openDays.toList(),
    'requestVersions': requestVersions,
    'lastRequest': lastRequest == null ? null : isoDayOf(lastRequest!),
    'lastImport': lastImport == null ? null : isoDayOf(lastImport!),
  };

  factory ReviewState.fromJson(Map<String, dynamic> json) => ReviewState(
    firstOpen: parseIsoDay(json['firstOpen'] as String?),
    openDays: (json['openDays'] as List).cast<String>().toSet(),
    requestVersions: (json['requestVersions'] as List).cast<String>(),
    lastRequest: parseIsoDay(json['lastRequest'] as String?),
    lastImport: parseIsoDay(json['lastImport'] as String?),
  );
}

abstract final class ReviewPolicy {
  static bool isQuiet(DateTime today, DateTime? importedOn) =>
      importedOn != null && daysBetween(importedOn, today) < 7;

  static bool shouldAsk({
    required ReviewState state,
    required DateTime today,
    required String version,
    required bool hasFinishedMock,
    required bool inFirstUse,
    required bool importing,
  }) {
    if (inFirstUse || importing || !hasFinishedMock || version.isEmpty) {
      return false;
    }
    final first = state.firstOpen;
    if (first == null || daysBetween(first, today) < 7) return false;
    if (state.openDays.length < 5) return false;
    if (isQuiet(today, state.lastImport)) return false;
    if (state.requestVersions.length >= 3 ||
        state.requestVersions.contains(version)) {
      return false;
    }
    final last = state.lastRequest;
    return last == null || daysBetween(last, today) >= 90;
  }
}
