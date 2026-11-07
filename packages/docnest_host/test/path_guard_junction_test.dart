import 'dart:io';

import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/docnest_host.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end check that a real Windows junction cannot be used to escape a
/// whitelisted root.
///
/// The fake-probe tests cover the logic; this one covers the platform: it needs
/// `mklink /J`, so it is skipped where junctions are unavailable.
void main() {
  late Directory temp;
  late Directory target;
  late Directory outside;
  var junctionsSupported = false;

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('docnest_junction_');
    target = Directory(p.join(temp.path, 'Docs'))..createSync();
    outside = Directory(p.join(temp.path, 'Outside'))..createSync();
    Directory(p.join(target.path, 'normal')).createSync();
    File(p.join(outside.path, 'secret.txt')).writeAsStringSync('secret');
    final result = Process.runSync('cmd', <String>[
      '/c',
      'mklink',
      '/J',
      p.join(target.path, 'link'),
      outside.path,
    ], runInShell: true);
    junctionsSupported = result.exitCode == 0;
  });

  tearDownAll(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('IoPathProbe sees the junction as a reparse point', () {
    if (!junctionsSupported) {
      markTestSkipped('junctions are not available on this platform');
      return;
    }
    const probe = IoPathProbe();
    expect(probe.isReparsePoint(p.join(target.path, 'link')), isTrue);
    expect(probe.isReparsePoint(p.join(target.path, 'normal')), isFalse);
    expect(probe.realPath(p.join(target.path, 'link'))!.toLowerCase(), outside.path.toLowerCase());
  });

  test('PathGuard blocks reads and writes through a junction', () {
    if (!junctionsSupported) {
      markTestSkipped('junctions are not available on this platform');
      return;
    }
    const guard = PathGuard(probe: IoPathProbe());
    final root = Root(
      id: const RootId(1),
      path: target.path,
      name: 'Docs',
      status: RootStatus.watching,
    );

    expect(() => guard.resolve(root, 'link/secret.txt'), throwsA(isA<PathOutsideRootException>()));
    expect(() => guard.resolve(root, 'link'), throwsA(isA<PathOutsideRootException>()));
    expect(guard.resolve(root, 'normal').relPath, 'normal');
  });

  test('a root that allows links still keeps them inside the root', () {
    if (!junctionsSupported) {
      markTestSkipped('junctions are not available on this platform');
      return;
    }
    const guard = PathGuard(probe: IoPathProbe());
    final permissive = Root(
      id: const RootId(1),
      path: target.path,
      name: 'Docs',
      status: RootStatus.watching,
      followLinks: true,
    );
    // followLinks skips the lexical link check, but the canonical-path check
    // still refuses a destination outside the root.
    expect(
      () => guard.resolve(permissive, 'link/secret.txt'),
      throwsA(isA<PathOutsideRootException>()),
    );
  });

  test('an 8.3 short path is not mistaken for a junction', () {
    final longDirectory = Directory(
      p.join(temp.path, 'A Very Long Directory Name To Force A Short Name'),
    )..createSync();
    File(p.join(longDirectory.path, 'file.txt')).writeAsStringSync('x');

    final short = Process.runSync('cmd', <String>[
      '/c',
      'for %I in ("${longDirectory.path}") do @echo %~sI',
    ], runInShell: true).stdout.toString().trim();
    if (short.isEmpty || short.toLowerCase() == longDirectory.path.toLowerCase()) {
      markTestSkipped('8.3 short names are not available on this volume');
      return;
    }

    const probe = IoPathProbe();
    expect(probe.isReparsePoint(p.join(short, 'file.txt')), isFalse);
    expect(probe.isReparsePoint(short), isFalse);

    const guard = PathGuard(probe: IoPathProbe());
    final shortRoot = Root(
      id: const RootId(1),
      path: short,
      name: 'Docs',
      status: RootStatus.watching,
    );
    expect(guard.resolve(shortRoot, 'file.txt').relPath, 'file.txt');
  });
}
