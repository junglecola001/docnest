import 'package:docnest_core/docnest_core.dart';

/// A validated `(rootId, relative path)` pair with its absolute counterpart.
class ResolvedPath {
  const ResolvedPath({required this.root, required this.relPath, required this.fullPath});

  final Root root;

  /// Normalised `/`-separated path relative to the root; `''` is the root.
  final String relPath;

  /// Normalised absolute Windows path.
  final String fullPath;

  bool get isRoot => relPath.isEmpty;

  /// Last segment, or the root's own name for the root.
  String get name {
    if (isRoot) return root.name;
    final index = relPath.lastIndexOf('/');
    return index < 0 ? relPath : relPath.substring(index + 1);
  }

  @override
  String toString() => 'ResolvedPath(${root.id.value}, $relPath)';
}
