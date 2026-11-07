import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_protocol/docnest_protocol.dart';
import 'package:test/test.dart';

void main() {
  final doc = DocMapper.toDto(
    DocEntry(
      id: const DocId(7),
      rootId: const RootId(3),
      relPath: 'Inbox/photo.png',
      name: 'photo.png',
      ext: 'png',
      kind: DocKind.image,
      size: 1024,
      modifiedAt: DateTime.utc(2026, 11, 7, 9),
      favorite: true,
      tagIds: const [TagId(1), TagId(4)],
    ),
  );

  final events = <String, LibraryEvent>{
    'doc created': DocCreated(DocMapper.toEntry(doc)),
    'doc updated': DocUpdated(DocMapper.toEntry(doc)),
    'doc moved': const DocMoved(id: DocId(7), rootId: RootId(3), relPath: 'Archive/photo.png'),
    'doc deleted': const DocDeleted(id: DocId(7), rootId: RootId(3)),
    'folder changed': const FolderChanged(rootId: RootId(3), relPath: 'Inbox'),
    'root status': const RootStatusChanged(rootId: RootId(3), status: RootStatus.offline),
    'scan progress': const ScanProgress(rootId: RootId(3), scanned: 10, total: 20, indexed: 4),
    'preview ready': const PreviewReady(id: DocId(7), kind: DocKind.image),
    'transfer offer': const TransferOffered(offerId: 'o-1', id: DocId(7)),
    'device revoked': const DeviceRevoked(deviceId: DeviceId('d-1')),
    'host shutdown': const HostShutdown(),
  };

  test('every event type round-trips through the wire envelope', () {
    var seq = 1;
    for (final entry in events.entries) {
      final dto = EventMapper.toDto(entry.value, seq: seq++);
      expect(dto.type, isNotNull, reason: entry.key);
      // Through JSON and back, the way a socket would deliver it.
      final decoded = EventMapper.fromDto(EventDto.fromJson(dto.toJson()));
      expect(decoded, isNotNull, reason: entry.key);
      expect(decoded.runtimeType, entry.value.runtimeType, reason: entry.key);
      expect(decoded!.type, entry.value.type, reason: entry.key);
    }
  });

  test('document payloads keep their metadata', () {
    final decoded =
        EventMapper.fromDto(
              EventDto.fromJson(
                EventMapper.toDto(DocCreated(DocMapper.toEntry(doc)), seq: 1).toJson(),
              ),
            )!
            as DocCreated;
    expect(decoded.doc.id, const DocId(7));
    expect(decoded.doc.favorite, isTrue);
    expect(decoded.doc.tagIds, const [TagId(1), TagId(4)]);
    expect(decoded.doc.modifiedAt.isUtc, isTrue);
  });

  test('scan progress keeps its counts', () {
    final decoded =
        EventMapper.fromDto(
              EventDto.fromJson(
                EventMapper.toDto(
                  const ScanProgress(rootId: RootId(3), scanned: 5, total: 10, indexed: 2),
                  seq: 4,
                ).toJson(),
              ),
            )!
            as ScanProgress;
    expect(decoded.scanned, 5);
    expect(decoded.fraction, 0.5);
  });

  test('an unknown event type is ignored instead of throwing', () {
    final dto = EventDto.fromJson({'seq': 9, 'type': 'doc.hologram', 'payload': {}});
    expect(EventMapper.fromDto(dto), isNull);
  });

  test('a malformed payload is ignored instead of throwing', () {
    final dto = EventDto.fromJson({
      'seq': 10,
      'type': 'doc.moved',
      'payload': {'docId': 'not a number'},
    });
    expect(EventMapper.fromDto(dto), isNull);
  });

  test('an unknown root status degrades to offline', () {
    final decoded =
        EventMapper.fromDto(
              EventDto.fromJson({
                'seq': 11,
                'type': 'root.status',
                'payload': {'rootId': 2, 'status': 'vibing'},
              }),
            )!
            as RootStatusChanged;
    expect(decoded.status, RootStatus.offline);
  });

  test('DocumentMapper round-trips a domain row', () {
    final entry = DocMapper.toEntry(doc);
    final again = DocMapper.toEntry(DocMapper.toDto(entry));
    expect(again.relPath, entry.relPath);
    expect(again.kind, DocKind.image);
    expect(again.tagIds, entry.tagIds);
  });
}
