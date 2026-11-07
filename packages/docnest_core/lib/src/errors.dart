/// Error codes shared by the host API, the client and the UI.
///
/// The enum lives in `docnest_core` rather than `docnest_protocol` so that
/// [AppException] can carry a code without the domain layer depending on the
/// wire layer; the wire strings themselves are what the protocol package
/// serialises. See ADR 0002.
enum DocNestErrorCode {
  unauthorized('UNAUTHORIZED'),
  tokenRevoked('TOKEN_REVOKED'),
  forbiddenScope('FORBIDDEN_SCOPE'),
  rootNotFound('ROOT_NOT_FOUND'),
  rootOffline('ROOT_OFFLINE'),
  rootReadOnly('ROOT_READ_ONLY'),
  pathOutsideRoot('PATH_OUTSIDE_ROOT'),
  invalidName('INVALID_NAME'),
  nameConflict('NAME_CONFLICT'),
  notFound('NOT_FOUND'),
  fileLocked('FILE_LOCKED'),
  insufficientSpace('INSUFFICIENT_SPACE'),
  uploadOffsetMismatch('UPLOAD_OFFSET_MISMATCH'),
  uploadExpired('UPLOAD_EXPIRED'),
  checksumMismatch('CHECKSUM_MISMATCH'),
  previewUnavailable('PREVIEW_UNAVAILABLE'),
  rateLimited('RATE_LIMITED'),
  protocolUnsupported('PROTOCOL_UNSUPPORTED'),
  invalidRequest('INVALID_REQUEST'),
  internal('INTERNAL');

  const DocNestErrorCode(this.wire);

  /// SCREAMING_SNAKE value used on the wire.
  final String wire;

  /// Parses [wire]; returns `null` for codes this build does not know, so a
  /// newer host degrades to a generic error instead of crashing.
  static DocNestErrorCode? tryParse(String? wire) {
    if (wire == null) return null;
    for (final code in values) {
      if (code.wire == wire) return code;
    }
    return null;
  }
}

/// Base type for every expected failure in DocNest.
///
/// Sealed so that UI code can switch exhaustively when it needs specific copy;
/// unexpected errors are wrapped in [UnknownException] with a full stack trace
/// kept for the log but not shown to the user.
sealed class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
    this.cause,
    this.stackTrace,
  });

  /// Machine-readable code, mirrored on the wire.
  final DocNestErrorCode code;

  /// Developer-facing English message. UI copy comes from `messageOf`.
  final String message;

  /// Extra context, safe to log.
  final Map<String, Object?> details;

  /// Underlying error, if any.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() => '${runtimeType.toString()}(${code.wire}): $message';
}

/// Request lacks a valid token.
final class UnauthorizedException extends AppException {
  const UnauthorizedException({super.message = 'Authentication required'})
    : super(code: DocNestErrorCode.unauthorized);
}

/// Token was revoked on the host; the device must pair again.
final class TokenRevokedException extends AppException {
  const TokenRevokedException({super.message = 'Device token revoked'})
    : super(code: DocNestErrorCode.tokenRevoked);
}

/// Device permission or root switch does not allow this action.
final class ForbiddenScopeException extends AppException {
  const ForbiddenScopeException({required super.message, super.details})
    : super(code: DocNestErrorCode.forbiddenScope);
}

/// The root id is unknown on the host.
final class RootNotFoundException extends AppException {
  RootNotFoundException({required int rootId})
    : super(
        code: DocNestErrorCode.rootNotFound,
        message: 'Root not found',
        details: {'rootId': rootId},
      );
}

/// The root is offline (drive unplugged, share gone).
final class RootOfflineException extends AppException {
  RootOfflineException({required int rootId})
    : super(
        code: DocNestErrorCode.rootOffline,
        message: 'Root is offline',
        details: {'rootId': rootId},
      );
}

/// The root is configured read-only.
final class ReadOnlyException extends AppException {
  const ReadOnlyException({super.message = 'Root is read-only', super.details})
    : super(code: DocNestErrorCode.rootReadOnly);
}

/// A resolved path escaped its root, or the input was not a relative path.
final class PathOutsideRootException extends AppException {
  const PathOutsideRootException({super.message = 'Path is outside the root', super.details})
    : super(code: DocNestErrorCode.pathOutsideRoot);
}

/// A file or folder name is not representable on Windows.
final class InvalidNameException extends AppException {
  const InvalidNameException({required super.message, super.details})
    : super(code: DocNestErrorCode.invalidName);
}

/// A target name exists and the caller asked not to overwrite.
final class NameConflictException extends AppException {
  NameConflictException({required String name})
    : super(
        code: DocNestErrorCode.nameConflict,
        message: 'Name already exists',
        details: {'name': name},
      );
}

/// Document, folder, tag or upload session not found.
final class NotFoundException extends AppException {
  const NotFoundException({super.message = 'Not found', super.details})
    : super(code: DocNestErrorCode.notFound);
}

/// Another process holds the file open.
final class FileLockedException extends AppException {
  const FileLockedException({super.message = 'File is locked by another program'})
    : super(code: DocNestErrorCode.fileLocked);
}

