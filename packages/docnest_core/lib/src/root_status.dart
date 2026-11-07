/// Runtime status of a whitelisted root.
///
/// Mirrors the state machine in the plan (§4.5.2): offline roots keep their
/// index; nothing is deleted until the drive is reachable again.
enum RootStatus {
  /// Probing the path before deciding.
  checking('checking'),

  /// Enumerating and reconciling; results are browsable while it runs.
  scanning('scanning'),

  /// Watching for file system events.
  watching('watching'),

  /// Path missing (unplugged drive, disconnected share). Index is preserved.
  offline('offline'),

  /// No access permission or an unrecoverable scan error.
  error('error');

  const RootStatus(this.wire);

  /// Stable name used on the wire and in the database.
  final String wire;

  /// Whether files can be read from this root right now.
  bool get isOnline => this == RootStatus.watching || this == RootStatus.scanning;

  /// Parses [wire], defaulting to [RootStatus.offline] for unknown values.
  static RootStatus fromWire(String? wire) {
    for (final status in values) {
      if (status.wire == wire) return status;
    }
    return RootStatus.offline;
  }
}
