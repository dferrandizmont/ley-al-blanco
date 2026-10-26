/// Chance level of a three-option question: the prior of an unseen question
/// (`MasteryModel.priorMean`).
const double kChanceMastery = 1 / 3;

/// Maps the raw mastery `p` (which starts at chance, 1/3, for a question never
/// seen) to the 0..1 scale shown to the user, so a bar for an untouched tema
/// starts empty: `clamp((p - 1/3) / (2/3), 0, 1)`.
///
/// Pure display mapping; the pass probability keeps using the raw `p`.
double displayMastery(double p) {
  if (p.isNaN) return 0;
  return ((p - kChanceMastery) / (1 - kChanceMastery)).clamp(0.0, 1.0);
}
