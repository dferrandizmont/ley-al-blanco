import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_ui.dart';

const _buscar = 'Buscar en las preguntas';
const _indicacion = 'Busca en el banco de preguntas';

/// The question search (`/buscar`): both entries (Teoría and Fallos), the
void registerBusqueda() {
  qaScenario(
    'busqueda_completa',
    'Buscar con la acceso completo: sin fila de pago, desde Teoría',
    (tester) async {
      final app = await launchApp(tester);
      await waitHome(app);
      app.go('/teoria');
      await tester.waitFor(find.byTooltip(_buscar));
      await tester.tapFinder(find.byTooltip(_buscar));
      await tester.waitFor(find.text(_indicacion));

      await tester.enterText(find.byType(TextField), 'arma');
      await tester.waitFor(find.textContaining(' resultados'));
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.textContaining('en temas de pago'), findsNothing);

      // Back returns to where it was opened from.
      await tester.tapFinder(find.byTooltip('Atrás'));
      await tester.waitFor(find.byTooltip(_buscar));
      expect(app.location, '/teoria');
    },
  );
}
