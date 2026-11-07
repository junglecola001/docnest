import 'package:docnest_protocol/docnest_protocol.dart';
import 'package:test/test.dart';

void main() {
  final fingerprint = 'A' * 42 + 'B'; // 43 chars, base64url alphabet

  PairingLink link() => PairingLink(
    hostId: 'h-1',
    hostName: 'HOME-PC',
    addresses: const ['192.168.1.8', '10.0.0.5'],
    port: 53420,
    fingerprint: fingerprint,
    code: '418207',
  );

  test('encode/parse round-trip', () {
    final encoded = link().encode();
    expect(encoded, startsWith('docnest://pair?'));
    final parsed = PairingLink.parse(encoded);
    expect(parsed.hostId, 'h-1');
    expect(parsed.hostName, 'HOME-PC');
    expect(parsed.addresses, ['192.168.1.8', '10.0.0.5']);
    expect(parsed.port, 53420);
    expect(parsed.fingerprint, fingerprint);
    expect(parsed.code, '418207');
    expect(parsed.version, 1);
  });

  test('parse tolerates whitespace and a mixed-case scheme', () {
    final parsed = PairingLink.parse('  ${link().encode()}\n');
    expect(parsed.port, 53420);
  });

  test('rejects foreign schemes and actions', () {
    expect(() => PairingLink.parse('https://pair?h=1'), throwsFormatException);
    expect(() => PairingLink.parse('docnest://open?h=1'), throwsFormatException);
    expect(() => PairingLink.parse(''), throwsFormatException);
  });

  test('rejects a bad fingerprint rather than pinning something else', () {
    final broken = link().encode().replaceAll(fingerprint, 'too-short');
    expect(() => PairingLink.parse(broken), throwsFormatException);
    final padded = link().encode().replaceAll(fingerprint, '${fingerprint.substring(0, 42)}=+');
    expect(() => PairingLink.parse(padded), throwsFormatException);
  });

  test('rejects out-of-range ports and empty address lists', () {
    final base = link().encode();
    expect(() => PairingLink.parse(base.replaceAll('p=53420', 'p=0')), throwsFormatException);
    expect(() => PairingLink.parse(base.replaceAll('p=53420', 'p=70000')), throwsFormatException);
    expect(
      () => PairingLink.parse(base.replaceAll('a=192.168.1.8%2C10.0.0.5', 'a=')),
      throwsFormatException,
    );
  });

  test('rejects an unsupported link version', () {
    final base = link().encode().replaceAll('v=1', 'v=2');
    expect(() => PairingLink.parse(base), throwsFormatException);
  });

  test('reports a fingerprint mismatch instead of trusting it', () {
    final parsed = PairingLink.parse(link().encode());
    expect(parsed.matchesFingerprint(fingerprint), isTrue);
    expect(parsed.matchesFingerprint('B' * 43), isFalse);
  });
}
