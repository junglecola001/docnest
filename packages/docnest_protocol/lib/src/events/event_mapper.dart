import 'package:docnest_core/docnest_core.dart';

import '../dto/doc_dto.dart';
import '../dto/event_dto.dart';
import '../json.dart';
import 'doc_mapper.dart';

/// Translates domain events to the `/events` wire envelope and back.
///
/// Events carry ids, not payloads (plan §3.8), so a client re-queries what it
/// needs. Anything malformed or unknown decodes to `null` instead of throwing:
/// a newer host must never be able to break an older client's socket.
abstract final class EventMapper {
  /// Wraps [event] with its sequence number.
  static EventDto toDto(LibraryEvent event, {required int seq}) {
    return EventDto(seq: seq, type: _typeOf(event), payload: _payloadOf(event));
  }

  /// Rebuilds the domain event, or `null` when this build cannot understand it.
  static LibraryEvent? fromDto(EventDto dto) {
    final type = dto.type;
    if (type == null) return null;
    final payload = dto.payload;
    try {
      switch (type) {
        case EventType.docCreated:
        case EventType.docUpdated:
          final doc = DocDto.fromJson(jsonObject(payload['doc'], context: 'doc'));
          final entry = DocMapper.toEntry(doc);
          return type == EventType.docCreated ? DocCreated(entry) : DocUpdated(entry);
        case EventType.docMoved:
          return DocMoved(
            id: DocId(jsonInt(payload, 'docId')),
            rootId: RootId(jsonInt(payload, 'rootId')),
            relPath: jsonString(payload, 'relPath'),
          );
        case EventType.docDeleted:
          return DocDeleted(
            id: DocId(jsonInt(payload, 'docId')),
            rootId: RootId(jsonInt(payload, 'rootId')),
          );
        case EventType.folderChanged:
          return FolderChanged(
            rootId: RootId(jsonInt(payload, 'rootId')),
            relPath: jsonString(payload, 'relPath'),
          );
        case EventType.rootStatus:
          return RootStatusChanged(
            rootId: RootId(jsonInt(payload, 'rootId')),
            status: RootStatus.fromWire(jsonStringOrNull(payload, 'status')),
          );
        case EventType.scanProgress:
          return ScanProgress(
            rootId: RootId(jsonInt(payload, 'rootId')),
            scanned: jsonInt(payload, 'scanned'),
            total: jsonInt(payload, 'total'),
            indexed: jsonInt(payload, 'indexed'),
          );
        case EventType.previewReady:
          final docId = jsonInt(payload, 'docId');
          final kind = DocKind.fromWire(jsonStringOrNull(payload, 'kind'));
          return PreviewReady(id: DocId(docId), kind: kind);
        case EventType.transferOffer:
          return TransferOffered(
            offerId: jsonString(payload, 'offerId'),
            id: DocId(jsonInt(payload, 'docId')),
          );
        case EventType.deviceRevoked:
          return DeviceRevoked(deviceId: DeviceId(jsonString(payload, 'deviceId')));
        case EventType.hostShutdown:
          return const HostShutdown();
      }
    } on FormatException {
      // Malformed payload from a newer/broken peer: ignore this event.
      return null;
    }
  }

  static EventType _typeOf(LibraryEvent event) => switch (event) {
    DocCreated() => EventType.docCreated,
    DocUpdated() => EventType.docUpdated,
    DocMoved() => EventType.docMoved,
    DocDeleted() => EventType.docDeleted,
    FolderChanged() => EventType.folderChanged,
    RootStatusChanged() => EventType.rootStatus,
    ScanProgress() => EventType.scanProgress,
    PreviewReady() => EventType.previewReady,
    TransferOffered() => EventType.transferOffer,
    DeviceRevoked() => EventType.deviceRevoked,
    HostShutdown() => EventType.hostShutdown,
  };

  static Map<String, Object?> _payloadOf(LibraryEvent event) => switch (event) {
    DocCreated(:final doc) => {'doc': DocMapper.toDto(doc).toJson()},
    DocUpdated(:final doc) => {'doc': DocMapper.toDto(doc).toJson()},
    DocMoved(:final id, :final rootId, :final relPath) => {
      'docId': id.value,
      'rootId': rootId.value,
      'relPath': relPath,
    },
    DocDeleted(:final id, :final rootId) => {'docId': id.value, 'rootId': rootId.value},
    FolderChanged(:final rootId, :final relPath) => {'rootId': rootId.value, 'relPath': relPath},
    RootStatusChanged(:final rootId, :final status) => {
      'rootId': rootId.value,
      'status': status.wire,
    },
    ScanProgress(:final rootId, :final scanned, :final total, :final indexed) => {
      'rootId': rootId.value,
      'scanned': scanned,
      'total': total,
      'indexed': indexed,
    },
    PreviewReady(:final id, :final kind) => {'docId': id.value, 'kind': kind.wire},
    TransferOffered(:final offerId, :final id) => {'offerId': offerId, 'docId': id.value},
    DeviceRevoked(:final deviceId) => {'deviceId': deviceId.value},
    HostShutdown() => const <String, Object?>{},
  };
}
