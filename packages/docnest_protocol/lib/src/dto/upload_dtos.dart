import 'package:docnest_core/docnest_core.dart';

import '../json.dart';

/// State of a resumable upload session lives in `docnest_core` so the host
/// state machine and the wire DTOs cannot drift apart.

/// Body of `POST /api/v1/uploads`.
class UploadInitRequestDto {
  const UploadInitRequestDto({
    required this.rootId,
    required this.dir,
    required this.fileName,
    required this.size,
    required this.modifiedAt,
    this.onConflict = ConflictPolicy.rename,
  });

  factory UploadInitRequestDto.fromJson(Map<String, Object?> json) {
    return UploadInitRequestDto(
      rootId: jsonInt(json, 'rootId'),
      dir: jsonString(json, 'dir'),
      fileName: jsonString(json, 'fileName'),
      size: jsonInt(json, 'size'),
      modifiedAt: jsonDateTime(json, 'modifiedAt'),
      onConflict: ConflictPolicy.fromWire(jsonStringOrNull(json, 'onConflict')),
    );
  }

  final int rootId;

  /// Destination folder relative to the root, `/`-separated, `''` for the root.
  final String dir;

  final String fileName;

  /// Total size in bytes, used for the free-space check.
  final int size;

  /// Original modification time, restored after the atomic rename.
  final DateTime modifiedAt;

  final ConflictPolicy onConflict;

  Map<String, Object?> toJson() => {
    'rootId': rootId,
    'dir': dir,
    'fileName': fileName,
    'size': size,
    'modifiedAt': dateTimeToWire(modifiedAt),
    'onConflict': onConflict.wire,
  };
}

/// Response of `POST /api/v1/uploads` (201).
class UploadInitResponseDto {
  const UploadInitResponseDto({
    required this.uploadId,
    required this.chunkSize,
    required this.offset,
    required this.expiresAt,
  });

  factory UploadInitResponseDto.fromJson(Map<String, Object?> json) {
    return UploadInitResponseDto(
      uploadId: jsonString(json, 'uploadId'),
      chunkSize: jsonInt(json, 'chunkSize'),
      offset: jsonInt(json, 'offset'),
      expiresAt: jsonDateTime(json, 'expiresAt'),
    );
  }

  final String uploadId;

  /// Chunk size the host asks the client to use, in bytes.
  final int chunkSize;

  /// Already-received offset; non-zero when resuming an existing session.
  final int offset;

  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
    'uploadId': uploadId,
    'chunkSize': chunkSize,
    'offset': offset,
    'expiresAt': dateTimeToWire(expiresAt),
  };
}

/// Response of `PUT /api/v1/uploads/{id}`.
class UploadChunkResponseDto {
  const UploadChunkResponseDto({required this.offset});

  factory UploadChunkResponseDto.fromJson(Map<String, Object?> json) =>
      UploadChunkResponseDto(offset: jsonInt(json, 'offset'));

  /// Total bytes accepted so far.
  final int offset;

  Map<String, Object?> toJson() => {'offset': offset};
}

/// Response of `HEAD /api/v1/uploads/{id}`.
class UploadStatusDto {
  const UploadStatusDto({
    required this.uploadId,
    required this.offset,
    required this.size,
    required this.state,
    this.expiresAt,
  });

  factory UploadStatusDto.fromJson(Map<String, Object?> json) {
    return UploadStatusDto(
      uploadId: jsonString(json, 'uploadId'),
      offset: jsonInt(json, 'offset'),
      size: jsonInt(json, 'size'),
      state: UploadState.fromWire(jsonStringOrNull(json, 'state')),
      expiresAt: jsonDateTimeOrNull(json, 'expiresAt'),
    );
  }

  final String uploadId;
  final int offset;
  final int size;
  final UploadState state;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
    'uploadId': uploadId,
    'offset': offset,
    'size': size,
    'state': state.wire,
    if (expiresAt != null) 'expiresAt': dateTimeToWire(expiresAt!),
  };
}

/// Response of `POST /api/v1/uploads/{id}/complete`.
class UploadCompleteResponseDto {
  const UploadCompleteResponseDto({
    required this.docId,
    required this.finalName,
    required this.relPath,
    required this.skipped,
  });

  factory UploadCompleteResponseDto.fromJson(Map<String, Object?> json) {
    return UploadCompleteResponseDto(
      docId: jsonInt(json, 'docId'),
      finalName: jsonString(json, 'finalName'),
      relPath: jsonString(json, 'relPath'),
      skipped: jsonBool(json, 'skipped'),
    );
  }

  final int docId;

  /// Name actually used after conflict resolution.
  final String finalName;

  /// Path relative to the root, `/`-separated.
  final String relPath;

  /// True when `onConflict: skip` found an existing file and wrote nothing.
  final bool skipped;

  Map<String, Object?> toJson() => {
    'docId': docId,
    'finalName': finalName,
    'relPath': relPath,
    'skipped': skipped,
  };
}
