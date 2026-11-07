import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/docnest_host.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Fixed time origin so expiry is deterministic.
final DateTime _start = DateTime.utc(2026, 1, 1, 9);

/// Records [Mover] calls and optionally performs the rename, so tests can see
/// exactly what the registry asked for and whether it asked at all.
class RecordingMover {
  RecordingMover({this.replace = false});

  /// Whether an existing destination is removed first, mimicking the trash move
  /// the overwrite policy performs in production.
  final bool replace;

  /// Every `(stagingPath, finalPath)` pair, in order.
  final List<(String, String)> calls = <(String, String)>[];

  /// [Mover] implementation.
  Future<void> call(String stagingPath, String finalPath) async {
    calls.add((stagingPath, finalPath));
    final destination = File(finalPath);
    if (replace && await destination.exists()) {
      await destination.delete();
    }
    await File(stagingPath).rename(finalPath);
  }
}

void main() {
  late Directory tempDir;
  late DateTime now;
  late RecordingMover mover;
  late UploadRegistry registry;
  late String stagingPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('docnest_upload_');
    now = _start;
    mover = RecordingMover();
    registry = UploadRegistry(mover: mover.call, clock: () => now);
    stagingPath = p.join(tempDir.path, '.docnest', 'staging', 'u_test.part');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<UploadSession> submit({
    required UploadRegistry target,
    required String path,
    int size = 12,
    String fileName = 'report.pdf',
    ConflictPolicy policy = ConflictPolicy.rename,
  }) {
    return target.create(
      deviceId: 'device-1',
      root: const RootId(1),
      dir: 'Inbox',
      fileName: fileName,
      size: size,
      modifiedAt: DateTime.utc(2025, 12, 31, 23),
      onConflict: policy,
      stagingPath: path,
    );
  }

  group('ChunkSink', () {
    test('MemoryChunkSink accepts only the current offset', () async {
      final sink = MemoryChunkSink();
      await sink.appendAt(0, <int>[1, 2]);

      await expectLater(sink.appendAt(1, <int>[9]), throwsA(isA<UploadOffsetMismatchException>()));

      expect(await sink.length(), 2);
      expect(sink.bytes, <int>[1, 2]);
    });

    test('FileChunkSink keeps bytes across instances and truncates on demand', () async {
      final path = p.join(tempDir.path, 'nested', 'deep', 'u.part');

      final first = FileChunkSink(path);
      await first.appendAt(0, <int>[1, 2, 3]);
      expect(await first.length(), 3);

      // A second instance models a restart: bytes written before must still be
      // there and the next writer must continue from them.
      final reopened = FileChunkSink(path);
      expect(await reopened.length(), 3);
      await reopened.appendAt(3, <int>[4, 5]);
      expect(await File(path).readAsBytes(), <int>[1, 2, 3, 4, 5]);

      // Dropping an unacknowledged tail must not extend the file with zeros.
      final truncated = FileChunkSink(path, truncateTo: 2);
      expect(await truncated.length(), 2);
      expect(await File(path).readAsBytes(), <int>[1, 2]);
    });

    test('FileChunkSink delete removes the staging file', () async {
      final sink = FileChunkSink(stagingPath);
      await sink.appendAt(0, <int>[7]);
      await sink.delete();

      expect(await File(stagingPath).exists(), isFalse);
      expect(await sink.length(), 0);
    });
  });

  group('create', () {
    test('starts at offset zero with the default chunk size and TTL', () async {
      final session = await submit(target: registry, path: stagingPath);

      expect(session.offset, 0);
      expect(session.chunkSize, defaultUploadChunkSize);
      expect(defaultUploadChunkSize, 8 * 1024 * 1024);
      expect(session.expiresAt, _start.add(const Duration(hours: 24)));
      expect(session.state, UploadState.open);
      expect(session.rootId, const RootId(1));
      // The `.part` is materialised eagerly, so a broken staging folder fails
      // here instead of on the first chunk.
      expect(await File(stagingPath).exists(), isTrue);
      expect((await registry.status(session.uploadId)).offset, 0);
    });

    test('rejects an empty file name', () async {
      await expectLater(
        submit(target: registry, path: stagingPath, fileName: ''),
        throwsA(isA<InvalidRequestException>()),
      );
    });
  });

  group('append', () {
    test('sequential chunks advance the offset and land on disk', () async {
      final session = await submit(target: registry, path: stagingPath, size: 5);

      expect(await registry.append(session.uploadId, 0, <int>[1, 2]), 2);
      expect(await registry.append(session.uploadId, 2, <int>[3, 4, 5]), 5);

      expect((await registry.status(session.uploadId)).offset, 5);
      expect(await File(stagingPath).readAsBytes(), <int>[1, 2, 3, 4, 5]);
    });

    test('a chunk at the wrong offset is rejected and writes nothing', () async {
      final session = await submit(target: registry, path: stagingPath, size: 5);
      await registry.append(session.uploadId, 0, <int>[1, 2]);

      await expectLater(
        registry.append(session.uploadId, 1, <int>[9]),
        throwsA(
          isA<UploadOffsetMismatchException>().having(
            (UploadOffsetMismatchException e) => e.details['expected'],
            'expected offset',
            2,
          ),
        ),
      );

      expect((await registry.status(session.uploadId)).offset, 2);
      expect(await File(stagingPath).readAsBytes(), <int>[1, 2]);
    });

    test('a chunk that overruns the declared size is rejected', () async {
      final session = await submit(target: registry, path: stagingPath, size: 4);

      await expectLater(
        registry.append(session.uploadId, 0, <int>[1, 2, 3, 4, 5]),
        throwsA(isA<InvalidRequestException>()),
      );

      expect((await registry.status(session.uploadId)).offset, 0);
    });

    test('a chunk hash mismatch leaves the offset untouched', () async {
      final session = await submit(target: registry, path: stagingPath, size: 4);
      final firstChunk = <int>[1, 2];
      final secondChunk = <int>[3, 4];

      expect(
        await registry.append(
          session.uploadId,
          0,
          firstChunk,
          chunkSha256: sha256.convert(firstChunk).toString(),
        ),
        2,
      );

      await expectLater(
        registry.append(session.uploadId, 2, secondChunk, chunkSha256: 'deadbeef'),
        throwsA(isA<ChecksumMismatchException>()),
      );
      expect((await registry.status(session.uploadId)).offset, 2);

      // Retrying with the right digest must still work from the same offset.
      expect(
        await registry.append(
          session.uploadId,
          2,
          secondChunk,
          chunkSha256: sha256.convert(secondChunk).toString().toUpperCase(),
        ),
        4,
      );
      expect(await File(stagingPath).readAsBytes(), <int>[1, 2, 3, 4]);
    });

    test('resume after a host restart keeps bytes and offset', () async {
      final store = InMemoryUploadSessionStore();
      final first = UploadRegistry(mover: mover.call, store: store, clock: () => now);
      final session = await submit(target: first, path: stagingPath, size: 4);
      await first.append(session.uploadId, 0, <int>[1, 2]);

      final second = UploadRegistry(mover: mover.call, store: store, clock: () => now);

      expect((await second.status(session.uploadId)).offset, 2);
      expect(await second.append(session.uploadId, 2, <int>[3, 4]), 4);
      expect(await File(stagingPath).readAsBytes(), <int>[1, 2, 3, 4]);
    });

    test('a memory sink works through the same contract', () async {
      final sink = MemoryChunkSink();
      final memoryRegistry = UploadRegistry(
        mover: mover.call,
        sinkFactory: (_) => sink,
        clock: () => now,
      );
      final session = await submit(target: memoryRegistry, path: 'mem://u1', size: 3);

      expect(await memoryRegistry.append(session.uploadId, 0, <int>[1, 2, 3]), 3);
      expect(sink.bytes, <int>[1, 2, 3]);
    });

    test('an unknown session is not found', () async {
      await expectLater(
        registry.append('u_missing', 0, <int>[1]),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('expiry', () {
    test('an expired session refuses chunks and the sweep deletes the .part', () async {
      final session = await submit(target: registry, path: stagingPath, size: 2);
      await registry.append(session.uploadId, 0, <int>[1, 2]);

      now = _start.add(const Duration(hours: 25));

      await expectLater(registry.status(session.uploadId), throwsA(isA<UploadExpiredException>()));
      await expectLater(
        registry.append(session.uploadId, 2, <int>[3]),
        throwsA(isA<UploadExpiredException>()),
      );
      expect(await File(stagingPath).exists(), isTrue);

      expect(await registry.expireStale(now), 1);
      expect(await File(stagingPath).exists(), isFalse);
      // The row survives the sweep as expired, so a late probe gets a clear
      // "expired" rather than "not found".
      await expectLater(registry.status(session.uploadId), throwsA(isA<UploadExpiredException>()));
      // Sweeping twice is harmless.
      expect(await registry.expireStale(now), 0);
    });
  });

  group('complete', () {
    test('skip keeps the existing file and never calls the mover', () async {
      final target = File(p.join(tempDir.path, 'report.pdf'))..writeAsStringSync('old');
      final session = await submit(
        target: registry,
        path: stagingPath,
        size: 3,
        policy: ConflictPolicy.skip,
      );
      await registry.append(session.uploadId, 0, <int>[1, 2, 3]);

      final completion = await registry.complete(
        session.uploadId,
        existingNames: <String>{'report.pdf'},
      );
      expect(completion.skipped, isTrue);
      expect(completion.finalName, 'report.pdf');

      await completion.commit(p.join(tempDir.path, 'report.pdf'));
      expect(mover.calls, isEmpty);
      expect(target.readAsStringSync(), 'old');
      expect((await registry.status(session.uploadId)).state, UploadState.completed);
    });

    test('rename picks a free name and the mover publishes the bytes', () async {
      final session = await submit(
        target: registry,
        path: stagingPath,
        size: 3,
        policy: ConflictPolicy.rename,
      );
      await registry.append(session.uploadId, 0, <int>[1, 2, 3]);

      final completion = await registry.complete(
        session.uploadId,
        existingNames: <String>{'report.pdf'},
      );
      expect(completion.skipped, isFalse);
      expect(completion.finalName, 'report (1).pdf');

      final finalPath = p.join(tempDir.path, 'report (1).pdf');
      await completion.commit(finalPath);

      expect(mover.calls, <(String, String)>[(stagingPath, finalPath)]);
      expect(await File(finalPath).readAsBytes(), <int>[1, 2, 3]);
      expect(await File(stagingPath).exists(), isFalse);
      expect((await registry.status(session.uploadId)).state, UploadState.completed);
      expect(completion.isCommitted, isTrue);

      // Committing twice must not move the file again.
      await completion.commit(finalPath);
      expect(mover.calls, hasLength(1));
    });

    test('overwrite keeps the desired name and replaces the target', () async {
      final target = File(p.join(tempDir.path, 'report.pdf'))..writeAsStringSync('old');
      final overwriteMover = RecordingMover(replace: true);
      final overwriteRegistry = UploadRegistry(mover: overwriteMover.call, clock: () => now);
      final session = await submit(
        target: overwriteRegistry,
        path: stagingPath,
        size: 3,
        policy: ConflictPolicy.overwrite,
      );
      await overwriteRegistry.append(session.uploadId, 0, <int>[1, 2, 3]);

      final completion = await overwriteRegistry.complete(
        session.uploadId,
        existingNames: <String>{'report.pdf'},
      );
      expect(completion.skipped, isFalse);
      expect(completion.finalName, 'report.pdf');

      await completion.commit(p.join(tempDir.path, 'report.pdf'));
      expect(await target.readAsBytes(), <int>[1, 2, 3]);
    });

    test('an incomplete upload is rejected', () async {
      final session = await submit(target: registry, path: stagingPath, size: 4);
      await registry.append(session.uploadId, 0, <int>[1, 2]);

      await expectLater(
        registry.complete(session.uploadId, existingNames: <String>{}),
        throwsA(isA<InvalidRequestException>()),
      );
    });

    test('the whole-file hash is verified when supplied', () async {
      final session = await submit(target: registry, path: stagingPath, size: 3);
      await registry.append(session.uploadId, 0, <int>[1, 2, 3]);

      await expectLater(
        registry.complete(
          session.uploadId,
          existingNames: <String>{},
          fileSha256: 'not-the-digest',
        ),
        throwsA(isA<ChecksumMismatchException>()),
      );

      final completion = await registry.complete(
        session.uploadId,
        existingNames: <String>{},
        fileSha256: sha256.convert(<int>[1, 2, 3]).toString(),
      );
      expect(completion.skipped, isFalse);
      expect(completion.finalName, 'report.pdf');
    });

    test('a session that is already completed cannot be completed again', () async {
      final session = await submit(
        target: registry,
        path: stagingPath,
        size: 2,
        policy: ConflictPolicy.skip,
      );
      await registry.append(session.uploadId, 0, <int>[1, 2]);
      await registry.complete(session.uploadId, existingNames: <String>{'report.pdf'});

      await expectLater(
        registry.complete(session.uploadId, existingNames: <String>{'report.pdf'}),
        throwsA(isA<InvalidRequestException>()),
      );
    });
  });

  group('cancel', () {
    test('deletes the staging file and marks the session cancelled', () async {
      final session = await submit(target: registry, path: stagingPath, size: 3);
      await registry.append(session.uploadId, 0, <int>[1, 2, 3]);

      await registry.cancel(session.uploadId);

      expect(await File(stagingPath).exists(), isFalse);
      expect((await registry.status(session.uploadId)).state, UploadState.cancelled);
      await expectLater(
        registry.append(session.uploadId, 3, <int>[4]),
        throwsA(isA<InvalidRequestException>()),
      );
    });
  });
}
