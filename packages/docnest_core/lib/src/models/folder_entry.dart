import '../ids.dart';

/// A folder row. Kept separately from documents so that empty folders show up
/// in the tree.
class FolderEntry {
  const FolderEntry({
    required this.id,
    required this.rootId,
    required this.relPath,
    required this.name,
    this.parentId,
    this.childCount = 0,
  });

  final FolderId id;
  final RootId rootId;

  /// Relative to the root, `/`-separated; the empty string is the root itself.
  final String relPath;

  final String name;
  final FolderId? parentId;

  /// Number of documents directly inside this folder.
  final int childCount;

  @override
  String toString() => 'FolderEntry(${id.value}, $relPath)';
}
