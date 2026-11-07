/// Permissions a paired device can hold.
enum DeviceScope {
  browse('browse'),
  upload('upload'),
  manage('manage'),
  delete('delete');

  const DeviceScope(this.wire);

  /// Stable name used on the wire and in the database.
  final String wire;

  /// Parses [wire], returning `null` for unknown scopes. Unknown scopes are
  /// ignored rather than granted: a newer host must not widen access here.
  static DeviceScope? tryParse(String? wire) {
    for (final scope in values) {
      if (scope.wire == wire) return scope;
    }
    return null;
  }
}
