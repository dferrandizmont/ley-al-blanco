import 'package:apto_armas/core/format/civil_day.dart';
import 'package:apto_armas/features/review/domain/review_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = DateTime.utc(2026, 10, 1);
  final today = DateTime.utc(2026, 10, 8);
  ReviewState ready({int days = 5}) => ReviewState(
    firstOpen: first,
    openDays: {for (var i = 0; i < days; i++) isoDayOf(addCivilDays(first, i))},
  );
  bool asks(
    ReviewState state, {
    DateTime? on,
    String version = '1.2.0',
    bool hasMock = true,
    bool firstUse = false,
    bool importing = false,
  }) => ReviewPolicy.shouldAsk(
    state: state,
    today: on ?? today,
    version: version,
    hasFinishedMock: hasMock,
    inFirstUse: firstUse,
    importing: importing,
  );

  test('all conditions hold at exactly seven days and five open days', () {
    expect(asks(ready()), isTrue);
    expect(asks(ready(), on: addCivilDays(today, -1)), isFalse);
    expect(asks(ready(), on: addCivilDays(today, 1)), isTrue);
    expect(asks(const ReviewState()), isFalse);
    expect(asks(ready(days: 4)), isFalse);
    expect(asks(ready(days: 6)), isTrue);
  });
  test('needs a finished mock and excludes first use and active imports', () {
    expect(asks(ready(), hasMock: false), isFalse);
    expect(asks(ready(), firstUse: true), isFalse);
    expect(asks(ready(), importing: true), isFalse);
    expect(asks(ready(), version: ''), isFalse);
  });
  test('import silence lasts seven civil days, including future dates', () {
    final state = ready().withImport(today);
    expect(asks(state), isFalse);
    expect(asks(state, on: addCivilDays(today, 6)), isFalse);
    expect(asks(state, on: addCivilDays(today, 7)), isTrue);
    expect(asks(state, on: addCivilDays(today, 8)), isTrue);
    expect(asks(ready().withImport(addCivilDays(today, 1))), isFalse);
  });
  test('requires ninety days and a different, never requested version', () {
    final state = ready().withRequest(today, '1.1.0');
    expect(asks(state, on: addCivilDays(today, 89)), isFalse);
    expect(asks(state, on: addCivilDays(today, 90)), isTrue);
    expect(asks(state, on: addCivilDays(today, 91)), isTrue);
    expect(asks(state, on: addCivilDays(today, 90), version: '1.1.0'), isFalse);
    final twice = state.withRequest(addCivilDays(today, 90), '1.2.0');
    expect(
      asks(twice, on: addCivilDays(today, 180), version: '1.1.0'),
      isFalse,
    );
  });
  test('two lifetime requests permit a third, three forbid a fourth', () {
    final twice = ready().withRequest(first, '0.1').withRequest(today, '0.2');
    expect(asks(twice, on: addCivilDays(today, 90)), isTrue);
    final three = twice.withRequest(addCivilDays(today, 90), '0.3');
    expect(asks(three, on: addCivilDays(today, 180)), isFalse);
  });
  test('repeated civil dates and clock rollback cannot count a day twice', () {
    var state = const ReviewState().withOpen(first).withOpen(today);
    state = state.withOpen(first).withOpen(today);
    expect(state.openDays.length, 2);
    expect(state.firstOpen, first);
    expect(asks(ready(), on: addCivilDays(first, -1)), isFalse);
  });
  test('uses calendar differences across DST and local dates across zones', () {
    final start = civilDay(DateTime.utc(2026, 10, 24, 22), 120);
    final end = civilDay(DateTime.utc(2026, 10, 31, 23), 60);
    expect(daysBetween(start, end), 7);
    expect(isoDayOf(start), '2026-10-25');
    final instant = DateTime.utc(2026, 10, 8, 1);
    expect(isoDayOf(civilDay(instant, -360)), '2026-10-07');
    expect(isoDayOf(civilDay(instant, 540)), '2026-10-08');
  });
  test('all counters survive JSON including import silence and versions', () {
    final state = ready().withRequest(today, '1.0').withImport(first);
    expect(ReviewState.fromJson(state.toJson()).toJson(), state.toJson());
  });
}
