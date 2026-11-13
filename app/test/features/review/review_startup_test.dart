import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/review/application/review_providers.dart';
import 'package:apto_armas/features/review/application/review_startup.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('startup and foreground resumes record distinct local dates', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 1, 23, 59);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const ReviewStartup(child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ReviewStartup)),
    );
    final repository = c.read(reviewRepositoryProvider);
    expect((await repository.load(DateTime.utc(2026, 10, 1))).openDays, {
      '2026-10-01',
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      (await repository.load(DateTime.utc(2026, 10, 1))).openDays.length,
      1,
    );
    now = DateTime(2026, 10, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    final state = await repository.load(DateTime.utc(2026, 10, 2));
    expect(state.firstOpen, DateTime.utc(2026, 10, 1));
    expect(state.openDays, {'2026-10-01', '2026-10-02'});
    await tester.pumpWidget(const SizedBox());
  });
}
