import 'mock_config.dart';

/// How many questions of each tema go into a mock (plan 2.4).
///
/// [temaSizes] maps tema -> number of questions available. The result has an
/// entry for every tema in [temaSizes] (0 when it gets none) and always sums
/// to `config.size`.
///
/// * With `config.distribution`: that split is used as is, after checking
///   that every tema exists and has enough questions. An impossible split is
///   a configuration error, so it throws [ArgumentError] instead of silently
///   capping it.
/// * Otherwise: Hamilton's largest-remainder method on the proportional
///   shares `size * temaSize / total`, computed with integers (no float
///   rounding). The seats left after the integer parts go to the largest
///   remainders; ties are broken by larger tema size, then lower tema number,
///   so the result is deterministic. With 68/67/66/70/66/64/22 and 20 this
///   gives 3/3/3/4/3/3/1.
///
/// Throws [ArgumentError] when a size is negative or when `config.size`
/// exceeds the total number of questions.
Map<int, int> allocateByTema(Map<int, int> temaSizes, MockConfig config) {
  var total = 0;
  for (final entry in temaSizes.entries) {
    if (entry.value < 0) {
      throw ArgumentError.value(temaSizes, 'temaSizes', 'negative size');
    }
    total += entry.value;
  }
  if (config.size > total) {
    throw ArgumentError.value(
      config.size,
      'config.size',
      'only $total questions available',
    );
  }
  final distribution = config.distribution;
  if (distribution != null) {
    return _fixedDistribution(temaSizes, distribution);
  }
  return _largestRemainder(temaSizes, config.size, total);
}

Map<int, int> _fixedDistribution(
  Map<int, int> temaSizes,
  Map<int, int> distribution,
) {
  for (final entry in distribution.entries) {
    final available = temaSizes[entry.key];
    if (available == null && entry.value > 0) {
      throw ArgumentError.value(
        distribution,
        'config.distribution',
        'tema ${entry.key} has no questions',
      );
    }
    if (available != null && entry.value > available) {
      throw ArgumentError.value(
        distribution,
        'config.distribution',
        'tema ${entry.key} needs ${entry.value} but has $available',
      );
    }
  }
  return {for (final tema in temaSizes.keys) tema: distribution[tema] ?? 0};
}

Map<int, int> _largestRemainder(Map<int, int> temaSizes, int size, int total) {
  final seats = <int, int>{};
  final remainders = <int, int>{};
  var assigned = 0;
  for (final entry in temaSizes.entries) {
    final scaled = size * entry.value;
    seats[entry.key] = scaled ~/ total;
    remainders[entry.key] = scaled % total;
    assigned += seats[entry.key]!;
  }
  final byPriority = temaSizes.keys.toList()
    ..sort((a, b) {
      final byRemainder = remainders[b]!.compareTo(remainders[a]!);
      if (byRemainder != 0) return byRemainder;
      final bySize = temaSizes[b]!.compareTo(temaSizes[a]!);
      if (bySize != 0) return bySize;
      return a.compareTo(b);
    });
  // Fewer seats are left than temas with a positive remainder, so every
  // extra seat goes to a tema with room for it.
  for (final tema in byPriority.take(size - assigned)) {
    seats[tema] = seats[tema]! + 1;
  }
  return seats;
}
