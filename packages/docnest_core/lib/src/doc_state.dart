/// Lifecycle of an indexed document row.
enum DocState {
  /// Present on disk and indexed.
  active('active'),

  /// Previously indexed but absent from the last complete scan. Kept for a
  /// grace period so that a rename or drive-letter change keeps its metadata.
  missing('missing');

  const DocState(this.wire);

  /// Stable name used on the wire and in the database.
  final String wire;

  /// Parses [wire], defaulting to [DocState.active].
  static DocState fromWire(String? wire) {
    for (final state in values) {
      if (state.wire == wire) return state;
    }
    return DocState.active;
  }
}
