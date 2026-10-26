import 'dart:math' show Random;

import '../../content/domain/question.dart';
import 'mock_allocation.dart';
import 'mock_config.dart';

/// Builds a mock exam (plan 2.4). Pure and deterministic: the same inputs and
/// a [Random] with the same seed give the same mock, whatever the order of
/// [questions].
///
/// 1. The number of questions per tema comes from [allocateByTema].
/// 2. Per tema, candidates are ranked: first those that are **not** in the
///    last `config.avoidLastMocks` mocks of [recentMocks]; if there are not
///    enough, the rest by recency of use, oldest mock first (least recently
///    used). Inside each rank the order is random.
/// 3. Candidates are taken in that order, skipping any that shares an
///    exclusion group (see `sameStemGroups`) with a question already chosen
///    for this mock: never two of a group. Only as a **last resort**, if a
///    tema still lacks questions because every remaining candidate is
///    excluded (tiny banks, or a group spanning temas), the exclusion is
///    relaxed for the missing ones, still following the ranking.
/// 4. The result is ordered by tema ascending, random within each tema.
///
/// [recentMocks] lists question ids per past mock, **newest first**. Ids that
/// are no longer in the bank are ignored.
///
/// Throws [ArgumentError] when the config cannot be satisfied by [questions]
/// (see [allocateByTema]).
List<Question> generateMock({
  required List<Question> questions,
  required MockConfig config,
  required Random rng,
  List<List<String>> recentMocks = const [],
  List<Set<String>> exclusionGroups = const [],
}) {
  final byTema = <int, List<Question>>{};
  for (final question in questions) {
    byTema.putIfAbsent(question.tema, () => []).add(question);
  }
  final allocation = allocateByTema({
    for (final entry in byTema.entries) entry.key: entry.value.length,
  }, config);

  final lastUse = _lastUseIndex(recentMocks.take(config.avoidLastMocks));
  final groupsOf = _groupsById(exclusionGroups);
  final usedGroups = <int>{};
  final mock = <Question>[];

  for (final tema in allocation.keys.toList()..sort()) {
    final count = allocation[tema]!;
    if (count == 0) continue;
    final ranked = _rankCandidates(byTema[tema]!, lastUse, rng);
    final picked = _pick(ranked, count, groupsOf, usedGroups);
    _shuffle(picked, rng);
    mock.addAll(picked);
  }
  return mock;
}

/// Question id -> index (0 = newest) of the newest recent mock that has it.
Map<String, int> _lastUseIndex(Iterable<List<String>> recentMocks) {
  final lastUse = <String, int>{};
  var index = 0;
  for (final ids in recentMocks) {
    for (final id in ids) {
      lastUse.putIfAbsent(id, () => index);
    }
    index++;
  }
  return lastUse;
}

/// Question id -> indexes of the exclusion groups it belongs to.
Map<String, List<int>> _groupsById(List<Set<String>> groups) {
  final groupsOf = <String, List<int>>{};
  for (var i = 0; i < groups.length; i++) {
    for (final id in groups[i]) {
      groupsOf.putIfAbsent(id, () => []).add(i);
    }
  }
  return groupsOf;
}

/// Orders [candidates]: not used recently first, then oldest use first;
/// random inside each bucket (sorted by id before shuffling so the result
/// does not depend on the input order).
List<Question> _rankCandidates(
  List<Question> candidates,
  Map<String, int> lastUse,
  Random rng,
) {
  const fresh = -1;
  final buckets = <int, List<Question>>{};
  for (final question in candidates) {
    buckets.putIfAbsent(lastUse[question.id] ?? fresh, () => []).add(question);
  }
  // fresh (-1) first, then higher index = older mock = less recently used.
  final order = buckets.keys.toList()
    ..sort((a, b) {
      if (a == fresh) return -1;
      if (b == fresh) return 1;
      return b.compareTo(a);
    });
  final ranked = <Question>[];
  for (final key in order) {
    final bucket = buckets[key]!..sort((a, b) => a.id.compareTo(b.id));
    _shuffle(bucket, rng);
    ranked.addAll(bucket);
  }
  return ranked;
}

/// Takes [count] questions from [ranked] honouring exclusion groups, relaxing
/// them only if there is no other way to reach [count].
List<Question> _pick(
  List<Question> ranked,
  int count,
  Map<String, List<int>> groupsOf,
  Set<int> usedGroups,
) {
  final picked = <Question>[];
  for (final question in ranked) {
    if (picked.length == count) break;
    final groups = groupsOf[question.id] ?? const <int>[];
    if (groups.any(usedGroups.contains)) continue;
    picked.add(question);
    usedGroups.addAll(groups);
  }
  if (picked.length < count) {
    // Last resort: not enough compatible questions.
    for (final question in ranked) {
      if (picked.length == count) break;
      if (picked.contains(question)) continue;
      picked.add(question);
      usedGroups.addAll(groupsOf[question.id] ?? const <int>[]);
    }
  }
  return picked;
}

/// Fisher-Yates driven only by [rng], so a seed gives a stable order across
/// SDK versions.
void _shuffle<T>(List<T> items, Random rng) {
  for (var i = items.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = items[i];
    items[i] = items[j];
    items[j] = tmp;
  }
}
