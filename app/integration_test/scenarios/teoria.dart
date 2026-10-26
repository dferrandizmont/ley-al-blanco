import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_ui.dart';

// Teoría scenarios (routes /teoria and /teoria/:id): the entry on Inicio, the
//
// The theory is optional content (assets/content/armas/<edition>/teoria.json,
// verified against the manifest). While the build does not ship it, Inicio has
// no Teoría tile and these scenarios skip themselves with a note
// (`QA_NOTE|...`) instead of failing. Run only these with `QA_ONLY=teoria`.

const _entrada = 'Teoría';
const _listaOverline = 'RESÚMENES POR TEMA';
const _tema1Overline = 'TEMA 1 · TEORÍA';
const _practicar = 'Practicar este tema';

/// True when Inicio shows the Teoría tile. Prints a skip note when it does
/// not (the build has no theory yet).
bool _hasTheory(String id) {
  final has = find
      .descendant(of: find.byType(Scaffold), matching: find.text(_entrada))
      .evaluate()
      .isNotEmpty;
  if (!has) {
    // ignore: avoid_print
    print('QA_NOTE|$id|skipped: this build ships no teoria.json');
  }
  return has;
}

Future<void> _openTeoriaFromHome(QaApp app) async {
  await app.tester.tapText(_entrada);
  await app.tester.waitFor(
    find.text(_listaOverline),
    reason: 'the Teoría list',
  );
  await app.tester.pumpFor(const Duration(milliseconds: 300));
}

Future<void> _back(QaApp app) async {
  await app.tester.tapFinder(find.byTooltip('Atrás'), reason: 'back button');
}

void registerTeoria() {
  qaScenario('teoria', 'Inicio abre Teoría, entra en el tema 1 y vuelve', (
    tester,
  ) async {
    final app = await launchApp(tester);
    if (!_hasTheory('teoria')) return;

    await _openTeoriaFromHome(app);
    expect(app.location, '/teoria');

    expect(find.text('La prueba práctica'), findsOneWidget);
    tester.expectNoException('teoria (lista)');

    // All seven summaries are open. Start with the first row.
    final tema1 = find.textContaining(RegExp(r'^\d+ min de lectura$')).first;
    await tester.waitFor(tema1, reason: 'the reading time of tema 1');
    await tester.tapFinder(
      find.ancestor(of: tema1, matching: find.byType(InkWell)).first,
      reason: 'the tema 1 row',
    );
    await tester.waitFor(
      find.text(_tema1Overline),
      reason: 'the tema 1 reader',
    );
    expect(app.location, '/teoria/t1');
    expect(find.text(_practicar), findsOneWidget);
    tester.expectNoException('teoria (tema 1)');

    // Back to the list, then to Inicio.
    await _back(app);
    await tester.waitFor(find.text(_listaOverline), reason: 'back on the list');
    expect(app.location, '/teoria');
    await _back(app);
    await waitHome(app);
    expect(app.location, '/');
    expect(find.byType(TemaCard), findsNWidgets(7));
  });
}
