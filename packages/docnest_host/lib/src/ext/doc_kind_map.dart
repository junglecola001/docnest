import 'package:docnest_core/docnest_core.dart';

/// Extensions indexed by default (plan appendix B).
///
/// Images are deliberately absent: they are opt-in per root because indexing
/// them can pull cloud placeholders down to disk.
const Set<String> defaultIndexExtensions = <String>{
  'pdf',
  'doc',
  'docx',
  'wps',
  'rtf',
  'odt',
  'xls',
  'xlsx',
  'et',
  'ods',
  'csv',
  'ppt',
  'pptx',
  'dps',
  'odp',
  'txt',
  'md',
  'markdown',
  'log',
  'json',
  'xml',
  'yaml',
  'yml',
  'ini',
  'epub',
};

/// Extensions treated as images (plan appendix B).
const Set<String> defaultImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'heic',
};

/// Extension (without a dot, lowercase) to [DocKind].
///
/// Covers a few kinds that the default index set does not include (`zip`,
/// `mp3`, …) so that files the user explicitly opted into still get a sensible
/// icon and filter bucket.
const Map<String, DocKind> _kindByExtension = <String, DocKind>{
  'pdf': DocKind.pdf,
  'doc': DocKind.word,
  'docx': DocKind.word,
  'wps': DocKind.word,
  'rtf': DocKind.word,
  'odt': DocKind.word,
  'xls': DocKind.spreadsheet,
  'xlsx': DocKind.spreadsheet,
  'et': DocKind.spreadsheet,
  'ods': DocKind.spreadsheet,
  'csv': DocKind.spreadsheet,
  'ppt': DocKind.presentation,
  'pptx': DocKind.presentation,
  'dps': DocKind.presentation,
  'odp': DocKind.presentation,
  'txt': DocKind.text,
  'log': DocKind.text,
  'ini': DocKind.text,
  'json': DocKind.text,
  'xml': DocKind.text,
  'yaml': DocKind.text,
  'yml': DocKind.text,
  'md': DocKind.markdown,
  'markdown': DocKind.markdown,
  'epub': DocKind.ebook,
  'mobi': DocKind.ebook,
  'azw3': DocKind.ebook,
  'jpg': DocKind.image,
  'jpeg': DocKind.image,
  'png': DocKind.image,
  'webp': DocKind.image,
  'gif': DocKind.image,
  'bmp': DocKind.image,
  'heic': DocKind.image,
  'tif': DocKind.image,
  'tiff': DocKind.image,
  'zip': DocKind.archive,
  '7z': DocKind.archive,
  'rar': DocKind.archive,
  'tar': DocKind.archive,
  'gz': DocKind.archive,
  'mp3': DocKind.audio,
  'wav': DocKind.audio,
  'flac': DocKind.audio,
  'm4a': DocKind.audio,
  'mp4': DocKind.video,
  'mkv': DocKind.video,
  'avi': DocKind.video,
  'mov': DocKind.video,
};

/// Kind for [ext], which may be given with or without a leading dot and in any
/// case.
///
/// Unknown or empty extensions map to [DocKind.other] so that a file picked up
/// through a user-supplied extension still gets a row.
DocKind kindForExtension(String ext) => _kindByExtension[_normalize(ext)] ?? DocKind.other;

/// The extension set a root actually indexes.
///
/// [configured] is the per-root override from `Root.includeExts`. An empty set
/// means "use [defaultIndexExtensions]" (plan appendix B), so a freshly added
/// root indexes documents without the user having to list extensions by hand.
/// [includeImages] adds [defaultImageExtensions] to whichever base applies;
/// images stay opt-in because indexing one may force a cloud download.
Set<String> resolveIndexExtensions({required Set<String> configured, bool includeImages = false}) {
  final base = configured.isEmpty
      ? defaultIndexExtensions
      : configured.map(_normalize).where((String ext) => ext.isNotEmpty).toSet();
  return includeImages ? <String>{...base, ...defaultImageExtensions} : base;
}

/// Lowercases and strips one leading dot, tolerating `.PDF` and `pdf` alike.
String _normalize(String ext) {
  var value = ext.trim().toLowerCase();
  if (value.startsWith('.')) value = value.substring(1);
  return value;
}