/// Not enough free space on the target volume.
final class InsufficientSpaceException extends AppException {
  InsufficientSpaceException({required int requiredBytes, required int availableBytes})
    : super(
        code: DocNestErrorCode.insufficientSpace,
        message: 'Not enough free space',
        details: {'requiredBytes': requiredBytes, 'availableBytes': availableBytes},
      );
}

/// A chunk arrived at the wrong offset.
final class UploadOffsetMismatchException extends AppException {
  UploadOffsetMismatchException({required int expected})
    : super(
        code: DocNestErrorCode.uploadOffsetMismatch,
        message: 'Upload offset mismatch',
        details: {'expected': expected},
      );
}

/// The upload session timed out and was cleaned up.
final class UploadExpiredException extends AppException {
  UploadExpiredException({required String uploadId})
    : super(
        code: DocNestErrorCode.uploadExpired,
        message: 'Upload session expired',
        details: {'uploadId': uploadId},
      );
}

/// A chunk or the whole file failed its hash check.
final class ChecksumMismatchException extends AppException {
  const ChecksumMismatchException({super.message = 'Checksum mismatch', super.details})
    : super(code: DocNestErrorCode.checksumMismatch);
}

/// Preview cannot be produced (encrypted PDF, unsupported format, …).
final class PreviewUnavailableException extends AppException {
  const PreviewUnavailableException({required String reason})
    : super(code: DocNestErrorCode.previewUnavailable, message: reason);
}

/// Too many requests; back off.
final class RateLimitedException extends AppException {
  const RateLimitedException() : super(code: DocNestErrorCode.rateLimited, message: 'Rate limited');
}

/// The two ends do not speak a compatible protocol version.
final class IncompatibleException extends AppException {
  const IncompatibleException({required super.message, super.details})
    : super(code: DocNestErrorCode.protocolUnsupported);
}

/// Malformed request: bad JSON, bad field types, missing required field.
final class InvalidRequestException extends AppException {
  const InvalidRequestException({required super.message, super.details})
    : super(code: DocNestErrorCode.invalidRequest);
}

/// Transport-level failure on the client (DNS, TLS, socket, timeout).
final class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network error',
    this.isCertificateMismatch = false,
    super.cause,
    super.stackTrace,
  }) : super(code: DocNestErrorCode.internal);

  /// Set when the presented certificate does not match the pinned fingerprint.
  final bool isCertificateMismatch;
}

/// Anything we did not anticipate. The UI shows an error id, the log has the rest.
final class UnknownException extends AppException {
  const UnknownException({super.message = 'Unexpected error', super.cause, super.stackTrace})
    : super(code: DocNestErrorCode.internal);
}

/// Maps a wire code to a concrete exception type.
///
/// [details] are the JSON details from the host; [message] is the host's
/// message, kept for logs only.
AppException appExceptionFromCode(
  String? wireCode, {
  String? message,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  final code = DocNestErrorCode.tryParse(wireCode);
  final text = message ?? code?.wire ?? 'Unexpected error';
  switch (code) {
    case DocNestErrorCode.unauthorized:
      return UnauthorizedException(message: text);
    case DocNestErrorCode.tokenRevoked:
      return TokenRevokedException(message: text);
    case DocNestErrorCode.forbiddenScope:
      return ForbiddenScopeException(message: text, details: details);
    case DocNestErrorCode.rootNotFound:
      return RootNotFoundException(rootId: _int(details['rootId']));
    case DocNestErrorCode.rootOffline:
      return RootOfflineException(rootId: _int(details['rootId']));
    case DocNestErrorCode.rootReadOnly:
      return ReadOnlyException(message: text, details: details);
    case DocNestErrorCode.pathOutsideRoot:
      return PathOutsideRootException(message: text, details: details);
    case DocNestErrorCode.invalidName:
      return InvalidNameException(message: text, details: details);
    case DocNestErrorCode.nameConflict:
      return NameConflictException(name: details['name'] as String? ?? '');
    case DocNestErrorCode.notFound:
      return NotFoundException(message: text, details: details);
    case DocNestErrorCode.fileLocked:
      return FileLockedException(message: text);
    case DocNestErrorCode.insufficientSpace:
      return InsufficientSpaceException(
        requiredBytes: _int(details['requiredBytes']),
        availableBytes: _int(details['availableBytes']),
      );
    case DocNestErrorCode.uploadOffsetMismatch:
      return UploadOffsetMismatchException(expected: _int(details['expected']));
    case DocNestErrorCode.uploadExpired:
      return UploadExpiredException(uploadId: details['uploadId'] as String? ?? '');
    case DocNestErrorCode.checksumMismatch:
      return ChecksumMismatchException(message: text, details: details);
    case DocNestErrorCode.previewUnavailable:
      return PreviewUnavailableException(reason: text);
    case DocNestErrorCode.rateLimited:
      return const RateLimitedException();
    case DocNestErrorCode.protocolUnsupported:
      return IncompatibleException(message: text, details: details);
    case DocNestErrorCode.invalidRequest:
      return InvalidRequestException(message: text, details: details);
    case DocNestErrorCode.internal:
    case null:
      return UnknownException(message: text);
  }
}

/// Reads an integer detail without throwing on a malformed payload.
int _int(Object? value) => value is int ? value : 0;
