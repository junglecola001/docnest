/// Route constants and builders for `/api/v1`.
///
/// Server and client both build paths through this file so a typo cannot
/// desynchronise them.
library;

abstract final class ApiPaths {
  /// Prefix for every JSON endpoint.
  static const String prefix = '/api/v1';

  static const String info = '$prefix/info';
  static const String pair = '$prefix/pair';
  static const String roots = '$prefix/roots';
  static const String docs = '$prefix/docs';
  static const String folders = '$prefix/folders';
  static const String tags = '$prefix/tags';
  static const String uploads = '$prefix/uploads';
  static const String offers = '$prefix/offers';
  static const String events = '$prefix/events';
  static const String opsMove = '$prefix/ops/move';
  static const String opsCopy = '$prefix/ops/copy';
  static const String opsTrash = '$prefix/ops/trash';
  static const String opsRestore = '$prefix/ops/restore';

  static String rootChildren(int rootId) => '$roots/$rootId/children';

  static String doc(int docId) => '$docs/$docId';

  static String docTags(int docId) => '$docs/$docId/tags';

  static String docThumbnail(int docId) => '$docs/$docId/thumbnail';

  static String docPreview(int docId) => '$docs/$docId/preview';

  static String docContent(int docId) => '$docs/$docId/content';

  static String docOpenOnHost(int docId) => '$docs/$docId/open-on-host';

  static String tag(int tagId) => '$tags/$tagId';

  static String upload(String uploadId) => '$uploads/$uploadId';

  static String uploadComplete(String uploadId) => '$uploads/$uploadId/complete';
}

/// Header names used by the transfer endpoints.
abstract final class ApiHeaders {
  static const String authorization = 'Authorization';

  /// Offset in bytes of the chunk being written.
  static const String uploadOffset = 'Upload-Offset';

  /// Lowercase hex SHA-256 of the chunk body.
  static const String chunkSha256 = 'Chunk-SHA256';

  /// Lowercase hex SHA-256 of the whole file, sent on `complete`.
  static const String fileSha256 = 'File-SHA256';
}

/// Media types used by the API.
abstract final class ApiMediaTypes {
  static const String json = 'application/json; charset=utf-8';
  static const String octetStream = 'application/offset+octet-stream';
}
