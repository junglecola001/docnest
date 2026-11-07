import '../json.dart';
import '../protocol_version.dart';

/// Response of `GET /api/v1/info`.
///
/// Unauthenticated: it must not leak paths, device names of peers, or tokens.
class HostInfoDto {
  const HostInfoDto({
    required this.hostId,
    required this.name,
    required this.appVersion,
    required this.protocolVersion,
    required this.minClientProtocol,
    required this.indexEpoch,
    this.capabilities = const <Capability>{},
  });

  factory HostInfoDto.fromJson(Map<String, Object?> json) {
    return HostInfoDto(
      hostId: jsonString(json, 'hostId'),
      name: jsonString(json, 'name'),
      appVersion: jsonString(json, 'appVersion'),
      protocolVersion: jsonInt(json, 'protocolVersion'),
      minClientProtocol: jsonInt(json, 'minClientProtocol'),
      indexEpoch: jsonInt(json, 'indexEpoch'),
      capabilities: Capability.parseAll(jsonStringList(json, 'capabilities')),
    );
  }

  final String hostId;
  final String name;
  final String appVersion;
  final int protocolVersion;
  final int minClientProtocol;

  /// Bumped by the host on every full reindex. Clients drop cached ids when it
  /// changes, because doc ids are not stable across a rebuild.
  final int indexEpoch;

  final Set<Capability> capabilities;

  bool supports(Capability capability) => capabilities.contains(capability);

  /// Whether this client can talk to the advertised host.
  bool get isCompatible => ProtocolVersion.isCompatible(protocolVersion);

  Map<String, Object?> toJson() => {
    'hostId': hostId,
    'name': name,
    'appVersion': appVersion,
    'protocolVersion': protocolVersion,
    'minClientProtocol': minClientProtocol,
    'indexEpoch': indexEpoch,
    'capabilities': capabilities.map((c) => c.wire).toList(growable: false),
  };
}
