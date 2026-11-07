/// Host-side services. Kept free of Flutter so it runs under `dart test`.
///
/// Only the Windows FFI package and the Flutter app may import platform
/// specific code; everything below is portable Dart.
library;

export 'src/ext/doc_kind_map.dart';
export 'src/fs/default_excludes.dart';
export 'src/fs/exclude_globs.dart';
export 'src/fs/io_path_probe.dart';
export 'src/path/conflict_resolver.dart';
export 'src/path/name_sanitizer.dart';
export 'src/path/path_guard.dart';
export 'src/path/resolved_path.dart';
export 'src/scan/index_store.dart';
export 'src/scan/reconciler.dart';
export 'src/scan/scanned_file.dart';
export 'src/scan/scanner.dart';
export 'src/search/name_index.dart';
export 'src/search/search_syntax.dart';
export 'src/search/tokenizer.dart';
export 'src/upload/chunk_sink.dart';
export 'src/upload/upload_registry.dart';
export 'src/upload/upload_session.dart';
