/// Semantic-ish version value with comparison support.
///
/// Supports up to four numeric components (`1.2.3+4` style is parsed as
/// `1.2.3.4`) and tolerant parsing: missing components are treated as zero.
library;

/// A parsed version value with component-wise comparison.
class PrismVersion implements Comparable<PrismVersion> {
  /// Creates a version from already-parsed components.
  const PrismVersion(this.components);

  /// Parses a version string such as `1.2.3`, `1.2.3+4`, or `v2.0`.
  ///
  /// Non-numeric components are ignored. Throws [PrismVersionException] when
  /// no numeric components can be extracted.
  factory PrismVersion.parse(String input) {
    final cleaned = input.trim().replaceFirst(RegExp(r'^[vV]\s*'), '');
    final parts = cleaned
        .split(RegExp(r'[.\s+\-]'))
        .map((p) => int.tryParse(p))
        .whereType<int>()
        .toList(growable: false);
    if (parts.isEmpty) {
      throw PrismVersionException(input);
    }
    return PrismVersion(List<int>.unmodifiable(parts));
  }

  /// Numeric components, most significant first.
  final List<int> components;

  /// Major component, or `0` when absent.
  int get major => _at(0);

  /// Minor component, or `0` when absent.
  int get minor => _at(1);

  /// Patch component, or `0` when absent.
  int get patch => _at(2);

  /// Build component, or `0` when absent.
  int get build => _at(3);

  int _at(int index) =>
      index < components.length ? components[index] : 0;

  @override
  int compareTo(PrismVersion other) {
    final length = components.length > other.components.length
        ? components.length
        : other.components.length;
    for (var i = 0; i < length; i++) {
      final a = i < components.length ? components[i] : 0;
      final b = i < other.components.length ? other.components[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  /// Whether this version is strictly newer than [other].
  bool operator >(PrismVersion other) => compareTo(other) > 0;

  /// Whether this version is older than [other].
  bool operator <(PrismVersion other) => compareTo(other) < 0;

  /// Whether this version is newer than or equal to [other].
  bool operator >=(PrismVersion other) => compareTo(other) >= 0;

  /// Whether this version is older than or equal to [other].
  bool operator <=(PrismVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is PrismVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll(_padded(4));

  List<int> _padded(int length) {
    final padded = List<int>.filled(length, 0);
    for (var i = 0; i < components.length && i < length; i++) {
      padded[i] = components[i];
    }
    return padded;
  }

  @override
  String toString() => components.join('.');
}

/// Thrown when a version string cannot be parsed.
class PrismVersionException implements Exception {
  /// Creates an exception for the unparseable [input].
  const PrismVersionException(this.input);

  /// The input that failed to parse.
  final String input;

  @override
  String toString() => 'PrismVersionException: cannot parse "$input"';
}
