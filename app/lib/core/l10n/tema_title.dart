import 'l10n.dart';

/// Number of temas in the questionnaire (spec §2).
const int kTemaCount = 7;

extension TemaTitles on AppLocalizations {
  /// Name of tema [tema] (1..7). Throws [RangeError] outside that range.
  String temaTitle(int tema) => switch (tema) {
    1 => tema1,
    2 => tema2,
    3 => tema3,
    4 => tema4,
    5 => tema5,
    6 => tema6,
    7 => tema7,
    _ => throw RangeError.range(tema, 1, kTemaCount, 'tema'),
  };
}
