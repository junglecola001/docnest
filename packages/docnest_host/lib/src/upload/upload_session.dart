import 'package:docnest_core/docnest_core.dart';

/// Default number of bytes the host asks for per chunk: 8 MiB (plan §3.5).
const int defaultUploadChunkSize = 8 * 1024 * 1024;

/// How long an upload session survives without receiving a chunk.
const Duration defaultUploadTtl = Duration(hours: 24);

/// Immutable description of one resumable upload.
///
/// The session is the single source of truth for the resume offset: [offset] is
/// only advanced after the corresponding bytes have been flushed to the sink,
/// so a host restart can trust it. Mutations go through [copyWith] and are
/// persisted by the registry.
final class UploadSession {
  /// Creates a session; the registry supplies every value.
  const UploadSession({
    required this.uploadId,
    required this.deviceId,
    required this.rootId,
    required this.dir,
    required this.fileName,
    required this.size,
    required this.modifiedAt,
    required this.createdAt,
    required this.expiresAt,
    required this.state,
    required this.stagingPath,
    this.offset = 0,
    this.onConflict = ConflictPolicy.rename,
    this.chunkSize = defaultUploadChunkSize,
  });

  /// Opaque host-generated identifier (`u_…`).
  final String uploadId;

  /// Device that owns the upload; other devices must not touch it.
  final String deviceId;

  /// Whitelisted root the file lands in.
  final RootId rootId;

  /// Destination directory relative to the root.
  final String dir;

  /// Client's desired file name, before conflict resolution.
  final String fileName;

  /// Total byte count declared when the session was created.
  final int size;

  /// Bytes already durably stored, and the offset the next chunk must use.
  final int offset;

  /// What to do when a file with [fileName] already exists at completion.
  final ConflictPolicy onConflict;

  /// Original modification time, restored after the move so the PC shows the
  /// same timestamp as the phone.
  final DateTime modifiedAt;

  /// When the session was created.
  final DateTime createdAt;

  /// When an idle session becomes [UploadState.expired]; refreshed on activity.
  final DateTime expiresAt;

  /// Current lifecycle state.
  final UploadState state;

  /// Absolute path of the `.part` file inside the target root's staging folder.
  ///
  /// It lives on the same volume as the target, which is what makes the final
  /// rename atomic.
  final String stagingPath;

  /// Bytes the host wants per request, used by the client's send loop.
  final int chunkSize;

  /// Whether the session has outlived [expiresAt] at [now].
  ///
  /// Expiry is inclusive: at [expiresAt] the session is already gone, matching
  /// the header the host handed out when it created the session.
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Returns a copy with the changed fields; everything else is shared.
  UploadSession copyWith({int? offset, UploadState? state, DateTime? expiresAt, String? fileName}) {
    return UploadSession(
      uploadId: uploadId,
      deviceId: deviceId,
      rootId: rootId,
      dir: dir,
      fileName: fileName ?? this.fileName,
      size: size,
      offset: offset ?? this.offset,
      onConflict: onConflict,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      state: state ?? this.state,
      stagingPath: stagingPath,
      chunkSize: chunkSize,
    );
  }

  /// Rejects a chunk that must not be appended to this session.
  ///
  /// Order matters: a closed session is refused before the offset check, so a
  /// client retrying after `complete` or `cancel` cannot slip bytes in. An
  /// expired session is refused before the offset check too, so the client is
  /// told to start over instead of silently succeeding against a `.part` that
  /// the sweep is about to delete.
  ///
  /// [now] defaults to wall-clock time; the registry passes its injected clock.
  void validateChunk(int offset, List<int> data, {DateTime? now}) {
    if (state != UploadState.open) {
      throw InvalidRequestException(
        message: 'Upload session is not open',
        details: {'uploadId': uploadId, 'state': state.name},
      );
    }
    if (isExpired(now ?? DateTime.now())) {
      throw UploadExpiredException(uploadId: uploadId);
    }
    if (offset != this.offset) {
      throw UploadOffsetMismatchException(expected: this.offset);
    }
    if (offset + data.length > size) {
      throw InvalidRequestException(
        message: 'Chunk exceeds the declared upload size',
        details: {'size': size, 'offset': offset, 'chunkLength': data.length},
      );
    }
  }
}
