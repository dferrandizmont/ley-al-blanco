import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';
import '../support/qa_ui.dart';

const _marcar = 'Marcar como dudosa';
const _marcada = 'Marcada como dudosa';

/// The cells the navigator marks as doubtful (1-based), with the sheet opened
/// and closed again on the same question.
Future<Set<int>> _navigatorFlagged(QaApp app) async {
  final tester = app.tester;
  await tester.tapText(T.preguntas);
  await tester.waitFor(find.byType(MockNavigator), reason: 'the navigator');
  final widget = tester.widget<MockNavigator>(find.byType(MockNavigator));
  final flagged = {for (final i in widget.flagged) i + 1};
  await tester.tapFinder(
    find.descendant(
      of: find.byType(MockNavigator),
      matching: find.text('${widget.current + 1}'),
    ),
  );
  await tester.waitGone(find.byType(MockNavigator));
  return flagged;
}

/// «Marcar como dudosa» in the mock: the toggle, the map, the warning when
/// handing in and the marks surviving the app being closed and reopened.
void registerSimulacroDudosas() {
  qaScenario(
    'simulacro_dudosas',
    'Marcar preguntas como dudosas: mapa, aviso al entregar y retomar',
    (tester) async {
      final app = await launchApp(tester);
      await startMockFromHome(app);

      // Mark question 1 and question 5 (answered).
      expect(find.text(_marcar), findsOneWidget);
      await tester.tapText(_marcar);
      await tester.waitFor(find.text(_marcada));
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

      await goToQuestion(app, 5);
      expect(find.text(_marcar), findsOneWidget, reason: 'not marked yet');
      await answerMock(app, 5, outcome: true);
      await tester.tapText(_marcar);
      await tester.waitFor(find.text(_marcada));

      // The map: both marked, one answered, the summary and the legend.
      expect(await _navigatorFlagged(app), {1, 5});
      await tester.tapText(T.preguntas);
      await tester.waitFor(find.text('2 dudosas · 19 sin responder'));
      expect(find.text('Dudosa'), findsOneWidget);
      expect(find.text('Respondida'), findsOneWidget);
      await tester.tapFinder(
        find.descendant(
          of: find.byType(MockNavigator),
          matching: find.text('5'),
        ),
      );
      await tester.waitGone(find.byType(MockNavigator));

      // The app is closed and opened again: "Continuar simulacro" brings the
      // marks back with the answers.
      await app.restart();
      await waitHome(app);
      await tester.tapText(T.simulacro);
      await tester.waitFor(find.text(T.continuarSimulacro));
      await tester.tapText(T.continuarSimulacro);
      await tester.waitFor(find.text(T.ratio(1, 20)));
      await tester.waitFor(find.text(_marcada), reason: 'question 1 marked');
      expect(await _navigatorFlagged(app), {1, 5});
      expect(await navigatorAnswered(app), {5});

      // Un-mark question 1 and mark 3: the dialog counts what is left.
      await tester.tapText(_marcada);
      await tester.waitFor(find.text(_marcar));
      await goToQuestion(app, 3);
      await tester.tapText(_marcar);
      await tester.waitFor(find.text(_marcada));
      expect(await _navigatorFlagged(app), {3, 5});

      await submitMock(
        app,
        body:
            'Tienes 2 dudosas y 19 sin responder. '
            'Las preguntas sin responder contarán como fallo.',
      );
      expect(find.text(T.noApto), findsOneWidget);
    },
  );
}
