import 'package:docnest_core/docnest_core.dart';

import 'index_store.dart';
import 'scanned_file.dart';

/// One thing the reconciler decided about one file.
///
/// Actions are pure data: the plan is computed from a scan and the current
/// index without touching either, so it can be logged, tested and applied in
/// one transaction. Inserted rows receive their [DocId] when the plan is
/// applied, not when it is built.
sealed class ReconcileAction {
  const ReconcileAction();

  /// One-line description for logs and test failures.
  String describe();
}

/// A file at a path the index does not know yet.
final class InsertDocAction extends ReconcileAction {
  const InsertDocAction(this.file);

  /// The file to add to the index.
  final ScannedFile file;

  @override
  String describe() => 'insert ${file.relPath}';
}

/// A known file whose size or modification time changed.
final class UpdateDocAction extends ReconcileAction {
  const UpdateDocAction({required this.doc, required this.file});

  /// The row to update in place.
  final IndexedDoc doc;

  /// The scan result that replaces the stored metadata.
  final ScannedFile file;

  @override
  String describe() => 'update ${file.relPath}';
}

/// A known file whose metadata is unchanged; reported so callers can count it
/// and so a plan describes every scanned file.
final class UnchangedDocAction extends ReconcileAction {
  const UnchangedDocAction({required this.doc, required this.file});

  /// The row that already matches the file.
  final IndexedDoc doc;

  /// The scan result that matched.
  final ScannedFile file;

  @override
  String describe() => 'unchanged ${file.relPath}';
}

/// A file whose NTFS file id matches a previously missing row.
///
/// The row keeps its [DocId], tags and notes; only the path and the changed
/// metadata are updated. That is what makes a rename after an offline scan
/// invisible to the user.
final class MovedDocAction extends ReconcileAction {
  const MovedDocAction({required this.doc, required this.file, required this.oldRelPath});

  /// The missing row being reactivated.
  final IndexedDoc doc;

  /// The file at its new path.
  final ScannedFile file;

  /// Path the row had before the move.
  final String oldRelPath;

  /// Path the row gets after the move.
  String get newRelPath => file.relPath;

  @override
  String describe() => 'move $oldRelPath -> $newRelPath';
}

/// An active row the scan did not see.
///
/// Only produced for a completed scan: a drive that vanished halfway through
/// must not mark half the library missing (plan §4.5.2 item 3).
final class MissingDocAction extends ReconcileAction {
  const MissingDocAction(this.doc);

  /// The row that disappears from the scan.
  final IndexedDoc doc;

  @override
  String describe() => 'missing ${doc.relPath}';
}

/// The result of comparing one scan with the index.
final class ReconcilePlan {
  const ReconcilePlan({required this.rootId, required this.actions, required this.scanCompleted});

  /// Root the plan belongs to; rows of other roots are ignored.
  final RootId rootId;

  /// Actions in scan order, with the missing actions appended sorted by path so
  /// the plan is deterministic.
  final List<ReconcileAction> actions;

  /// Whether the scan walked the whole root. When false no [MissingDocAction]
  /// is produced; rows simply stay as they are until the next full scan.
  final bool scanCompleted;

  List<InsertDocAction> get inserts => actions.whereType<InsertDocAction>().toList(growable: false);

  List<UpdateDocAction> get updates => actions.whereType<UpdateDocAction>().toList(growable: false);

  List<UnchangedDocAction> get unchanged =>
      actions.whereType<UnchangedDocAction>().toList(growable: false);

  List<MovedDocAction> get moves => actions.whereType<MovedDocAction>().toList(growable: false);

  List<MissingDocAction> get missing =>
      actions.whereType<MissingDocAction>().toList(growable: false);

  /// Whether applying the plan would write anything.
  bool get hasChanges =>
      inserts.isNotEmpty || updates.isNotEmpty || moves.isNotEmpty || missing.isNotEmpty;

  @override
  String toString() =>
      'ReconcilePlan(root ${rootId.value}, ${actions.length} actions, completed: $scanCompleted)';
}

