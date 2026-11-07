/// One file discovered by a scan, before it is compared with the index.
final class ScannedFile {
  const ScannedFile({
    required this.relPath,
    required this.size,
    required this.modifiedAt,
    this.fileId,
    this.isHidden = false,
    this.isCloudPlaceholder = false,
  });

  /// Path relative to the root, always `/`-separated.
  ///
  /// The original casing is preserved; Windows compares paths
  /// case-insensitively, so callers that key by path must fold the case
  /// themselves.
  final String relPath;

  /// Size in bytes.
  final int size;

  /// Last write time, in local time, as reported by the file system.
  final DateTime modifiedAt;

  /// NTFS file id, used to recognise a move even when the path changed.
  ///
  /// `null` until the Win32 enumeration lane fills it in; reconcile then falls
  /// back to treating a new path as an insert.
  final String? fileId;

  /// Whether the name is hidden. The attribute itself needs Win32; until that
  /// lane exists this reflects the dot-file convention only.
  final bool isHidden;

  /// OneDrive and friends mark on-demand files; reading them would trigger a
  /// download, so the indexer only stores metadata for these (plan §4.5.2).
  final bool isCloudPlaceholder;

  @override
  String toString() => 'ScannedFile($relPath, $size B, $modifiedAt)';
}

/// One folder discovered by a scan.
///
/// Folders are reported so the library can show an empty directory without a
/// second round trip to disk; they carry no other metadata here.
final class ScannedFolder {
  const ScannedFolder({required this.relPath});

  /// Path relative to the root, always `/`-separated.
  final String relPath;

  @override
  String toString() => 'ScannedFolder($relPath)';
}
