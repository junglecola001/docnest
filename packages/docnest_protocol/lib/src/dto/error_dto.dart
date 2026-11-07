import 'package:docnest_core/docnest_core.dart';

import '../json.dart';

/// Error body shared by every failing endpoint.
///
/// ```json
/// { "error": { "code": "PATH_OUTSIDE_ROOT", "message": "…", "details": { } } }
/// ```
class ApiErrorDto {
  const ApiErrorDto({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  factory ApiErrorDto.fromJson(Map<String, Object?> json) {
    final error = jsonObject(json['error'], context: 'error');
    final details = error['details'];
    return ApiErrorDto(
      code: jsonString(error, 'code'),
      message: jsonString(error, 'message'),
      details: details == null ? const {} : jsonObject(details, context: 'details'),
    );
  }

  /// Wraps an exception for sending to a client.
  factory ApiErrorDto.fromException(AppException error) {
    return ApiErrorDto(code: error.code.wire, message: error.message, details: error.details);
  }

  /// Wire code, e.g. `PATH_OUTSIDE_ROOT`.
  final String code;

  final String message;
  final Map<String, Object?> details;

  /// Converts to the client-side exception type with the same meaning.
  AppException toException() => appExceptionFromCode(code, message: message, details: details);

  Map<String, Object?> toJson() => {
    'error': {'code': code, 'message': message, 'details': details},
  };
}
