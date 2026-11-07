import '../doc_kind.dart';
import '../doc_state.dart';
import '../ids.dart';

/// Row shown in library lists: metadata only, no content.
class DocEntry {
  const DocEntry({
    required this.id,
    required this.rootId,
    required this.relPath,
    required this.name,
    required this.ext,
    required this.kind,
    required this.size,
    required this.modifiedAt,
    this.createdAt,
    this.state = DocState.active,
    this.favorite = false,
    this.tagIds = const <TagId>[],
    this.hasThumbnail = false,
  });

  final DocId id;
  final RootId rootId;

  /// Path relative to the root, always `/`-separated.
  final String relPath;

  final String name;

  /// Lowercase, no dot. Empty for extension-less files.
  final String ext;

  final DocKind kind;
  final int size;
  final DateTime? createdAt;
  final DateTime modifiedAt;
  final DocState state;
  final bool favorite;
  final List<TagId> tagIds;
  final bool hasThumbnail;

  /// Name of the containing folder, or the empty string at the root.
  String get dirPath {
    final index = relPath.lastIndexOf('/');
    return index < 0 ? '' : relPath.substring(0, index);
  }

  DocEntry copyWith({
    String? relPath,
    String? name,
    String? ext,
    DocKind? kind,
    int? size,
    DateTime? modifiedAt,
    DocState? state,
    bool? favorite,
    List<TagId>? tagIds,
    bool? hasThumbnail,
  }) {
    return DocEntry(
      id: id,
      rootId: rootId,
      relPath: relPath ?? this.relPath,
      name: name ?? this.name,
      ext: ext ?? this.ext,
      kind: kind ?? this.kind,
      size: size ?? this.size,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      state: state ?? this.state,
      favorite: favorite ?? this.favorite,
      tagIds: tagIds ?? this.tagIds,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
    );
  }

  @override
  String toString() => 'DocEntry(${id.value}, $relPath)';
}
