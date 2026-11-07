import 'dart:math';

import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/docnest_host.dart';
import 'package:test/test.dart';

/// Randomised sweep over the hostile parts of the filesystem namespace.
///
/// The property is deliberately weak but absolute: whatever the input, the
/// guard either throws an [AppException] or returns a path that is inside the
/// root. Nothing else may escape, and no other exception type may be thrown.
void main() {
  const rootPath = r'D:\Docs';
  const alphabet = <String>[
    'a',
    'Z',
    '0',
    ' ',
    '.',
    '..',
    '/',
    r'\',
    ':',
    '<',
    '>',
    '"',
    '|',
    '?',
    '*',
    '%',
    '%2e',
    '~',
    '\u0000',
    '\u0007',
    'ü',
    '合',
    '同',
    '\u0301',
    'CON',
    'aux',
    'COM1',
    'LPT9',
    r'$',
    '#',
    '=',
    '+',
    '\uD83D\uDE00',
  ];

  test('3000 random hostile names never escape the root', () {
    final guard = PathGuard();
    final root = Root(
      id: const RootId(1),
      path: rootPath,
      name: 'Docs',
      status: RootStatus.watching,
    );
    final random = Random(20261107);
    var rejected = 0;
    var accepted = 0;

    for (var iteration = 0; iteration < 3000; iteration++) {
      final length = random.nextInt(8) + 1;
      final buffer = StringBuffer();
      for (var part = 0; part < length; part++) {
        buffer.write(alphabet[random.nextInt(alphabet.length)]);
      }
      final relPath = buffer.toString();

      try {
        final resolved = guard.resolve(root, relPath);
        accepted++;
        final lowered = resolved.fullPath.toLowerCase();
        expect(
          lowered == rootPath.toLowerCase() || lowered.startsWith('${rootPath.toLowerCase()}\\'),
          isTrue,
          reason: 'escaped root: "$relPath" -> ${resolved.fullPath}',
        );
        expect(
          resolved.relPath.split('/').every((segment) => segment != '.' && segment != '..'),
          isTrue,
          reason: 'dot segments survived: $relPath',
        );
        expect(resolved.relPath.startsWith('/'), isFalse, reason: 'absolute path survived: $relPath');
        expect(resolved.relPath.contains(':'), isFalse, reason: 'drive or ADS survived: $relPath');
      } on AppException {
        rejected++;
      }
      // Any other exception type fails the test by escaping this block.
    }

    expect(rejected, greaterThan(0), reason: 'the fuzz corpus should hit rejections');
    expect(accepted, greaterThan(0), reason: 'some plain names should still be accepted');
  });
}
