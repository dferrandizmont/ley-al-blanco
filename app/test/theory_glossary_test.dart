import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/features/theory/domain/theory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/theory_support.dart';

/// «Autorización para menores (AEM)» and the glossary: two free documents
/// without tema (domain, list rows, routes, reader, search).

void _phone(WidgetTester tester, {double scale = 1}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

Future<void> _pump(WidgetTester tester) async {
  _phone(tester);
  await pumpFullApp(
    tester,
    bundle: theoryBundle(theory: theoryFixtureJson(extras: true)),
  );
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  group('domain', () {
    test('aem and glosario are documents without tema', () {
      final bank = TheoryBank.fromJson(theoryFixtureJson(extras: true));
      expect(bank.docs.map((d) => d.id).toList().sublist(7), [
        'practica',
        'aem',
        'glosario',
      ]);
      expect(bank.aem?.tema, isNull);
      expect(bank.glosario?.tema, isNull);
      expect(bank.temaDocs, hasLength(7));
      expect(temaOfDocId(kAemDocId), isNull);
      expect(temaOfDocId(kGlosarioDocId), isNull);
      // A bank without them (older builds) still parses.
      final old = TheoryBank.fromJson(theoryFixtureJson());
      expect(old.aem, isNull);
      expect(old.glosario, isNull);
    });

    test('a tema on aem or glosario is rejected', () {
      for (final id in ['aem', 'glosario']) {
        final json = theoryFixtureJson(extras: true);
        final doc = (json['docs'] as List).firstWhere(
          (d) => (d as Map)['id'] == id,
        ) as Map<String, dynamic>;
        doc['tema'] = 3;
        expect(() => TheoryBank.fromJson(json), throwsFormatException);
      }
    });

    test('parses the terms block', () {
      final glosario = TheoryBank.fromJson(theoryFixtureJson(extras: true))
          .glosario!;
      expect(glosario.sections, hasLength(4));
      expect(glosario.termCount, 12);
      final first =
          (glosario.sections.first.blocks.first as TermsBlock).items.first;
      expect(first.term, 'Guía de pertenencia');
      expect(first.article, 'Art. 88 RD 137/1993');
      final second =
          (glosario.sections.first.blocks.first as TermsBlock).items[1];
      expect(second.article, isNull);
      expect(glosario.readingMinutes, greaterThanOrEqualTo(1));
    });

    test('rejects malformed terms', () {
      Map<String, dynamic> block(Object? items) => {
        'type': 'terms',
        'items': items,
      };
      for (final bad in [
        block([]),
        block('x'),
        block(['solo texto']),
        block([
          {'term': '', 'text': 'x'},
        ]),
        block([
          {'term': 'a'},
        ]),
        block([
          {'term': 'a', 'text': 'x', 'article': ''},
        ]),
        block([
          {'term': 'a', 'text': 'x', 'article': 3},
        ]),
      ]) {
        expect(() => TheoryBlock.fromJson(bad), throwsFormatException);
      }
    });

    test('foldForSearch ignores case, accents and the ñ', () {
      expect(foldForSearch('Guía DE Pertenencia'), 'guia de pertenencia');
      expect(foldForSearch('CAÑÓN'), 'canon');
      expect(foldForSearch('años'), foldForSearch('ANOS'));
      expect(foldForSearch('pingüino'), 'pinguino');
      expect(searchWords('  Guia   pertenencia '), ['guia', 'pertenencia']);
      expect(searchWords('   '), isEmpty);
    });

    test('filterTerms matches term and text, every word, any accent', () {
      final glosario = TheoryBank.fromJson(theoryFixtureJson(extras: true))
          .glosario!;
      List<String> terms(TheoryDoc? doc) => [
        for (final s in doc?.sections ?? <TheorySection>[])
          for (final b in s.blocks.whereType<TermsBlock>())
            for (final i in b.items) i.term,
      ];
      expect(terms(glosario.filterTerms('')), hasLength(12));
      expect(glosario.filterTerms('   '), same(glosario));
      expect(terms(glosario.filterTerms('guia')), ['Guía de pertenencia']);
      expect(terms(glosario.filterTerms('CAÑON')), ['Cañón']);
      expect(terms(glosario.filterTerms('canon')), ['Cañón']);
      expect(terms(glosario.filterTerms('cañón')), ['Cañón']);
      // In the definition, not the term.
      expect(terms(glosario.filterTerms('fulminante')), [
        'Percutor',
        'Cartucho',
        'Fulminante',
      ]);
      // Every word must be there, in any order.
      expect(terms(glosario.filterTerms('pieza fulminante')), ['Percutor']);
      expect(glosario.filterTerms('zzz'), isNull);
    });

    test('a filtered section is unfolded and loses the section articles', () {
      final json = theoryFixtureJson(extras: true);
      final doc = (json['docs'] as List).last as Map<String, dynamic>;
      final first = (doc['sections'] as List).first as Map<String, dynamic>;
      first['collapsed'] = true;
      first['articles'] = ['Art. 3 RD 137/1993'];
      final glosario = TheoryBank.fromJson(json).glosario!;
      expect(glosario.sections.first.collapsed, isTrue);
      final filtered = glosario.filterTerms('licencia')!;
      expect(filtered.sections.single.title, 'Licencias y guías');
      expect(filtered.sections.single.collapsed, isFalse);
      expect(filtered.sections.single.articles, isEmpty);
    });
  });

  group('list', () {
    testScreen(
      'shows the two reference rows below the temas, with no padlock',
      (tester) async {
        await _pump(tester);
        await openRoute(tester, '/teoria');
        expect(find.text('PARA COMPLETAR'), findsOneWidget);
        expect(find.text('Autorización para menores (AEM)'), findsOneWidget);
        expect(find.text('Glosario'), findsOneWidget);
        expect(find.text('12 términos explicados'), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsNothing);
        // Chevrons: seven temas, the practica card and two reference rows.
        expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(10));
      },
    );

    testScreen('the rows open their documents for everyone', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria');
      await _tap(tester, find.text('Autorización para menores (AEM)'));
      expect(locationOf(tester), '/teoria/aem');
      expect(find.text('TEORÍA · MENORES (AEM)'), findsOneWidget);
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Glosario'));
      expect(locationOf(tester), '/teoria/glosario');
      expect(find.text('TEORÍA · GLOSARIO'), findsOneWidget);
    });

    testScreen('a build without them shows no extra card', (tester) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: theoryBundle());
      await openRoute(tester, '/teoria');
      expect(find.text('PARA COMPLETAR'), findsNothing);
      expect(find.text('Glosario'), findsNothing);
    });

    testScreen('rows read as buttons with title and subtitle', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria');
      final handle = tester.ensureSemantics();
      await tester.ensureVisible(find.text('Glosario'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Glosario. 12 términos explicados'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('routes', () {
    testScreen('deep links to aem and glosario are open for everyone', (
      tester,
    ) async {
      await _pump(tester);
      for (final id in ['aem', 'glosario']) {
        await openRoute(tester, '/teoria/$id');
        expect(locationOf(tester), '/teoria/$id');
      }
    });

    testScreen('no "Practicar este tema" on either document', (tester) async {
      await _pump(tester);
      for (final id in ['aem', 'glosario']) {
        await openRoute(tester, '/teoria/$id');
        expect(find.text('Practicar este tema'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      }
    });

    testScreen('without them a deep link shows the empty state', (
      tester,
    ) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: theoryBundle());
      await openRoute(tester, '/teoria/glosario');
      expect(find.text('La teoría no está disponible'), findsOneWidget);
    });
  });

  group('glossary reader', () {
    testScreen('a new query unfolds a previously folded result', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      await _search(tester, 'canon');
      await _tap(tester, find.text('Piezas del arma'));
      expect(find.text('Cañón'), findsNothing);

      await _search(tester, 'guia');
      expect(find.text('Licencias y guías'), findsOneWidget);
      expect(find.text('Guía de pertenencia'), findsOneWidget);
    });

    testScreen('changing documents clears the previous glossary query', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      await _search(tester, 'canon');
      await openRoute(tester, '/teoria/aem');
      await openRoute(tester, '/teoria/glosario');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.text('Guía de pertenencia'), findsOneWidget);
    });

    testScreen('renders every term with its definition and article chip', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      expect(find.text('Glosario'), findsOneWidget); // the title
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Guía de pertenencia'), findsOneWidget);
      expect(
        find.text('Documento de cada arma que acredita quién es su titular.'),
        findsOneWidget,
      );
      expect(find.text('Art. 88 RD 137/1993'), findsOneWidget);
      expect(find.byType(ArticleChip), findsNWidgets(2));
      // No results line without a search.
      expect(find.textContaining('términos'), findsNothing);
    });

    testScreen('the term is bold and each entry reads as one item', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      final term = tester.widget<Text>(find.text('Guía de pertenencia'));
      expect(term.style?.fontWeight, FontWeight.w700);
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(r'^Guía de pertenencia\n')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testScreen('the aem document has no search field', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/aem');
      expect(find.byType(TextField), findsNothing);
    });

    testScreen('search ignores case and accents and hides the rest', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      await _search(tester, 'CANON'); // no ñ on the keyboard
      expect(find.text('Cañón'), findsOneWidget);
      expect(find.text('Ningún término coincide'), findsNothing);

      await _search(tester, 'cañon');
      expect(find.text('Cañón'), findsOneWidget);
      expect(find.text('Percutor'), findsNothing);
      expect(find.text('Munición'), findsNothing); // section without a match
      expect(find.text('Piezas del arma'), findsOneWidget);
      expect(find.text('1 término'), findsOneWidget);

      await _search(tester, 'GUIA');
      expect(find.text('Guía de pertenencia'), findsOneWidget);
      // The article of the term still shows.
      expect(find.byType(ArticleChip), findsOneWidget);
    });

    testScreen('search looks in the definition too and counts the results', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      await _search(tester, 'fulminante');
      expect(find.text('3 términos'), findsOneWidget);
      expect(find.text('Percutor'), findsOneWidget);
      expect(find.text('Cartucho'), findsOneWidget);
      expect(find.text('Fulminante'), findsOneWidget);
      expect(find.text('Licencia D'), findsNothing);
    });

    testScreen('the result count is a live region', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      final handle = tester.ensureSemantics();
      await _search(tester, 'fulminante');
      expect(
        tester.getSemantics(find.text('3 términos')),
        matchesSemantics(label: '3 términos', isLiveRegion: true),
      );
      handle.dispose();
    });

    testScreen('clearing the search brings everything back', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      await _search(tester, 'zzz');
      expect(find.text('Ningún término coincide'), findsOneWidget);
      expect(find.text('Guía de pertenencia'), findsNothing);

      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Borrar la búsqueda'), findsNothing);
      expect(find.text('Ningún término coincide'), findsNothing);
      expect(find.text('Guía de pertenencia'), findsOneWidget);
      expect(find.textContaining('términos'), findsNothing);
    });

    testScreen('a search unfolds the sections the document folds', (
      tester,
    ) async {
      _phone(tester);
      final json = theoryFixtureJson(extras: true);
      final doc = (json['docs'] as List).last as Map<String, dynamic>;
      for (final s in doc['sections'] as List) {
        (s as Map<String, dynamic>)['collapsed'] = true;
      }
      await pumpFullApp(tester, bundle: theoryBundle(theory: json));
      await openRoute(tester, '/teoria/glosario');
      expect(find.text('Percutor'), findsNothing);
      await _search(tester, 'percutor');
      expect(find.text('Percutor'), findsOneWidget);
      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Percutor'), findsNothing);
    });

    testScreen('sections can be folded without searching', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/glosario');
      expect(find.text('Percutor'), findsOneWidget);
      await _tap(tester, find.text('Piezas del arma'));
      expect(find.text('Percutor'), findsNothing);
    });

    testScreen('lays out at 320 x 568 with text x1.3', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFullApp(
        tester,
        bundle: theoryBundle(theory: theoryFixtureJson(extras: true)),
      );
      await openRoute(tester, '/teoria/glosario');
      expect(tester.takeException(), isNull);
      await _search(tester, 'a');
      expect(tester.takeException(), isNull);
      await openRoute(tester, '/teoria');
      expect(tester.takeException(), isNull);
    });
  });
}
