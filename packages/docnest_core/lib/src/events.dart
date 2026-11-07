import 'doc_kind.dart';
import 'ids.dart';
import 'models/doc_entry.dart';
import 'root_status.dart';

/// Real-time change notifications emitted by both repository implementations.
///
/// Events are intentionally light: they carry ids, not payloads. Consumers
/// re-query the rows they care about.
sealed class LibraryEvent {
  const LibraryEvent();

  /// Event types are also used as the wire `type` of the `/events` socket.
  String get type;
}

/// A document was indexed for the first time.
final class DocCreated extends LibraryEvent {
  const DocCreated(this.doc);

  final DocEntry doc;

  @override
  String get type => 'doc.created';
}

/// Metadata of an existing document changed (size, mtime, tags, favorite).
final class DocUpdated extends LibraryEvent {
  const DocUpdated(this.doc);

  final DocEntry doc;

  @override
  String get type => 'doc.updated';
}

/// A document changed path, inside or across roots.
final class DocMoved extends LibraryEvent {
  const DocMoved({required this.id, required this.rootId, required this.relPath});

  final DocId id;
  final RootId rootId;
  final String relPath;

  @override
  String get type => 'doc.moved';
}

/// A document disappeared from the index (or was trashed).
final class DocDeleted extends LibraryEvent {
  const DocDeleted({required this.id, required this.rootId});

  final DocId id;
  final RootId rootId;

  @override
  String get type => 'doc.deleted';
}

/// Folder contents changed; [relPath] is the affected folder inside [rootId].
final class FolderChanged extends LibraryEvent {
  const FolderChanged({required this.rootId, required this.relPath});

  final RootId rootId;
  final String relPath;

  @override
  String get type => 'folder.changed';
}

/// A root moved between [RootStatus] values.
final class RootStatusChanged extends LibraryEvent {
  const RootStatusChanged({required this.rootId, required this.status});

  final RootId rootId;
  final RootStatus status;

  @override
  String get type => 'root.status';
}

/// Progress of a scan/reconcile pass.
final class ScanProgress extends LibraryEvent {
  const ScanProgress({
    required this.rootId,
    required this.scanned,
    required this.total,
    required this.indexed,
  });

  final RootId rootId;

  /// Files walked so far.
  final int scanned;

  /// Estimated total, or `0` when unknown.
  final int total;

  /// Rows written or updated so far.
  final int indexed;

  /// Fraction in `[0, 1]`, or `null` when the total is unknown.
  double? get fraction => total <= 0 ? null : (scanned / total).clamp(0.0, 1.0);

  @override
  String get type => 'scan.progress';
}

/// A preview (thumbnail or PDF) finished rendering.
final class PreviewReady extends LibraryEvent {
  const PreviewReady({required this.id, required this.kind});

  final DocId id;
  final DocKind kind;

  @override
  String get type => 'preview.ready';
}

/// The host offers a file to this device (computer → phone push).
final class TransferOffered extends LibraryEvent {
  const TransferOffered({required this.offerId, required this.id});

  final String offerId;
  final DocId id;

  @override
  String get type => 'transfer.offer';
}

/// A device was revoked; the client must clear its token and re-pair.
final class DeviceRevoked extends LibraryEvent {
  const DeviceRevoked({required this.deviceId});

  final DeviceId deviceId;

  @override
  String get type => 'device.revoked';
}

/// The host is shutting down; clients should show a reconnecting state.
final class HostShutdown extends LibraryEvent {
  const HostShutdown();

  @override
  String get type => 'host.shutdown';
}
