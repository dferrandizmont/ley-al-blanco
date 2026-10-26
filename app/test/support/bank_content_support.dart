import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts the explanation block shows the REAL content of [q] from the bank
/// (explanation or placeholder, article chip, notice callout), whatever the
/// editorial content happens to be.
void expectBankContent(Question q) {
  final explanation = q.explanation?.trim();
  if (explanation == null || explanation.isEmpty) {
    expect(find.text('Explicación en preparación'), findsOneWidget);
  } else {
    expect(find.text(explanation), findsOneWidget);
    expect(find.text('Explicación en preparación'), findsNothing);
  }
  expect(
    find.byType(ArticleChip),
    q.article == null ? findsNothing : findsOneWidget,
  );
  final notice = q.notice?.trim();
  if (notice == null || notice.isEmpty) {
    expect(find.text('Aviso: cambio en la norma'), findsNothing);
  } else {
    expect(find.text('Aviso: cambio en la norma'), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
  }
}
