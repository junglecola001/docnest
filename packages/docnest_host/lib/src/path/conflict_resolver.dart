import 'package:docnest_core/docnest_core.dart';

/// Picks the final file name for a write, honouring the client's policy.
abstract final class ConflictResolver {
  /// Highest `(n)` suffix tried before falling back to a timestamp suffix.
  static const int maxRenameAttempts = 1000;

  /// Returns the name to write, or `null` when [policy] says to skip.
  ///
  /// [existing] must contain lowercased names in the target directory, because
  /// Windows compares names case-insensitively.
  static String? resolve({
    required String desiredName,
    required Set<String> existing,
    required ConflictPolicy policy,
    DateTime? now,
  }) {
    // Windows compares names case-insensitively; normalise once here so callers
    // cannot accidentally let `Report.PDF` coexist with `report.pdf`.
    final taken = <String>{for (final name in existing) name.toLowerCase()};
    if (!taken.contains(desiredName.toLowerCase())) return desiredName;
    switch (policy) {
      case ConflictPolicy.overwrite:
        return desiredName;
      case ConflictPolicy.skip:
        return null;
      case ConflictPolicy.rename:
        return _nextFreeName(desiredName, taken, now ?? DateTime.now());
    }
  }

  /// `report.pdf` → `report (1).pdf`, `report (2).pdf`, …
  static String _nextFreeName(String desiredName, Set<String> existing, DateTime now) {
    final dot = desiredName.lastIndexOf('.');
    final hasExtension = dot > 0;
    final stem = hasExtension ? desiredName.substring(0, dot) : desiredName;
    final extension = hasExtension ? desiredName.substring(dot) : '';
    for (var attempt = 1; attempt <= maxRenameAttempts; attempt++) {
      final candidate = '$stem ($attempt)$extension';
      if (!existing.contains(candidate.toLowerCase())) return candidate;
    }
    // A directory with 1000 copies of the same name is pathological; a
    // timestamp cannot collide with the `(n)` pattern we already tried.
    final stamp = now.toUtc().millisecondsSinceEpoch;
    final candidate = '$stem ($stamp)$extension';
    if (existing.contains(candidate.toLowerCase())) {
      throw NameConflictException(name: 'Unable to find a free file name');
    }
    return candidate;
  }
}
