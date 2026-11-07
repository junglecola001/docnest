import 'package:docnest_core/docnest_core.dart';

import '../dto/doc_dto.dart';

/// Converts between domain rows and their wire form.
///
/// The two shapes are deliberately separate: the domain type has typed ids and
/// no JSON, the DTO is what the OpenAPI document describes. Keeping the mapping
/// in one place is what makes "protocol change ⇒ one file" true.
abstract final class DocMapper {
  /// Wire form of [entry].
  static DocDto toDto(DocEntry entry) => DocDto(
    id: entry.id.value,
    rootId: entry.rootId.value,
    relPath: entry.relPath,
    name: entry.name,
    ext: entry.ext,
    kind: entry.kind,
    size: entry.size,
    modifiedAt: entry.modifiedAt,
    createdAt: entry.createdAt,
    state: entry.state,
    favorite: entry.favorite,
    tagIds: [for (final tag in entry.tagIds) tag.value],
    hasThumbnail: entry.hasThumbnail,
  );

  /// Domain form of [dto].
  static DocEntry toEntry(DocDto dto) => DocEntry(
    id: DocId(dto.id),
    rootId: RootId(dto.rootId),
    relPath: dto.relPath,
    name: dto.name,
    ext: dto.ext,
    kind: dto.kind,
    size: dto.size,
    modifiedAt: dto.modifiedAt,
    createdAt: dto.createdAt,
    state: dto.state,
    favorite: dto.favorite,
    tagIds: [for (final id in dto.tagIds) TagId(id)],
    hasThumbnail: dto.hasThumbnail,
  );
}
