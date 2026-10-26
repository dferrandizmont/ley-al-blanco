import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/tema_title.dart';
import '../domain/theory.dart';

extension TheoryDocTitle on TheoryDoc {
  /// The title the app shows for this document.
  ///
  /// A tema summary shows the name of the tema from the ARB (`temaN`, the
  /// official programme names), the same text as Inicio, the practice screen
  /// and the result: one source of truth for the titles of the temas. The
  /// other documents (practica, aem, glosario) use their own [title].
  String displayTitle(AppLocalizations l10n) =>
      tema == null ? title : l10n.temaTitle(tema!);
}
