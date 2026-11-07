import 'package:docnest_core/docnest_core.dart';

import '../json.dart';

/// A document row as transferred over the wire.
class DocDto {
  const DocDto({
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
    this.tagIds = const <int>[],
    this.hasThumbnail = false,
  });

  factory DocDto.fromJson(Map<String, Object?> json) {
    return DocDto(
      id: jsonInt(json, 'id'),
      rootId: jsonInt(json, 'rootId'),
      relPath: jsonString(json, 'relPath'),
      name: jsonString(json, 'name'),
      ext: jsonString(json, 'ext'),
      kind: DocKind.fromWire(jsonStringOrNull(json, 'kind')),
      size: jsonInt(json, 'size'),
      modifiedAt: jsonDateTime(json, 'modifiedAt'),
      createdAt: jsonDateTimeOrNull(json, 'createdAt'),
      state: DocState.fromWire(jsonStringOrNull(json, 'state')),
      favorite: jsonBool(json, 'favorite'),
      tagIds: jsonIntList(json, 'tagIds'),
      hasThumbnail: jsonBool(json, 'hasThumbnail'),
    );
  }

  final int id;
  final int rootId;
  final String relPath;
  final String name;
  final String ext;
  final DocKind kind;
  final int size;
  final DateTime modifiedAt;
  final DateTime? createdAt;
  final DocState state;
  final bool favorite;
  final List<int> tagIds;
  final bool hasThumbnail;

  Map<String, Object?> toJson() => {
    'id': id,
    'rootId': rootId,
    'relPath': relPath,
    'name': name,
    'ext': ext,
    'kind': kind.wire,
    'size': size,
    'modifiedAt': dateTimeToWire(modifiedAt),
    if (createdAt != null) 'createdAt': dateTimeToWire(createdAt!),
    'state': state.wire,
    'favorite': favorite,
    'tagIds': tagIds,
    'hasThumbnail': hasThumbnail,
  };
}

/// Cursor-paginated list of documents (`GET /docs`, `/roots/{id}/children`).
class DocPageDto {
  const DocPageDto({required this.items, this.nextCursor});

  factory DocPageDto.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw FormatException('Field "items" must be a list, got ${rawItems.runtimeType}');
    }
    return DocPageDto(
      items: rawItems
          .map((item) => DocDto.fromJson(jsonObject(item, context: 'items[]')))
          .toList(growable: false),
      nextCursor: jsonStringOrNull(json, 'nextCursor'),
    );
  }

  final List<DocDto> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  Map<String, Object?> toJson() => {
    'items': items.map((d) => d.toJson()).toList(growable: false),
    if (nextCursor != null) 'nextCursor': nextCursor,
  };
}

/// Folder row returned alongside documents in a children listing.
class FolderDto {
  const FolderDto({
    required this.id,
    required this.rootId,
    required this.relPath,
    required this.name,
    this.childCount = 0,
  });

  factory FolderDto.fromJson(Map<String, Object?> json) {
    return FolderDto(
      id: jsonInt(json, 'id'),
      rootId: jsonInt(json, 'rootId'),
      relPath: jsonString(json, 'relPath'),
      name: jsonString(json, 'name'),
      childCount: jsonInt(json, 'childCount'),
    );
  }

  final int id;
  final int rootId;
  final String relPath;
  final String name;
  final int childCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'rootId': rootId,
    'relPath': relPath,
    'name': name,
    'childCount': childCount,
  };
}

/// Combined children listing: folders first, then documents.
class ChildrenPageDto {
  const ChildrenPageDto({required this.folders, required this.docs, this.nextCursor});

  factory ChildrenPageDto.fromJson(Map<String, Object?> json) {
    final rawFolders = json['folders'];
    final rawDocs = json['docs'];
    if (rawFolders is! List || rawDocs is! List) {
      throw const FormatException('Children page requires "folders" and "docs" lists');
    }
    return ChildrenPageDto(
      folders: rawFolders
          .map((item) => FolderDto.fromJson(jsonObject(item, context: 'folders[]')))
          .toList(growable: false),
      docs: rawDocs
          .map((item) => DocDto.fromJson(jsonObject(item, context: 'docs[]')))
          .toList(growable: false),
      nextCursor: jsonStringOrNull(json, 'nextCursor'),
    );
  }

  final List<FolderDto> folders;
  final List<DocDto> docs;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'folders': folders.map((f) => f.toJson()).toList(growable: false),
    'docs': docs.map((d) => d.toJson()).toList(growable: false),
    if (nextCursor != null) 'nextCursor': nextCursor,
  };
}
