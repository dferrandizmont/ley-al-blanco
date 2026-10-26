import 'package:flutter/foundation.dart' show immutable, mapEquals;

/// Parameters of a mock exam (plan 2.4), read from `manifest.json` with
/// defaults: 20 questions, pass with 16, proportional split, avoid the
/// questions of the last 2 mocks.
@immutable
class MockConfig {
  /// Questions in a mock when the manifest does not say otherwise.
  static const int defaultSize = 20;

  /// Throws [ArgumentError] when the values are inconsistent:
  /// `size` must be positive, `passMark` in `1..size`, `avoidLastMocks` not
  /// negative, and a `distribution` must have tema keys >= 1, no negative
  /// counts and sum exactly `size`.
  MockConfig({
    this.size = defaultSize,
    this.passMark = 16,
    Map<int, int>? distribution,
    this.avoidLastMocks = 2,
  }) : distribution = distribution == null
           ? null
           : Map.unmodifiable(distribution) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }
    if (passMark < 1 || passMark > size) {
      throw ArgumentError.value(passMark, 'passMark', 'must be in 1..$size');
    }
    if (avoidLastMocks < 0) {
      throw ArgumentError.value(avoidLastMocks, 'avoidLastMocks', 'negative');
    }
    final dist = this.distribution;
    if (dist != null) {
      var sum = 0;
      for (final entry in dist.entries) {
        if (entry.key < 1) {
          throw ArgumentError.value(entry.key, 'distribution', 'tema < 1');
        }
        if (entry.value < 0) {
          throw ArgumentError.value(entry.value, 'distribution', 'negative');
        }
        sum += entry.value;
      }
      if (sum != size) {
        throw ArgumentError.value(
          dist,
          'distribution',
          'sums to $sum but size is $size',
        );
      }
    }
  }

  /// A config where any value left null takes its default (20 questions,
  /// pass with 16, proportional split, avoid the last 2 mocks). The single
  /// place where the manifest's optional `mock` block becomes a config, for
  /// the app and for the import-time validation. Throws [ArgumentError] like
  /// the constructor.
  factory MockConfig.withDefaults({
    int? size,
    int? passMark,
    Map<int, int>? distribution,
    int? avoidLastMocks,
  }) => MockConfig(
    size: size ?? defaultSize,
    passMark: passMark ?? 16,
    distribution: distribution,
    avoidLastMocks: avoidLastMocks ?? 2,
  );

  /// Parses the mock section of the manifest. Keys: `size`, `pass_mark`,
  /// `distribution` (`{"1": 3, "2": 3, ...}`, tema -> count) and
  /// `avoid_last_mocks`. Missing keys take the defaults.
  factory MockConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['distribution'];
    return MockConfig.withDefaults(
      size: json['size'] as int?,
      passMark: json['pass_mark'] as int?,
      distribution: raw is Map
          ? {
              for (final entry in raw.entries)
                int.parse(entry.key as String): entry.value as int,
            }
          : null,
      avoidLastMocks: json['avoid_last_mocks'] as int?,
    );
  }

  /// Number of questions in a mock.
  final int size;

  /// Minimum correct answers to pass (`APTO`).
  final int passMark;

  /// Fixed tema -> count split, or null for the proportional one
  /// ([allocateByTema]).
  final Map<int, int>? distribution;

  /// How many of the most recent mocks the new one tries not to repeat.
  final int avoidLastMocks;

  @override
  bool operator ==(Object other) =>
      other is MockConfig &&
      other.size == size &&
      other.passMark == passMark &&
      other.avoidLastMocks == avoidLastMocks &&
      ((other.distribution == null && distribution == null) ||
          (other.distribution != null &&
              distribution != null &&
              mapEquals(other.distribution, distribution)));

  @override
  int get hashCode => Object.hash(
    size,
    passMark,
    avoidLastMocks,
    distribution == null
        ? null
        : Object.hashAllUnordered(
            distribution!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
  );

  @override
  String toString() =>
      'MockConfig(size: $size, passMark: $passMark, '
      'distribution: $distribution, avoidLastMocks: $avoidLastMocks)';
}
