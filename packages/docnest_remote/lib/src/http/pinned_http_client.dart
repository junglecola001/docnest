import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The host is reached over TLS with a self-signed certificate whose fingerprint
/// the client learned from the pairing QR code (ADR 0004).
///
/// `SecurityContext(withTrustedRoots: false)` makes every handshake fail at
/// first, so [HttpClient.badCertificateCallback] is the only place trust can be
/// granted — and it grants it to exactly one certificate.
HttpClient createPinnedHttpClient({
  required String expectedFingerprint,
  SecurityContext? context,
  Duration connectionTimeout = const Duration(seconds: 10),
}) {
  final client = HttpClient(context: context ?? SecurityContext(withTrustedRoots: false));
  client.connectionTimeout = connectionTimeout;
  client.badCertificateCallback = (X509Certificate certificate, String host, int port) {
    return constantTimeEquals(certificateFingerprint(certificate), expectedFingerprint);
  };
  return client;
}

/// Base64url (no padding) of the certificate's SHA-256, matching the `f` field
/// of a `docnest://pair` link.
String certificateFingerprint(X509Certificate certificate) =>
    base64Url.encode(sha256.convert(certificate.der).bytes).replaceAll('=', '');

/// Compares two fingerprints without leaking where they diverge.
///
/// The fingerprints are public, but a short-circuit compare here costs nothing
/// and keeps the habit consistent with the token checks on the host.
bool constantTimeEquals(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}
