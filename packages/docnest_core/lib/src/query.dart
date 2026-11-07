import 'doc_kind.dart';
import 'ids.dart';

/// Sort keys shared by local queries and the `/docs` API.
enum SortField {
  name('name'),
  modified('modified'),
  created('created'),
  size('size'),
  kind('kind');

  const SortField(this.wire);

  final String wire;

  static SortField fromWire(String? wire) {
    for (final field in values) {
      if (field.wire == wire) return field;
    }
    return SortField.name;
  }
}

/// Sort direction.
enum SortDirection {
  ascending('asc'),
  descending('desc');

  const SortDirection(this.wire);

  final String wire;

  static SortDirection fromWire(String? wire) =>
      wire == 'desc' ? SortDirection.descending : SortDirection.ascending;
}

/// A page of results plus the cursor for the next one.
///
/// Cursors are opaque: callers must not parse or construct them.
class PageOf<T> {
  const PageOf({required this.items, this.nextCursor});

  const PageOf.empty() : items = const [], nextCursor = null;

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  int get length => items.length;

  PageOf<R> map<R>(R Function(T item) transform) =>
      PageOf<R>(items: items.map(transform).toList(growable: false), nextCursor: nextCursor);
}

/// Structured query used by the library, search and remote API.
class DocQuery {
  const DocQuery({
    this.text,
    this.rootId,
    this.dirPath,
    this.kinds = const <DocKind>{},
    this.exts = const <String>{},
    this.tagIds = const <TagId>[],
    this.favoritesOnly = false,
    this.modifiedAfter,
    this.modifiedBefore,
    this.minSize,
    this.maxSize,
    this.sort = SortField.name,
    this.direction = SortDirection.ascending,
    this.limit = 100,
    this.cursor,
  });

  /// Free text: matched against name, pinyin, initials and (M4) content.
  final String? text;

  final RootId? rootId;

  /// Restrict to a folder subtree; empty string means the whole root.
  final String? dirPath;

  final Set<DocKind> kinds;
  final Set<String> exts;
  final List<TagId> tagIds;
  final bool favoritesOnly;
  final DateTime? modifiedAfter;
  final DateTime? modifiedBefore;
  final int? minSize;
  final int? maxSize;
  final SortField sort;
  final SortDirection direction;

  /// Page size. The host clamps this to its own maximum.
  final int limit;

  final String? cursor;

  DocQuery copyWith({
    String? Function()? text,
    RootId? Function()? rootId,
    String? Function()? dirPath,
    Set<DocKind>? kinds,
    Set<String>? exts,
    List<TagId>? tagIds,
    bool? favoritesOnly,
    DateTime? Function()? modifiedAfter,
    DateTime? Function()? modifiedBefore,
    int? Function()? minSize,
    int? Function()? maxSize,
    SortField? sort,
    SortDirection? direction,
    int? limit,
    String? Function()? cursor,
  }) {
    return DocQuery(
      text: text == null ? this.text : text(),
      rootId: rootId == null ? this.rootId : rootId(),
      dirPath: dirPath == null ? this.dirPath : dirPath(),
      kinds: kinds ?? this.kinds,
      exts: exts ?? this.exts,
      tagIds: tagIds ?? this.tagIds,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      modifiedAfter: modifiedAfter == null ? this.modifiedAfter : modifiedAfter(),
      modifiedBefore: modifiedBefore == null ? this.modifiedBefore : modifiedBefore(),
      minSize: minSize == null ? this.minSize : minSize(),
      maxSize: maxSize == null ? this.maxSize : maxSize(),
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
      limit: limit ?? this.limit,
      cursor: cursor == null ? this.cursor : cursor(),
    );
  }

  /// Stable cache key; used by the list controller to detect real changes.
  String get cacheKey => [
    text ?? '',
    rootId?.value ?? '',
    dirPath ?? '',
    kinds.map((k) => k.wire).join(','),
    exts.join(','),
    tagIds.map((t) => t.value).join(','),
    favoritesOnly,
    modifiedAfter?.toIso8601String() ?? '',
    modifiedBefore?.toIso8601String() ?? '',
    minSize ?? '',
    maxSize ?? '',
    sort.wire,
    direction.wire,
    limit,
  ].join('|');

  @override
  String toString() => 'DocQuery($cacheKey)';
}
