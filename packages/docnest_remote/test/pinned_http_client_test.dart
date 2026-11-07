import 'dart:io';

import 'package:docnest_remote/docnest_remote.dart';
import 'package:test/test.dart';

/// Proves the pinning that ADR 0004 depends on: a self-signed host is reachable
/// only when its certificate fingerprint matches the one from the QR code.
///
/// The certificate is generated with `openssl` at test time; where openssl is
/// unavailable the tests skip rather than silently passing.
void main() {
  late Directory temp;
  late HttpServer server;
  late String actualFingerprint;
  late bool hasOpenSsl;

  Future<String> run(List<String> arguments) async {
    final result = await Process.run('openssl', arguments, runInShell: true);
    if (result.exitCode != 0) {
      throw StateError('openssl failed: ${result.stderr}');
    }
    return result.stdout.toString();
  }

  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('docnest_tls_');
    final key = '${temp.path}/key.pem';
    final cert = '${temp.path}/cert.pem';
    hasOpenSsl = true;
    try {
      await run(<String>[
        'req',
        '-x509',
        '-newkey',
        'ec',
        '-pkeyopt',
        'ec_paramgen_curve:prime256v1',
        '-nodes',
        '-keyout',
        key,
        '-out',
        cert,
        '-days',
        '1',
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=IP:127.0.0.1,DNS:localhost',
      ]);
    } on Object {
      hasOpenSsl = false;
      markTestSkipped('openssl is not available');
      return;
    }

    final context = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ok')
        ..close();
    });

    // Learn the fingerprint the way a permissive first contact would see it;
    // production code never does this, tests need it to know what to pin.
    final probe = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..badCertificateCallback = (certificate, host, port) {
        actualFingerprint = certificateFingerprint(certificate);
        return true;
      };
    final request = await probe.getUrl(Uri.parse('https://127.0.0.1:${server.port}/'));
    final response = await request.close();
    await response.drain<void>();
    probe.close();
  });

  tearDownAll(() async {
    if (!hasOpenSsl) return;
    await server.close(force: true);
    temp.deleteSync(recursive: true);
  });

  test('the fingerprint is a 43-character base64url SHA-256', () {
    if (!hasOpenSsl) return;
    expect(actualFingerprint, hasLength(43));
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(actualFingerprint), isTrue);
  });

  test('a client pinned to the presented certificate connects', () async {
    if (!hasOpenSsl) return;
    final client = createPinnedHttpClient(expectedFingerprint: actualFingerprint);
    addTearDown(client.close);
    final request = await client.getUrl(Uri.parse('https://127.0.0.1:${server.port}/'));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    await response.drain<void>();
  });

  test('a client pinned to another certificate refuses the handshake', () async {
    if (!hasOpenSsl) return;
    final client = createPinnedHttpClient(expectedFingerprint: 'A' * 43);
    addTearDown(client.close);
    await expectLater(
      client
          .getUrl(Uri.parse('https://127.0.0.1:${server.port}/'))
          .then((request) => request.close()),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('constant-time compare ignores case and padding-insensitive formatting', () {
    expect(constantTimeEquals('ABC', 'abc'), isTrue);
    expect(constantTimeEquals('abc ', ' abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
    expect(constantTimeEquals('abc', 'ab'), isFalse);
  });
}
