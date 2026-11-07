/// Protocol version negotiation.
library;

abstract final class ProtocolVersion {
  /// Version this build speaks.
  static const int current = 1;

  /// Oldest client version this host still accepts.
  static const int minClient = 1;

  /// True when a peer advertising [version] can talk to this build.
  static bool isCompatible(int version) => version >= minClient && version <= current;
}

/// Optional features a host advertises in `/info`.
///
/// Clients enable features by capability, never by version number. Unknown
/// capability strings from a newer host are ignored.
enum Capability {
  contentSearch('contentSearch'),
  officePreview('officePreview'),
  thumbnails('thumbnails'),
  offers('offers'),
  uploads('uploads'),
  tags('tags');

  const Capability(this.wire);

  final String wire;

  static Set<Capability> parseAll(Iterable<String> wireValues) {
    final known = {for (final capability in values) capability.wire: capability};
    return {for (final value in wireValues) ?known[value]};
  }
}
