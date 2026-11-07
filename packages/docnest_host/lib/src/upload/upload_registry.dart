import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:docnest_core/docnest_core.dart';

import '../path/conflict_resolver.dart';
import 'chunk_sink.dart';
import 'upload_session.dart';

/// Returns the host's current time, injected so expiry is testable.
typedef Clock = DateTime Function();

/// Opens the [ChunkSink] that stores one staging path.
typedef ChunkSinkFactory = ChunkSink Function(String path);

/// Computes the lowercase hex SHA-256 digest of [bytes].
typedef Sha256 = String Function(List<int> bytes);

/// Atomically moves [stagingPath] to [finalPath].
///
/// The registry does not rename files itself: the move must happen on the same
/// volume as the target, and only the caller knows the absolute final path. It
/// is also the caller's job to overwrite (move the old file to the trash first)
/// and to restore the original modification time, per plan §3.5.
typedef Mover = Future<void> Function(String stagingPath, String finalPath);

/// Persistence for upload sessions.
///
/// Asynchronous so the host can back it with SQLite: an upload survives a host
/// restart only if the offset is really persisted (plan §3.5 item 4).
abstract interface class UploadSessionStore {
  /// Inserts or replaces [session].
  Future<void> save(UploadSession session);

  /// Returns the session for [uploadId], or `null` when it is unknown.
  Future<UploadSession?> load(String uploadId);

  /// Returns every stored session; used by the expiry sweep.
  Future<List<UploadSession>> loadAll();

  /// Drops [uploadId] entirely.
  Future<void> delete(String uploadId);
}

/// [UploadSessionStore] that keeps sessions in memory, for tests and dry runs.
final class InMemoryUploadSessionStore implements UploadSessionStore {
  final Map<String, UploadSession> _sessions = <String, UploadSession>{};

  @override
  Future<void> save(UploadSession session) async {
    _sessions[session.uploadId] = session;
  }

  @override
  Future<UploadSession?> load(String uploadId) async => _sessions[uploadId];

  @override
  Future<List<UploadSession>> loadAll() async => List<UploadSession>.of(_sessions.values);

  @override
  Future<void> delete(String uploadId) async {
    _sessions.remove(uploadId);
  }
}

/// Outcome of [UploadRegistry.complete].
///
/// [finalName] is the name the file would get under the session's conflict
/// policy. [skipped] means the target already exists and the client asked to
/// keep it, so there is nothing to write and [commit] is a no-op.
final class UploadCompletion {
  /// Creates a completion; only [UploadRegistry.complete] constructs these.
  UploadCompletion({
    required this.uploadId,
    required this.finalName,
    required this.skipped,
    Future<void> Function(String finalPath)? onCommit,
  }) : _onCommit = onCommit;

  /// Session this completion belongs to, for logging and metrics.
  final String uploadId;

  /// Name to use at the destination after conflict resolution.
  final String finalName;

  /// Whether the client chose to keep the existing file.
  final bool skipped;

  final Future<void> Function(String finalPath)? _onCommit;

  bool _committed = false;

  /// Whether [commit] has already published the staged bytes.
  bool get isCommitted => _committed;

  /// Publishes the staged bytes at [finalPath] through the injected [Mover].
  ///
  /// Does nothing when [skipped]; repeated calls are no-ops so a retried
  /// request cannot move the same file twice.
  Future<void> commit(String finalPath) async {
    if (skipped || _committed) return;
    final onCommit = _onCommit;
    if (onCommit == null) {
      throw StateError('Upload completion has no Mover configured');
    }
    await onCommit(finalPath);
    _committed = true;
  }
}

/// Resumable-upload state machine: sessions, offsets, verification and cleanup.
///
/// The layer is pure logic plus file writes; HTTP concerns (paths, headers,
/// authentication) belong to the transport that calls it. Chunks for one upload
/// MUST be appended sequentially: the registry does not serialise concurrent
/// appends, because the protocol sends them one at a time.
final class UploadRegistry {
  /// Creates a registry.
  ///
  /// [mover] performs the final atomic rename when the caller commits a
  /// completion. [store] defaults to an in-memory store, [sinkFactory] to
  /// [FileChunkSink], [clock] to wall clock time and [sha256] to a real
  /// SHA-256 implementation.
  UploadRegistry({
    required Mover mover,
    UploadSessionStore? store,
    ChunkSinkFactory? sinkFactory,
    Clock? clock,
    Sha256? sha256,
  }) : _mover = mover,
       _store = store ?? InMemoryUploadSessionStore(),
       _sinkFactory = sinkFactory ?? FileChunkSink.new,
       _now = clock ?? DateTime.now,
       _sha256 = sha256 ?? _defaultSha256;

