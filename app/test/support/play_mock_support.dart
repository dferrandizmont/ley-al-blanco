import 'dart:math';

import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/application/mock_service.dart'
    show StartedMock;
import 'package:flutter_test/flutter_test.dart';

import 'screen_support.dart';
import 'study_support.dart';

/// Plays a mock through the controller: [right] official answers, then
/// [wrong] wrong ones; with [submit] it is handed in.
Future<StartedMock> playMock(
  WidgetTester tester, {
  required int right,
  required int wrong,
  required bool submit,
}) async {
  final container = containerOf(tester);
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < right + wrong; i++) {
    controller.goTo(i);
    final q = started.questions[i];
    controller.select(i < right ? q.answer : wrongOption(q));
  }
  controller.goTo(0);
  if (submit) await controller.submit();
  await controller.pendingSaves;
  return started;
}
