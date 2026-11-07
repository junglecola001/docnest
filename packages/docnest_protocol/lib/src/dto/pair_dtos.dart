import 'package:docnest_core/docnest_core.dart';

import '../json.dart';

/// Body of `POST /api/v1/pair`.
///
/// The host only accepts this inside the 5-minute pairing window opened by the
/// user, and the one-time [code] may be guessed at most 5 times.
class PairRequestDto {
  const PairRequestDto({
    required this.code,
    required this.deviceName,
    required this.platform,
    required this.model,
    required this.clientProtocol,
    this.compareCode,
  });

  factory PairRequestDto.fromJson(Map<String, Object?> json) {
    return PairRequestDto(
      code: jsonString(json, 'code'),
      deviceName: jsonString(json, 'deviceName'),
      platform: jsonString(json, 'platform'),
      model: jsonString(json, 'model'),
      clientProtocol: jsonInt(json, 'clientProtocol'),
      compareCode: jsonStringOrNull(json, 'compareCode'),
    );
  }

  /// One-time pairing code from the QR payload.
  final String code;

  final String deviceName;
  final String platform;
  final String model;

  /// Protocol version the client speaks, so the host can refuse early.
  final int clientProtocol;

  /// Six digits shown on both screens for manual (no-camera) pairing.
  final String? compareCode;

  Map<String, Object?> toJson() => {
    'code': code,
    'deviceName': deviceName,
    'platform': platform,
    'model': model,
    'clientProtocol': clientProtocol,
    if (compareCode != null) 'compareCode': compareCode,
  };
}

/// Response of a successful `POST /api/v1/pair`.
class PairResponseDto {
  const PairResponseDto({
    required this.deviceId,
    required this.token,
    required this.hostId,
    required this.hostName,
    required this.protocolVersion,
    required this.scopes,
  });

  factory PairResponseDto.fromJson(Map<String, Object?> json) {
    return PairResponseDto(
      deviceId: jsonString(json, 'deviceId'),
      token: jsonString(json, 'token'),
      hostId: jsonString(json, 'hostId'),
      hostName: jsonString(json, 'hostName'),
      protocolVersion: jsonInt(json, 'protocolVersion'),
      scopes: {for (final wire in jsonStringList(json, 'scopes')) ?DeviceScope.tryParse(wire)},
    );
  }

  final String deviceId;

  /// 256-bit random token. Stored in the Android Keystore on the client and
  /// only as a hash on the host.
  final String token;

  final String hostId;
  final String hostName;
  final int protocolVersion;
  final Set<DeviceScope> scopes;

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'token': token,
    'hostId': hostId,
    'hostName': hostName,
    'protocolVersion': protocolVersion,
    'scopes': scopes.map((s) => s.wire).toList(growable: false),
  };
}
