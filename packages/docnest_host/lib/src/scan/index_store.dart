import 'package:docnest_core/docnest_core.dart';

/// One row of the document index as the scanner sees it.
///
/// Deliberately narrower than the full document record: reconciling only needs
/// identity, location and the metadata that decides whether a file changed.
/// Tags, notes and extracted text live in other tables keyed by [id] and are
/// untouched by a move or an update.
final class IndexedDoc {
  const IndexedDoc({
    required this.id,
    required this.rootId,
    required this.relPath,
    required this.size,
    required this.modifiedAt,
    this.fileId,
    this.state = DocState.active,
  });

  /// Stable document id. A move keeps it, so tags and notes survive a rename.
  final DocId id;

  /// Root the row belongs to.
  final RootId rootId;

  /// Path relative to the root, `/`-separated.
  final String relPath;

  /// Size in bytes at the time of the last scan.
  final int size;

  /// Last write time reported by the file system.
  final DateTime modifiedAt;

  /// NTFS file id used to recognise a move (see `ScannedFile.fileId`).
  final String? fileId;

  /// [DocState.missing] rows are kept for a grace period so that a move can be
  /// recognised; see the reconciler.
  final DocState state;

  /// Returns a copy with the given fields replaced.
  IndexedDoc copyWith({
    RootId? rootId,
    String? relPath,
    int? size,
    DateTime? modifiedAt,
    String? fileId,
    DocState? state,
  }) {
    return IndexedDoc(
      id: id,
      rootId: rootId ?? this.rootId,
      relPath: relPath ?? this.relPath,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      fileId: fileId ?? this.fileId,
      state: state ?? this.state,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! IndexedDoc) return false;
    return other.id == id &&
        other.rootId == rootId &&
        other.relPath == relPath &&
        other.size == size &&
        other.modifiedAt == modifiedAt &&
        other.fileId == fileId &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(id, rootId, relPath, size, modifiedAt, fileId, state);

  @override
  String toString() => 'IndexedDoc(${id.value}, $relPath, ${state.wire})';
}

/// Persistence seam for the scan/reconcile loop.
///
/// Methods are asynchronous because the production implementation talks to
/// SQLite through drift; the in-memory implementation below completes
/// immediately.
abstract interface class IndexStore {
  /// Every row of [rootId], in a deterministic order.
  Future<List<IndexedDoc>> docsInRoot(RootId rootId);

  /// The row previously marked missing whose NTFS file id is [fileId].
  ///
  /// Returns `null` when the file is unknown, or when the row is still active
  /// (an active row at a different path is an unexpected duplicate rather than
  /// a move).
  Future<IndexedDoc?> findMissingByFileId({required RootId rootId, required String fileId});

  /// Inserts [doc] or replaces the row with the same id.
  Future<void> upsert(IndexedDoc doc);

  /// Marks [docIds] as [DocState.missing] after a complete scan did not see
  /// them.
  Future<void> markMissing(Iterable<DocId> docIds);

  /// Deletes [docIds] once the missing grace period has elapsed.
  Future<void> remove(Iterable<DocId> docIds);
}

/// [IndexStore] backed by a map, for tests and for the first-run smoke path.
final class MemoryIndexStore implements IndexStore {
  /// [nextDocId] is the first id [allocateId] hands out.
  MemoryIndexStore({int nextDocId = 1}) : _nextDocId = nextDocId;

  final Map<int, IndexedDoc> _docs = <int, IndexedDoc>{};
  int _nextDocId;

  /// Allocates an id for a new document.
  ///
  /// The production store gets this from SQLite's autoincrement; the memory
  /// store keeps a counter so tests can build rows without inventing ids.
  DocId allocateId() => DocId(_nextDocId++);

  @override
  Future<List<IndexedDoc>> docsInRoot(RootId rootId) async {
    final docs = _docs.values.where((IndexedDoc doc) => doc.rootId == rootId).toList()
      ..sort((IndexedDoc a, IndexedDoc b) => a.relPath.compareTo(b.relPath));
    return docs;
  }

  @override
  Future<IndexedDoc?> findMissingByFileId({required RootId rootId, required String fileId}) async {
    final candidates =
        _docs.values
            .where(
              (IndexedDoc doc) =>
                  doc.rootId == rootId && doc.state == DocState.missing && doc.fileId == fileId,
            )
            .toList()
          ..sort((IndexedDoc a, IndexedDoc b) => a.relPath.compareTo(b.relPath));
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<void> upsert(IndexedDoc doc) async {
    if (doc.id.value <= 0) {
      throw ArgumentError.value(doc.id.value, 'doc.id', 'Document ids must be positive');
    }
    if (doc.id.value >= _nextDocId) _nextDocId = doc.id.value + 1;
    _docs[doc.id.value] = doc;
  }

  @override
  Future<void> markMissing(Iterable<DocId> docIds) async {
    for (final id in docIds) {
      final doc = _docs[id.value];
      if (doc == null || doc.state == DocState.missing) continue;
      _docs[id.value] = doc.copyWith(state: DocState.missing);
    }
  }

  @override
  Future<void> remove(Iterable<DocId> docIds) async {
    for (final id in docIds) {
      _docs.remove(id.value);
    }
  }
}
