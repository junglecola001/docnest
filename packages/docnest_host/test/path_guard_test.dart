import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/docnest_host.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Probe that reports whatever the test declares, so escapes can be simulated
/// without creating junctions on disk.
class FakeProbe implements PathProbe {
  FakeProbe({Set<String> reparse = const {}, Map<String, String> realPaths = const {}})
    : reparse = {for (final path in reparse) _norm(path)},
      realPaths = {for (final entry in realPaths.entries) _norm(entry.key): entry.value};

  final Set<String> reparse;
  final Map<String, String> realPaths;

  @override
  bool exists(String fullPath) => true;

  @override
  bool isDirectory(String fullPath) => true;

  @override
  bool isReparsePoint(String fullPath) => reparse.contains(_norm(fullPath));

  @override
  String? realPath(String fullPath) => realPaths[_norm(fullPath)];

  static String _norm(String path) => p.windows.normalize(path).toLowerCase();
}

Root root({
  String path = r'D:\Docs',
  bool followLinks = false,
  bool localReadOnly = false,
  RootStatus status = RootStatus.watching,
}) {
  return Root(
    id: const RootId(1),
    path: path,
    name: 'Docs',
    followLinks: followLinks,
    localReadOnly: localReadOnly,
    status: status,
  );
}

void main() {
  final guard = PathGuard();

  group('accepts legitimate relative paths', () {
    test('nested path is joined under the root', () {
      final resolved = guard.resolve(root(), 'Contracts/2026/Lease.pdf');
      expect(resolved.relPath, 'Contracts/2026/Lease.pdf');
      expect(resolved.fullPath, p.windows.join(r'D:\Docs', 'Contracts', '2026', 'Lease.pdf'));
      expect(resolved.name, 'Lease.pdf');
      expect(resolved.isRoot, isFalse);
    });

    test('empty path is the root itself', () {
      final resolved = guard.resolve(root(), '');
      expect(resolved.relPath, '');
      expect(resolved.isRoot, isTrue);
      expect(resolved.fullPath, r'D:\Docs');
    });

    test('duplicate separators, backslashes and a trailing slash collapse', () {
      expect(guard.resolve(root(), r'a\\b//c/').relPath, 'a/b/c');
      expect(guard.resolve(root(), r'Contracts\Lease.pdf').relPath, 'Contracts/Lease.pdf');
    });

    test('unicode names survive unchanged', () {
      const name = '合同 (2026) 副本.pdf';
      expect(guard.resolve(root(), name).relPath, name);
      // NFD and NFC are distinct strings; both are legal names.
      const nfd = 'Cafe\u0301.pdf';
      expect(guard.resolve(root(), nfd).relPath, nfd);
    });

    test('names that merely look like device names are rejected only when exact', () {
      expect(guard.resolve(root(), 'CONSOLE.txt').relPath, 'CONSOLE.txt');
      expect(guard.resolve(root(), 'consult.docx').relPath, 'consult.docx');
    });
  });

  group('rejects traversal and absolute forms', () {
    final badPaths = <String, String>{
      'parent traversal': '../secret.txt',
      'nested traversal': 'a/../../secret.txt',
      'bare dot-dot': '..',
      'current dir segment': 'a/./b.txt',
      'percent-encoded traversal': '%2e%2e/secret.txt',
      'uppercase encoded traversal': '%2E%2E/secret.txt',
      'absolute unix': '/etc/passwd',
      'absolute windows': r'\Windows\System32\drivers\etc\hosts',
      'drive relative': r'C:secret.txt',
      'drive absolute': r'C:\Windows\notepad.exe',
      'unc share': r'\\server\share\file.txt',
      'extended prefix': r'\\?\C:\Windows',
      'alternate data stream': 'report.pdf:hidden',
      'device path': r'\\.\PhysicalDrive0',
    };

    badPaths.forEach((label, path) {
      test('$label ($path)', () {
        expect(
          () => guard.resolve(root(), path),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              anyOf(DocNestErrorCode.pathOutsideRoot, DocNestErrorCode.invalidName),
            ),
          ),
        );
      });
    });

    test('a name ending with a dot or space is refused', () {
      expect(() => guard.resolve(root(), 'report.pdf.'), throwsA(isA<InvalidNameException>()));
      expect(() => guard.resolve(root(), 'report .pdf '), throwsA(isA<InvalidNameException>()));
    });

    test('reserved device names are refused with or without extension', () {
      for (final name in ['CON', 'con', 'PRN.txt', 'aux.log', 'NUL', 'COM1', 'com9.dat', 'LPT3']) {
        expect(
          () => guard.resolve(root(), name),
          throwsA(isA<InvalidNameException>()),
          reason: name,
        );
      }
    });

    test('illegal characters are refused', () {
      for (final name in ['a<b', 'a>b', 'a|b', 'a?b', 'a*b', 'a"b', 'a\u0007b']) {
        expect(
          () => guard.resolve(root(), name),
          throwsA(isA<InvalidNameException>()),
          reason: name,
        );
      }
    });

    test('a NUL byte is refused', () {
      expect(() => guard.resolve(root(), 'a\u0000b'), throwsA(isA<InvalidNameException>()));
    });
  });

  group('containment is case-insensitive', () {
    test('root comparison ignores case', () {
      final resolved = guard.resolve(root(), 'Contracts/Lease.pdf');
      expect(resolved.fullPath.toLowerCase(), contains(r'd:\docs'));
    });

    test('a root that is not absolute is refused', () {
      expect(
        () => guard.resolve(root(path: r'Docs\Sub'), 'a.txt'),
        throwsA(isA<InvalidRequestException>()),
      );
    });

    test('a sibling with the same prefix is not "within" the root', () {
      // D:\Docs2 must not count as inside D:\Docs: the real path of the
      // requested file is what the guard compares.
      final sibling = PathGuard(
        probe: FakeProbe(realPaths: {r'D:\Docs\evil.txt': r'D:\Docs2\evil.txt'}),
      );
      expect(() => sibling.resolve(root(), 'evil.txt'), throwsA(isA<PathOutsideRootException>()));
    });
  });

  group('reparse points', () {
    test('a junction inside the root is refused by default', () {
      final probe = FakeProbe(reparse: {r'D:\Docs\link'});
      final guarded = PathGuard(probe: probe);
      expect(
        () => guarded.resolve(root(), r'link\secret.txt'),
        throwsA(isA<PathOutsideRootException>()),
      );
    });

    test('a junction is followed only when the root allows links', () {
      final probe = FakeProbe(reparse: {r'D:\Docs\link'});
      final guarded = PathGuard(probe: probe);
      final resolved = guarded.resolve(root(followLinks: true), r'link\a.txt');
      expect(resolved.relPath, 'link/a.txt');
    });

    test('the real path from an open handle must stay inside the root', () {
      final probe = FakeProbe(realPaths: {r'D:\Docs\escape.txt': r'C:\Windows\win.ini'});
      final guarded = PathGuard(probe: probe);
      expect(() => guarded.resolve(root(), 'escape.txt'), throwsA(isA<PathOutsideRootException>()));
    });

    test('a real path inside the root passes', () {
      final probe = FakeProbe(realPaths: {r'D:\Docs\ok.txt': r'd:\docs\ok.txt'});
      final guarded = PathGuard(probe: probe);
      expect(guarded.resolve(root(), 'ok.txt').relPath, 'ok.txt');
    });
  });

  group('write guard', () {
    test('read-only roots refuse writes', () {
      expect(
        () => guard.resolveWritable(root(localReadOnly: true), 'a.txt'),
        throwsA(isA<ReadOnlyException>()),
      );
    });

    test('offline roots refuse writes', () {
      expect(
        () => guard.resolveWritable(root(status: RootStatus.offline), 'a.txt'),
        throwsA(isA<RootOfflineException>()),
      );
    });

    test('watching roots allow writes and still validate the path', () {
      expect(guard.resolveWritable(root(), 'Inbox/a.txt').relPath, 'Inbox/a.txt');
      expect(
        () => guard.resolveWritable(root(), '../a.txt'),
        throwsA(isA<PathOutsideRootException>()),
      );
    });
  });

  group('resolveName', () {
    test('accepts a single segment', () {
      expect(guard.resolveName('Lease.pdf'), 'Lease.pdf');
    });

    test('rejects separators and traversal', () {
      expect(() => guard.resolveName('a/b'), throwsA(isA<InvalidNameException>()));
      expect(() => guard.resolveName('..'), throwsA(isA<PathOutsideRootException>()));
      expect(() => guard.resolveName(''), throwsA(isA<InvalidNameException>()));
    });
  });
}
