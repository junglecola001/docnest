import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_protocol/docnest_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('HostInfoDto', () {
    test('round-trips through JSON', () {
      const info = HostInfoDto(
        hostId: 'h-1',
        name: 'HOME-PC',
        appVersion: '0.1.0+1',
        protocolVersion: 1,
        minClientProtocol: 1,
        indexEpoch: 42,
        capabilities: {Capability.thumbnails, Capability.uploads},
      );
      final decoded = HostInfoDto.fromJson(info.toJson());
      expect(decoded.hostId, 'h-1');
      expect(decoded.name, 'HOME-PC');
      expect(decoded.indexEpoch, 42);
      expect(decoded.capabilities, {Capability.thumbnails, Capability.uploads});
      expect(decoded.supports(Capability.uploads), isTrue);
      expect(decoded.supports(Capability.offers), isFalse);
      expect(decoded.isCompatible, isTrue);
    });

    test('ignores unknown capabilities', () {
      final decoded = HostInfoDto.fromJson({
        'hostId': 'h',
        'name': 'n',
        'appVersion': '1',
        'protocolVersion': 1,
        'minClientProtocol': 1,
        'indexEpoch': 0,
        'capabilities': ['uploads', 'teleport'],
      });
      expect(decoded.capabilities, {Capability.uploads});
    });

    test('rejects a missing required field', () {
      expect(() => HostInfoDto.fromJson({'name': 'n'}), throwsFormatException);
    });
  });

  group('DocDto', () {
    final json = {
      'id': 1,
      'rootId': 2,
      'relPath': 'Contracts/Lease.pdf',
      'name': 'Lease.pdf',
      'ext': 'pdf',
      'kind': 'pdf',
      'size': 2048,
      'modifiedAt': '2026-11-03T14:20:00.000Z',
      'favorite': true,
      'tagIds': [7, 9],
      'hasThumbnail': true,
    };

    test('decodes with defaults for optional fields', () {
      final doc = DocDto.fromJson(json);
      expect(doc.kind, DocKind.pdf);
      expect(doc.state, DocState.active);
      expect(doc.createdAt, isNull);
      expect(doc.tagIds, [7, 9]);
      expect(doc.modifiedAt.isUtc, isTrue);
    });

    test('round-trips', () {
      final doc = DocDto.fromJson(json);
      final again = DocDto.fromJson(doc.toJson());
      expect(again.relPath, doc.relPath);
      expect(again.favorite, isTrue);
      expect(again.modifiedAt, doc.modifiedAt);
    });

    test('unknown kind degrades to other', () {
      final doc = DocDto.fromJson({...json, 'kind': 'hologram'});
      expect(doc.kind, DocKind.other);
    });

    test('rejects wrong types instead of defaulting', () {
      expect(() => DocDto.fromJson({...json, 'size': 'big'}), throwsFormatException);
      expect(
        () => DocDto.fromJson({
          ...json,
          'tagIds': ['7'],
        }),
        throwsFormatException,
      );
      expect(() => DocDto.fromJson({...json, 'modifiedAt': 'yesterday'}), throwsFormatException);
    });
  });

  group('pages', () {
    test('DocPageDto exposes the next cursor', () {
      final page = DocPageDto.fromJson({
        'items': [
          {
            'id': 1,
            'rootId': 1,
            'relPath': 'a.txt',
            'name': 'a.txt',
            'ext': 'txt',
            'kind': 'text',
            'size': 1,
            'modifiedAt': '2026-01-01T00:00:00Z',
          },
        ],
        'nextCursor': 'c2',
      });
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'c2');
    });

    test('ChildrenPageDto requires both lists', () {
      expect(() => ChildrenPageDto.fromJson({'folders': []}), throwsFormatException);
      final page = ChildrenPageDto.fromJson({'folders': [], 'docs': []});
      expect(page.folders, isEmpty);
      expect(page.docs, isEmpty);
    });
  });

  group('uploads', () {
    test('init request defaults to rename on unknown policy', () {
      final request = UploadInitRequestDto.fromJson({
        'rootId': 3,
        'dir': 'Inbox',
        'fileName': 'IMG_2041.HEIC',
        'size': 31457280,
        'modifiedAt': '2026-11-07T09:12:30Z',
        'onConflict': 'explode',
      });
      expect(request.onConflict, ConflictPolicy.rename);
      expect(request.dir, 'Inbox');
    });

    test('init response round-trips', () {
      final response = UploadInitResponseDto(
        uploadId: 'u_5f2c',
        chunkSize: 8 * 1024 * 1024,
        offset: 0,
        expiresAt: DateTime.utc(2026, 11, 8, 9, 12, 31),
      );
      final decoded = UploadInitResponseDto.fromJson(response.toJson());
      expect(decoded.uploadId, 'u_5f2c');
      expect(decoded.chunkSize, 8388608);
      expect(decoded.expiresAt, response.expiresAt);
    });

    test('status maps unknown state to expired (fail safe: resume is refused)', () {
      final status = UploadStatusDto.fromJson({
        'uploadId': 'u',
        'offset': 5,
        'size': 10,
        'state': 'quantum',
      });
      expect(status.state, UploadState.expired);
    });

    test('complete response reports skipped files', () {
      final done = UploadCompleteResponseDto.fromJson({
        'docId': 0,
        'finalName': 'a.pdf',
        'relPath': 'Inbox/a.pdf',
        'skipped': true,
      });
      expect(done.skipped, isTrue);
    });
  });

  group('pairing', () {
    test('pair request omits a null compare code', () {
      const request = PairRequestDto(
        code: '123456',
        deviceName: 'Xiaomi 14',
        platform: 'android',
        model: '23127PN0CC',
        clientProtocol: 1,
      );
      expect(request.toJson().containsKey('compareCode'), isFalse);
      expect(
        PairResponseDto.fromJson({
          'deviceId': 'd1',
          'token': 't',
          'hostId': 'h',
          'hostName': 'PC',
          'protocolVersion': 1,
          'scopes': ['browse', 'upload', 'mind-control'],
        }).scopes,
        {DeviceScope.browse, DeviceScope.upload},
      );
    });
  });

  group('EventDto', () {
    test('unknown event types are ignored, not fatal', () {
      final event = EventDto.fromJson({'seq': 4, 'type': 'doc.exploded', 'payload': {}});
      expect(event.type, isNull);
      expect(event.seq, 4);
    });

    test('known types decode with a payload', () {
      final event = EventDto.fromJson({
        'seq': 5,
        'type': 'doc.created',
        'payload': {'docId': 12},
      });
      expect(event.type, EventType.docCreated);
      expect(event.payload['docId'], 12);
    });

    test('missing payload defaults to an empty map', () {
      final event = EventDto.fromJson({'seq': 1, 'type': 'host.shutdown'});
      expect(event.payload, isEmpty);
      expect(event.type, EventType.hostShutdown);
    });
  });

  group('ApiErrorDto', () {
    test('maps to a typed exception', () {
      final error = ApiErrorDto.fromJson({
        'error': {
          'code': 'PATH_OUTSIDE_ROOT',
          'message': '目标路径不在白名单内',
          'details': {'rootId': 3},
        },
      });
      final exception = error.toException();
      expect(exception, isA<PathOutsideRootException>());
      expect(exception.details['rootId'], 3);
    });

    test('round-trips an exception', () {
      final dto = ApiErrorDto.fromException(NameConflictException(name: 'a.pdf'));
      final json = dto.toJson();
      expect((json['error'] as Map)['code'], 'NAME_CONFLICT');
      expect(ApiErrorDto.fromJson(json).toException(), isA<NameConflictException>());
    });
  });

  test('ApiPaths builds the routes the host serves', () {
    expect(ApiPaths.info, '/api/v1/info');
    expect(ApiPaths.doc(7), '/api/v1/docs/7');
    expect(ApiPaths.docContent(7), '/api/v1/docs/7/content');
    expect(ApiPaths.uploadComplete('u_1'), '/api/v1/uploads/u_1/complete');
    expect(ApiPaths.rootChildren(3), '/api/v1/roots/3/children');
  });
}