/// Compares [scanned] with [indexed] and decides what to write.
///
/// Rules (plan §4.5.2):
///  * same path, same size and modification time, active row → unchanged;
///  * same path, changed metadata (or a row that was marked missing but is back)
///    → update;
///  * new path whose file id matches a missing row → move, keeping the id;
///  * new path otherwise → insert;
///  * active row not seen → missing, but only when [scanCompleted].
///
/// A missing row that is still absent produces no action, and a scanned file
/// that was inserted or moved produces an unchanged action on the next run, so
/// applying the plan and planning again yields only unchanged actions.
///
/// Paths are compared exactly. Windows is case-insensitive, so the scanner must
/// report the casing stored in the index; normalising here would fork the
/// comparison rules between this function and the database.
ReconcilePlan planReconcile({
  required RootId rootId,
  required List<ScannedFile> scanned,
  required List<IndexedDoc> indexed,
  bool scanCompleted = true,
}) {
  final byPath = <String, IndexedDoc>{};
  for (final doc in indexed) {
    if (doc.rootId != rootId) continue;
    final existing = byPath[doc.relPath];
    // Prefer the active row when duplicates exist; the missing one is a stale
    // leftover and must not win the path.
    if (existing == null || existing.state == DocState.missing) {
      byPath[doc.relPath] = doc;
    }
  }

  final missingByFileId = <String, IndexedDoc>{};
  for (final doc in indexed) {
    if (doc.rootId != rootId || doc.state != DocState.missing) continue;
    final fileId = doc.fileId;
    if (fileId == null) continue;
    missingByFileId.putIfAbsent(fileId, () => doc);
  }

  final claimed = <DocId>{};
  final actions = <ReconcileAction>[];
  final scannedPaths = <String>{};

  for (final file in scanned) {
    scannedPaths.add(file.relPath);
    final existing = byPath[file.relPath];

    if (existing != null) {
      final unchanged =
          existing.state == DocState.active &&
          existing.size == file.size &&
          existing.modifiedAt == file.modifiedAt;
      actions.add(
        unchanged
            ? UnchangedDocAction(doc: existing, file: file)
            : UpdateDocAction(doc: existing, file: file),
      );
      continue;
    }

    final fileId = file.fileId;
    if (fileId != null) {
      final movedDoc = missingByFileId[fileId];
      if (movedDoc != null && !claimed.contains(movedDoc.id)) {
        claimed.add(movedDoc.id);
        actions.add(MovedDocAction(doc: movedDoc, file: file, oldRelPath: movedDoc.relPath));
        continue;
      }
    }

    actions.add(InsertDocAction(file));
  }

  if (scanCompleted) {
    final unseen =
        indexed
            .where(
              (IndexedDoc doc) =>
                  doc.rootId == rootId &&
                  doc.state == DocState.active &&
                  !scannedPaths.contains(doc.relPath),
            )
            .toList()
          ..sort((IndexedDoc a, IndexedDoc b) => a.relPath.compareTo(b.relPath));
    for (final doc in unseen) {
      actions.add(MissingDocAction(doc));
    }
  }

  return ReconcilePlan(rootId: rootId, actions: actions, scanCompleted: scanCompleted);
}

/// Applies [plan] to a [MemoryIndexStore].
///
/// Test and smoke-path convenience; the SQLite store applies the same switch
/// inside a transaction. Every action is idempotent with respect to the plan,
/// so applying an already-applied plan is harmless.
extension MemoryIndexStoreApply on MemoryIndexStore {
  Future<void> applyPlan(ReconcilePlan plan) async {
    for (final action in plan.actions) {
      switch (action) {
        case InsertDocAction(:final file):
          await upsert(
            IndexedDoc(
              id: allocateId(),
              rootId: plan.rootId,
              relPath: file.relPath,
              size: file.size,
              modifiedAt: file.modifiedAt,
              fileId: file.fileId,
            ),
          );
        case UpdateDocAction(:final doc, :final file):
          await upsert(
            doc.copyWith(
              relPath: file.relPath,
              size: file.size,
              modifiedAt: file.modifiedAt,
              fileId: file.fileId ?? doc.fileId,
              state: DocState.active,
            ),
          );
        case MovedDocAction(:final doc, :final file):
          await upsert(
            doc.copyWith(
              relPath: file.relPath,
              size: file.size,
              modifiedAt: file.modifiedAt,
              fileId: file.fileId ?? doc.fileId,
              state: DocState.active,
            ),
          );
        case UnchangedDocAction():
          break;
        case MissingDocAction(:final doc):
          await markMissing(<DocId>[doc.id]);
      }
    }
  }
}
