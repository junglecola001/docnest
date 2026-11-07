import '../json.dart';

/// Envelope for a message on `WS /api/v1/events`.
///
/// Payloads are small and typed by [type]; clients re-fetch what they need.
class EventDto {
  const EventDto({required this.seq, required this.type, this.payload = const <String, Object?>{}});

  factory EventDto.fromJson(Map<String, Object?> json) {
    final wireType = jsonString(json, 'type');
    final payload = json['payload'];
    return EventDto(
      seq: jsonInt(json, 'seq'),
      type: EventType.fromWire(wireType),
      payload: payload == null ? const {} : jsonObject(payload, context: 'payload'),
    );
  }

  /// Monotonic sequence number; used to resume after a reconnect.
  final int seq;

  /// `null` when this build does not know the event type (newer host).
  final EventType? type;

  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {'seq': seq, 'type': type?.wire ?? '', 'payload': payload};
}

/// Known real-time event types.
enum EventType {
  docCreated('doc.created'),
  docUpdated('doc.updated'),
  docMoved('doc.moved'),
  docDeleted('doc.deleted'),
  folderChanged('folder.changed'),
  rootStatus('root.status'),
  scanProgress('scan.progress'),
  previewReady('preview.ready'),
  transferOffer('transfer.offer'),
  deviceRevoked('device.revoked'),
  hostShutdown('host.shutdown');

  const EventType(this.wire);

  final String wire;

  /// Returns `null` for unknown types so clients can ignore them safely.
  static EventType? fromWire(String wire) {
    for (final type in values) {
      if (type.wire == wire) return type;
    }
    return null;
  }
}
