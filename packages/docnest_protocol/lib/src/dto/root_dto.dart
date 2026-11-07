import 'package:docnest_core/docnest_core.dart';

import '../json.dart';

/// One whitelisted root as seen by a remote device.
///
/// Deliberately omits the absolute host path: phones address content by
/// `(rootId, relative path)` only.
class RootDto {
  const RootDto({
    required this.id,
    required this.name,
    required this.status,
    required this.docCount,
    this.color,
    this.writable = false,
    this.uploadTarget = false,
    this.scanProgress,
  });

  factory RootDto.fromJson(Map<String, Object?> json) {
    return RootDto(
      id: jsonInt(json, 'id'),
      name: jsonString(json, 'name'),
      status: RootStatus.fromWire(jsonStringOrNull(json, 'status')),
      docCount: jsonInt(json, 'docCount'),
      color: jsonIntOrNull(json, 'color'),
      writable: jsonBool(json, 'writable'),
      uploadTarget: jsonBool(json, 'uploadTarget'),
      scanProgress: jsonDoubleOrNull(json, 'scanProgress'),
    );
  }

  final int id;
  final String name;
  final RootStatus status;
  final int docCount;

  /// ARGB, or null for the theme default.
  final int? color;

  /// Remote writes are allowed on this root.
  final bool writable;

  /// This root may receive uploads.
  final bool uploadTarget;

  /// Scan progress in `[0, 1]` while [status] is [RootStatus.scanning].
  final double? scanProgress;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'status': status.wire,
    'docCount': docCount,
    if (color != null) 'color': color,
    'writable': writable,
    'uploadTarget': uploadTarget,
    if (scanProgress != null) 'scanProgress': scanProgress,
  };
}
