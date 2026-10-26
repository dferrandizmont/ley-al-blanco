/// Length of the optional, indicative mock countdown. The real exam time is
/// not in the BOE (spec §2); this is only a guide and never ends the mock.
const Duration kMockIndicativeDuration = Duration(minutes: 20);

/// Time left on the indicative countdown of a mock started at [startedAt];
/// never negative.
Duration mockRemaining({
  required DateTime startedAt,
  required DateTime now,
  Duration total = kMockIndicativeDuration,
}) {
  final left = startedAt.add(total).difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// `mm:ss` for a countdown: 12 min 5 s -> "12:05". Seconds round up so the
/// display only reaches "00:00" when the time is really over.
String formatCountdown(Duration remaining) {
  final seconds = (remaining.inMilliseconds / 1000).ceil();
  final safe = seconds < 0 ? 0 : seconds;
  final mm = (safe ~/ 60).toString().padLeft(2, '0');
  final ss = (safe % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}
