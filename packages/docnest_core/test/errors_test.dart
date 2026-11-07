import 'package:docnest_core/docnest_core.dart';
import 'package:test/test.dart';

void main() {
  group('DocNestErrorCode', () {
    test('every code has a unique SCREAMING_SNAKE wire value', () {
      final wires = DocNestErrorCode.values.map((c) => c.wire).toList();
      expect(wires.toSet(), hasLength(wires.length));
      for (final wire in wires) {
        expect(wire, matches(RegExp(r'^[A-Z][A-Z_]*$')));
      }
    });

    test('tryParse round-trips every code', () {
      for (final code in DocNestErrorCode.values) {
        expect(DocNestErrorCode.tryParse(code.wire), code);
      }
    });

    test('tryParse returns null for unknown codes', () {
      expect(DocNestErrorCode.tryParse('FROM_THE_FUTURE'), isNull);
      expect(DocNestErrorCode.tryParse(null), isNull);
    });
  });

  group('appExceptionFromCode', () {
    test('maps wire codes to concrete exception types', () {
      expect(appExceptionFromCode('UNAUTHORIZED'), isA<UnauthorizedException>());
      expect(appExceptionFromCode('TOKEN_REVOKED'), isA<TokenRevokedException>());
      expect(appExceptionFromCode('FORBIDDEN_SCOPE'), isA<ForbiddenScopeException>());
      expect(appExceptionFromCode('ROOT_OFFLINE'), isA<RootOfflineException>());
      expect(appExceptionFromCode('ROOT_READ_ONLY'), isA<ReadOnlyException>());
      expect(appExceptionFromCode('PATH_OUTSIDE_ROOT'), isA<PathOutsideRootException>());
      expect(appExceptionFromCode('INVALID_NAME'), isA<InvalidNameException>());
      expect(appExceptionFromCode('NAME_CONFLICT'), isA<NameConflictException>());
      expect(appExceptionFromCode('NOT_FOUND'), isA<NotFoundException>());
      expect(appExceptionFromCode('FILE_LOCKED'), isA<FileLockedException>());
      expect(appExceptionFromCode('INSUFFICIENT_SPACE'), isA<InsufficientSpaceException>());
      expect(appExceptionFromCode('UPLOAD_OFFSET_MISMATCH'), isA<UploadOffsetMismatchException>());
      expect(appExceptionFromCode('UPLOAD_EXPIRED'), isA<UploadExpiredException>());
      expect(appExceptionFromCode('CHECKSUM_MISMATCH'), isA<ChecksumMismatchException>());
      expect(appExceptionFromCode('PREVIEW_UNAVAILABLE'), isA<PreviewUnavailableException>());
      expect(appExceptionFromCode('RATE_LIMITED'), isA<RateLimitedException>());
      expect(appExceptionFromCode('PROTOCOL_UNSUPPORTED'), isA<IncompatibleException>());
      expect(appExceptionFromCode('INVALID_REQUEST'), isA<InvalidRequestException>());
      expect(appExceptionFromCode('INTERNAL'), isA<UnknownException>());
    });

    test('unknown and missing codes degrade to UnknownException', () {
      expect(appExceptionFromCode('WHATEVER'), isA<UnknownException>());
      expect(appExceptionFromCode(null), isA<UnknownException>());
    });

    test('carries details into typed exceptions', () {
      final error =
          appExceptionFromCode('ROOT_OFFLINE', details: {'rootId': 7}) as RootOfflineException;
      expect(error.details['rootId'], 7);
      expect(error.code, DocNestErrorCode.rootOffline);
    });

    test('does not throw on a malformed details payload', () {
      final error =
          appExceptionFromCode('INSUFFICIENT_SPACE', details: {'requiredBytes': 'not a number'})
              as InsufficientSpaceException;
      expect(error.details['requiredBytes'], 0);
    });
  });

  group('enums tolerate unknown wire values', () {
    test('DocKind falls back to other', () {
      expect(DocKind.fromWire('pdf'), DocKind.pdf);
      expect(DocKind.fromWire('hologram'), DocKind.other);
      expect(DocKind.fromWire(null), DocKind.other);
    });

    test('RootStatus falls back to offline', () {
      expect(RootStatus.fromWire('watching'), RootStatus.watching);
      expect(RootStatus.fromWire('hibernating'), RootStatus.offline);
    });

    test('DocState falls back to active', () {
      expect(DocState.fromWire('tombstoned'), DocState.active);
    });

    test('ConflictPolicy falls back to rename (never overwrites by accident)', () {
      expect(ConflictPolicy.fromWire('skip'), ConflictPolicy.skip);
      expect(ConflictPolicy.fromWire('replace-everything'), ConflictPolicy.rename);
    });

    test('DeviceScope.tryParse ignores unknown scopes', () {
      expect(DeviceScope.tryParse('delete'), DeviceScope.delete);
      expect(DeviceScope.tryParse('admin'), isNull);
    });
  });

  test('Root.acceptsUploads requires visibility, writability and the switch', () {
    Root root({bool visible = true, bool writable = true, bool target = true}) => Root(
      id: const RootId(1),
      path: r'D:\Docs',
      name: 'Docs',
      remoteVisible: visible,
      remoteWritable: writable,
      uploadTarget: target,
    );

    expect(root().acceptsUploads, isTrue);
    expect(root(visible: false).acceptsUploads, isFalse);
    expect(root(writable: false).acceptsUploads, isFalse);
    expect(root(target: false).acceptsUploads, isFalse);
  });

  test('Root.copyWith null-clearing works for nullable fields', () {
    const root = Root(
      id: RootId(2),
      path: r'D:\Docs',
      name: 'Docs',
      color: 0xFF112233,
      maxDepth: 3,
    );
    expect(root.copyWith().color, 0xFF112233);
    expect(root.copyWith(color: () => null).color, isNull);
    expect(root.copyWith(maxDepth: () => null).maxDepth, isNull);
    expect(root.copyWith(maxDepth: () => 5).maxDepth, 5);
  });
}
