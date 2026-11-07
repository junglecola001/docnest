/// The payload embedded in the pairing QR code.
///
/// ```text
/// docnest://pair?v=1&h=<hostId>&n=HOME-PC&a=192.168.1.8,10.0.0.5&p=53420&f=<sha256-base64url>&c=<code>
/// ```
///
/// The fingerprint is the whole point: the client pins it and therefore never
/// trusts a certificate it did not see in the QR code. See ADR 0004.
library;

class PairingLink {
  const PairingLink({
    required this.hostId,
    required this.hostName,
    required this.addresses,
    required this.port,
    required this.fingerprint,
    required this.code,
    this.version = currentVersion,
  });

  /// Parses a scanned or pasted link, throwing [FormatException] on any defect.
  factory PairingLink.parse(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != scheme || uri.host != action) {
      throw FormatException('Not a DocNest pairing link: $raw');
    }
    final params = uri.queryParameters;
    final version = int.tryParse(params['v'] ?? '');
    if (version == null) throw const FormatException('Pairing link is missing version');
    if (version != currentVersion) {
      throw FormatException('Unsupported pairing link version: $version');
    }
    final hostId = params['h'] ?? '';
    if (hostId.isEmpty) throw const FormatException('Pairing link is missing hostId');
    final port = int.tryParse(params['p'] ?? '');
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('Pairing link has an invalid port');
    }
    final fingerprint = params['f'] ?? '';
    if (!_isFingerprint(fingerprint)) {
      throw const FormatException('Pairing link has an invalid certificate fingerprint');
    }
    final code = params['c'] ?? '';
    if (code.isEmpty) throw const FormatException('Pairing link is missing the pairing code');
    final addresses = (params['a'] ?? '')
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList(growable: false);
    if (addresses.isEmpty) throw const FormatException('Pairing link has no addresses');
    return PairingLink(
      hostId: hostId,
      hostName: params['n'] ?? '',
      addresses: addresses,
      port: port,
      fingerprint: fingerprint,
      code: code,
    );
  }

  static const String scheme = 'docnest';
  static const String action = 'pair';
  static const int currentVersion = 1;

  /// Length of a base64url-encoded SHA-256 digest without padding.
  static const int _fingerprintLength = 43;

  final int version;
  final String hostId;
  final String hostName;

  /// Private (LAN) IPv4 addresses of the host, virtual adapters excluded.
  final List<String> addresses;

  final int port;

  /// Base64url (no padding) of the DER certificate's SHA-256.
  final String fingerprint;

  /// One-time pairing code, valid for the 5-minute window.
  final String code;

  static bool _isFingerprint(String value) {
    if (value.length != _fingerprintLength) return false;
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
  }

  /// True when this fingerprint is what a pinned client expects.
  bool matchesFingerprint(String candidate) => candidate == fingerprint;

  String encode() {
    final params = <String, String>{
      'v': '$version',
      'h': hostId,
      'n': hostName,
      'a': addresses.join(','),
      'p': '$port',
      'f': fingerprint,
      'c': code,
    };
    final query = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$scheme://$action?$query';
  }

  @override
  String toString() => 'PairingLink($hostName, ${addresses.join(",")}:$port)';
}
