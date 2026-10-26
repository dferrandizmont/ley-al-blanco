import 'package:apto_armas/core/widgets/search_field.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mistakes/presentation/mistake_sheet.dart';
import 'package:apto_armas/features/search/domain/question_search.dart';
import 'package:apto_armas/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';

Question _q(
  String id,
  String stem, {
  int tema = 1,
  List<String> options = const ['a', 'b', 'c'],
}) => Question(
  id: id,
  tema: tema,
  stem: stem,
  options: options,
  answer: 0,
  edition: 'GC-2020-11',
);

/// The longest plain word (letters only) of [text], lower case.
String _longestWord(String text) {
  final words = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñü]{5,}').allMatches(text);
  return words
      .map((m) => m.group(0)!.toLowerCase())
      .reduce((a, b) => b.length > a.length ? b : a);
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

void main() {
  group('QuestionSearchIndex', () {
    final index = QuestionSearchIndex([
      _q(
        't1-001',
        'El cañón del arma debe estar descargado',
        options: ['Siempre', 'Nunca', 'A veces'],
      ),
      _q('t1-002', 'La licencia de armas D caduca a los cinco años'),
      _q(
        't2-001',
        'Categoría de las escopetas',
        tema: 2,
        options: ['Segunda', 'Tercera', 'Cuarta'],
      ),
    ]);

    List<String> ids(String query) => [
      for (final q in index.search(query)) q.id,
    ];

    test('ignores capitals and accents on both sides', () {
      expect(ids('canon'), ['t1-001']);
      expect(ids('CAÑÓN'), ['t1-001']);
      expect(ids('categoria'), ['t2-001']);
      expect(ids('categoría'), ['t2-001']);
    });

    test('every word has to be there, in any order', () {
      expect(ids('arma cañón'), ['t1-001']);
      expect(ids('cañón arma'), ['t1-001']);
      expect(ids('cañón licencia'), isEmpty);
      expect(ids('  licencia   caduca '), ['t1-002']);
    });

    test('it also looks in the options', () {
      expect(ids('escopetas tercera'), ['t2-001']);
      expect(ids('siempre'), ['t1-001']);
    });

    test('a word matches inside another word, like the glossary', () {
      expect(ids('descarg'), ['t1-001']);
      expect(ids('arma'), ['t1-001', 't1-002']);
    });

    test('too short a query finds nothing instead of everything', () {
      expect(ids(''), isEmpty);
      expect(ids('   '), isEmpty);
      expect(ids('a'), isEmpty);
      expect(isSearchable('a'), isFalse);
      expect(isSearchable('ar'), isTrue);
      expect(isSearchable('a b'), isTrue);
    });

    test('results come in bank order', () {
      expect(ids('de'), ['t1-001', 't1-002', 't2-001']);
    });
  });

  group('screen', () {
    testScreen('starts with a prompt and nothing listed', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      expect(find.text('Buscar preguntas'), findsOneWidget);
      expect(find.byType(AptoSearchField), findsOneWidget);
      expect(find.text('Buscar en enunciados y opciones'), findsOneWidget);
      expect(find.text('Busca en el banco de preguntas'), findsOneWidget);
      expect(find.byType(MistakeSheet), findsNothing);

      // One letter is not a search.
      await _search(tester, 'a');
      expect(find.text('Busca en el banco de preguntas'), findsOneWidget);
    });

    testScreen('lists the matches with their tema and the total', (
      tester,
    ) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      final bank = await bankOf(tester);
      final target = bank.firstWhere((q) => q.tema == 3);
      final word = _longestWord(target.stem);
      final expected = QuestionSearchIndex(bank).search(word);

      // Capitals do not matter.
      await _search(tester, word.toUpperCase());
      final shown = expected.take(kMaxSearchResults).toList();
      expect(
        find.text(
          expected.length == 1
              ? '1 resultado'
              : '${expected.length} resultados',
        ),
        findsOneWidget,
      );
      expect(
        find.text(target.stem),
        expected.contains(target) && shown.contains(target)
            ? findsOneWidget
            : findsNothing,
      );
      for (final q in shown.take(3)) {
        expect(find.text(q.stem), findsOneWidget);
      }
      expect(find.text('Tema ${shown.first.tema}'), findsWidgets);
    });

    testScreen('clearing the field goes back to the prompt', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      await _search(tester, 'arma');
      expect(find.text('Busca en el banco de preguntas'), findsNothing);
      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Busca en el banco de preguntas'), findsOneWidget);
    });

    testScreen('no matches says so', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      await _search(tester, 'zzqxjw');
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(
        find.text('Prueba con otras palabras o con menos palabras.'),
        findsOneWidget,
      );
    });

    testScreen('lists at most 50 and says so', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      final bank = await bankOf(tester);
      final all = QuestionSearchIndex(bank).search('de');
      expect(all.length, greaterThan(kMaxSearchResults));
      await _search(tester, 'de');
      expect(find.text('${all.length} resultados'), findsOneWidget);
      expect(
        find.text(
          'Se muestran las $kMaxSearchResults primeras. '
          'Añade palabras para afinar la búsqueda.',
        ),
        findsOneWidget,
      );
    });

    testScreen('a result opens the same ficha as Fallos', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      final bank = await bankOf(tester);
      // A question with its explanation, the official answer and an article.
      final q = bank.firstWhere(
        (q) => q.explanation != null && q.article != null,
      );
      // Narrow the search to that question with a long, rare word.
      final query = _longestWord(q.stem);
      await _search(tester, query);
      await tester.tap(find.text(q.stem).first);
      await tester.pumpAndSettle();

      expect(find.byType(MistakeSheet), findsOneWidget);
      expect(find.text(q.explanation!), findsOneWidget);
      expect(find.textContaining(q.article!), findsWidgets);
      // The official answer is shown; the question was never failed, so the
      // button practises the tema.
      expect(find.text('Practicar esta pregunta'), findsNothing);
      await tester.ensureVisible(find.text('Practicar este tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar este tema'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/tema/${q.tema}');
    });

    testScreen('the full version has no locked row', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      await _search(tester, 'arma');
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.textContaining('en temas de pago'), findsNothing);
    });

    testScreen('a result row is a button of at least 48 dp, spoken with its '
        'tema and stem', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/buscar');
      final bank = await bankOf(tester);
      final q = bank.firstWhere((q) => q.tema == 2);
      await _search(tester, _longestWord(q.stem));
      final row = find.ancestor(
        of: find.text(q.stem).first,
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Tema 2. ${q.stem}'), findsWidgets);
    });
  });

  group('entries', () {
    testScreen('Teoría has a search icon that opens the search', (
      tester,
    ) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/teoria');
      expect(find.byTooltip('Buscar en las preguntas'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar en las preguntas'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/buscar');
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testScreen('Fallos has a search icon that opens the search', (
      tester,
    ) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/fallos');
      expect(find.byTooltip('Buscar en las preguntas'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar en las preguntas'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/buscar');
      // Back returns to Fallos.
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/fallos');
    });

    testScreen('Inicio does not have one', (tester) async {
      await pumpFullApp(tester);
      expect(find.byTooltip('Buscar en las preguntas'), findsNothing);
    });

    testScreen('the icon is a 48 dp target', (tester) async {
      await pumpFullApp(tester);
      await pushRoute(tester, '/fallos');
      final size = tester.getSize(find.byTooltip('Buscar en las preguntas'));
      expect(size.shortestSide, greaterThanOrEqualTo(48));
    });
  });
}
