/// Broad category of a document, used for icons, previews and filters.
///
/// The mapping from file extension to [DocKind] lives in the host package so
/// the domain layer stays free of platform policy.
enum DocKind {
  pdf('pdf'),
  word('word'),
  spreadsheet('spreadsheet'),
  presentation('presentation'),
  text('text'),
  markdown('markdown'),
  ebook('ebook'),
  image('image'),
  archive('archive'),
  audio('audio'),
  video('video'),
  other('other');

  const DocKind(this.wire);

  /// Stable name used on the wire and in the database.
  final String wire;

  /// Parses [wire], returning [DocKind.other] for unknown values so a newer
  /// host can introduce kinds without breaking older clients.
  static DocKind fromWire(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return DocKind.other;
  }
}