  final Mover _mover;
  final UploadSessionStore _store;
  final ChunkSinkFactory _sinkFactory;
  final Clock _now;
  final Sha256 _sha256;

  /// Random component of upload ids; keeps two hosts from colliding.
  final Random _random = Random.secure();

  int _sequence = 0;

  /// Creates a session with offset `0` and an expiry of now + 24 hours.
  ///
  /// The staging file is materialised eagerly so a missing directory or a
  /// permission problem surfaces here, not on the first chunk. Anything already
  /// at [stagingPath] is discarded because the advertised offset is `0`.
  ///
  /// Throws [InvalidRequestException] for a negative [size], an empty
  /// [fileName] or [stagingPath], or a non-positive [chunkSize].
  Future<UploadSession> create({
    required String deviceId,
    required RootId root,
    required String dir,
    required String fileName,
    required int size,
    required DateTime modifiedAt,
    required ConflictPolicy onConflict,
    required String stagingPath,
    int chunkSize = defaultUploadChunkSize,
    DateTime? now,
  }) async {
    if (size < 0) {
      throw InvalidRequestException(message: 'size must not be negative', details: {'size': size});
    }
    if (fileName.isEmpty) {
      throw const InvalidRequestException(message: 'fileName must not be empty');
    }
    if (stagingPath.isEmpty) {
      throw const InvalidRequestException(message: 'stagingPath must not be empty');
    }
    if (chunkSize <= 0) {
      throw InvalidRequestException(
        message: 'chunkSize must be positive',
        details: {'chunkSize': chunkSize},
      );
    }

    final moment = now ?? _now();
    final session = UploadSession(
      uploadId: _newUploadId(),
      deviceId: deviceId,
      rootId: root,
      dir: dir,
      fileName: fileName,
      size: size,
      modifiedAt: modifiedAt,
      createdAt: moment,
      expiresAt: moment.add(defaultUploadTtl),
      onConflict: onConflict,
      stagingPath: stagingPath,
      chunkSize: chunkSize,
      state: UploadState.open,
    );

    final sink = _sinkFactory(stagingPath);
    final leftover = await sink.length();
    if (leftover > 0) {
      await sink.delete();
      // Recreate the empty file so the session always has its `.part`.
      await sink.length();
    }

    await _store.save(session);
    return session;
  }

  /// Appends one chunk and returns the new offset.
  ///
  /// [chunkSha256] is the client's digest of [data]; when present a mismatch is
  /// rejected with [ChecksumMismatchException] *before* anything is written, so
  /// the offset the client will retry from stays correct.
  ///
  /// Throws [UploadOffsetMismatchException] for a stale offset,
  /// [UploadExpiredException] past expiry, [InvalidRequestException] when the
  /// chunk overruns the declared size, and [NotFoundException] for an unknown
  /// session.
  Future<int> append(String uploadId, int offset, List<int> data, {String? chunkSha256}) async {
    final session = await _requireSession(uploadId);
    final moment = _now();
    session.validateChunk(offset, data, now: moment);

    if (chunkSha256 != null) {
      final actual = _sha256(data);
      if (!_digestMatches(actual, chunkSha256)) {
        throw ChecksumMismatchException(
          message: 'Chunk hash mismatch',
          details: {'uploadId': uploadId, 'offset': offset},
        );
      }
    }

    final sink = _sinkFactory(session.stagingPath);
    await sink.appendAt(offset, data);
    // Bytes reach disk before the offset does. The reverse order would let a
    // crash advertise bytes the file does not have, and the client would skip
    // them on resume.
    await sink.flush();

    final updated = session.copyWith(
      offset: offset + data.length,
      expiresAt: moment.add(defaultUploadTtl),
    );
    await _store.save(updated);
    return updated.offset;
  }

  /// Returns the session for [uploadId], for the client's resume probe.
  ///
  /// Throws [NotFoundException] when it is unknown and [UploadExpiredException]
  /// when it has expired, whether or not the sweep already ran.
  Future<UploadSession> status(String uploadId) async {
    final session = await _requireSession(uploadId);
    if (session.state == UploadState.expired ||
        (session.state == UploadState.open && session.isExpired(_now()))) {
      throw UploadExpiredException(uploadId: uploadId);
    }
    return session;
  }

  /// Deletes the staging file and marks [uploadId] cancelled.
  ///
  /// The session row is kept so a late `HEAD` can distinguish "cancelled" from
  /// "never existed"; only the bytes are gone.
  Future<void> cancel(String uploadId) async {
    final session = await _requireSession(uploadId);
    await _sinkFactory(session.stagingPath).delete();
    await _store.save(session.copyWith(state: UploadState.cancelled));
  }

