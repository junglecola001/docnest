/// What the host does when the target file name already exists.
enum ConflictPolicy {
  /// Keep both: `report.pdf` becomes `report (1).pdf`.
  rename('rename'),

  /// Leave the existing file untouched and report success without a write.
  skip('skip'),

  /// Move the existing file to the trash, then write the new one.
  overwrite('overwrite');

  const ConflictPolicy(this.wire);

  /// Stable name used on the wire.
  final String wire;

  /// Parses [wire], defaulting to [ConflictPolicy.rename].
  static ConflictPolicy fromWire(String? wire) {
    for (final policy in values) {
      if (policy.wire == wire) return policy;
    }
    return ConflictPolicy.rename;
  }
}