  /// Resolves the final name and prepares the commit for [uploadId].
  ///
  /// The session is only marked completed once the caller calls
  /// [UploadCompletion.commit], except for the skip case where the target is
  /// already in place. Nothing at the destination is touched here; the caller
  /// supplies [existingNames] lowercased, as Windows compares names
  /// case-insensitively.
  ///
  /// Throws [InvalidRequestException] when the upload is incomplete or the
  /// session is not open, [UploadExpiredException] after expiry,
  /// [ChecksumMismatchException] when [fileSha256] does not match the staged
  /// bytes, and [NotFoundException] for an unknown session.
  Future<UploadCompletion> complete(
    String uploadId, {
    required Set<String> existingNames,
    String? fileSha256,
    DateTime? now,
  }) async {
    final moment = now ?? _now();
    final session = await _requireSession(uploadId);
    if (session.state != UploadState.open) {
      throw InvalidRequestException(
        message: 'Upload session is not open',
        details: {'uploadId': uploadId, 'state': session.state.name},
      );
    }
    if (session.isExpired(moment)) {
      throw UploadExpiredException(uploadId: uploadId);
    }

    final sink = _sinkFactory(session.stagingPath);
    final stagedLength = await sink.length();
    if (session.offset != session.size || stagedLength != session.size) {
      throw InvalidRequestException(
        message: 'Upload size mismatch',
        details: {'expected': session.size, 'offset': session.offset, 'staged': stagedLength},
      );
    }

    if (fileSha256 != null) {
      // Streamed from disk: hashing a multi-gigabyte upload into one list would
      // defeat the point of chunked transfer.
      final actual = await _hashFile(session.stagingPath);
      if (!_digestMatches(actual, fileSha256)) {
        throw ChecksumMismatchException(
          message: 'File hash mismatch',
          details: {'uploadId': uploadId},
        );
      }
    }

    final finalName = ConflictResolver.resolve(
      desiredName: session.fileName,
      existing: existingNames,
      policy: session.onConflict,
      now: moment,
    );

    if (finalName == null) {
      // The client chose to keep the existing file. The target is not touched;
      // the orphaned `.part` is removed by [expireStale] once the session ages
      // out, which keeps this call free of destination side effects.
      await _store.save(session.copyWith(state: UploadState.completed));
      return UploadCompletion(uploadId: uploadId, finalName: session.fileName, skipped: true);
    }

    return UploadCompletion(
      uploadId: uploadId,
      finalName: finalName,
      skipped: false,
      onCommit: (String finalPath) async {
        await _mover(session.stagingPath, finalPath);
        await _store.save(session.copyWith(state: UploadState.completed, fileName: finalName));
      },
    );
  }

  /// Deletes staging files of sessions that outlived their expiry.
  ///
  /// Returns how many open sessions were newly marked expired. Staging bytes of
  /// already-terminal sessions are swept as well: `skip` deliberately leaves
  /// them behind, and a crash between `cancel` and the delete can leave a file
  /// that no live session will ever resume.
  Future<int> expireStale(DateTime now) async {
    final sessions = await _store.loadAll();
    var expired = 0;
    for (final session in sessions) {
      if (!session.isExpired(now)) continue;
      await _sinkFactory(session.stagingPath).delete();
      if (session.state == UploadState.open) {
        await _store.save(session.copyWith(state: UploadState.expired));
        expired++;
      }
    }
    return expired;
  }

  /// Loads [uploadId] or fails the way the HTTP layer expects.
  Future<UploadSession> _requireSession(String uploadId) async {
    final session = await _store.load(uploadId);
    if (session == null) {
      throw NotFoundException(message: 'Upload session not found', details: {'uploadId': uploadId});
    }
    return session;
  }

  /// Opaque id: timestamp, a random salt and a per-process counter.
  ///
  /// The salt makes ids unique across host restarts, when the counter resets.
  String _newUploadId() {
    _sequence += 1;
    final stamp = _now().toUtc().microsecondsSinceEpoch.toRadixString(16);
    final salt = _random.nextInt(1 << 16).toRadixString(16).padLeft(4, '0');
    return 'u_$stamp$salt${_sequence.toRadixString(16)}';
  }

  static String _defaultSha256(List<int> bytes) => sha256.convert(bytes).toString();

  static bool _digestMatches(String actual, String expected) =>
      actual.trim().toLowerCase() == expected.trim().toLowerCase();

  /// SHA-256 of the whole staged file, computed in constant memory.
  static Future<String> _hashFile(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }
}
