import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/docnest_host.dart';
import 'package:test/test.dart';

void main() {
  final validator = RootValidator(
    systemDirectories: <String>[
      r'C:\Windows',
      r'C:\Program Files',
      r'C:\Program Files (x86)',
      r'C:\ProgramData',
      r'C:\Users\anna',
    ],
  );

  Root root(String path, {int id = 1}) =>
      Root(id: RootId(id), path: path, name: 'R$id', status: RootStatus.watching);

  group('RootValidator', () {
    test('accepts an ordinary folder', () {
      final check = validator.check(candidatePath: r'D:\Work\Docs', roots: const []);
      expect(check.issues, isEmpty);
      expect(check.canAdd, isTrue);
      expect(check.needsConfirmation, isFalse);
    });

    test('rejects relative and empty paths', () {
      expect(
        validator.check(candidatePath: 'Docs', roots: const []).issues,
        contains(RootIssue.invalidPath),
      );
      expect(
        validator.check(candidatePath: '  ', roots: const []).issues,
        contains(RootIssue.invalidPath),
      );
      expect(validator.check(candidatePath: '', roots: const []).canAdd, isFalse);
    });

    test('rejects system directories, including their children', () {
      for (final path in <String>[
        r'C:\Windows',
        r'C:\Windows\System32',
        r'C:\Program Files\Something',
        r'C:\ProgramData\Secret',
      ]) {
        expect(
          validator.check(candidatePath: path, roots: const []).issues,
          contains(RootIssue.systemDirectory),
          reason: path,
        );
      }
    });

    test('rejects a protected segment reached through another path', () {
      expect(
        validator.check(candidatePath: r'D:\Backup\AppData\Local', roots: const []).issues,
        contains(RootIssue.systemDirectory),
      );
      expect(
        validator.check(candidatePath: r'D:\Backup\$RECYCLE.BIN', roots: const []).issues,
        contains(RootIssue.systemDirectory),
      );
    });

    test('asking for a whole drive needs confirmation but is not blocked', () {
      final check = validator.check(candidatePath: r'D:\', roots: const []);
      expect(check.issues, contains(RootIssue.driveRoot));
      expect(check.needsConfirmation, isTrue);
      expect(check.canAdd, isTrue);
    });

    test('a folder already added is refused', () {
      final check = validator.check(
        candidatePath: r'D:\Work\Docs',
        roots: <Root>[root(r'd:\work\docs')],
      );
      expect(check.issues, contains(RootIssue.alreadyAdded));
      expect(check.canAdd, isFalse);
      expect(check.existingRoots, hasLength(1));
    });

    test('a folder inside an existing root is refused with the covering root', () {
      final check = validator.check(
        candidatePath: r'D:\Work\Docs\2026',
        roots: <Root>[root(r'D:\Work\Docs')],
      );
      expect(check.issues, contains(RootIssue.insideExistingRoot));
      expect(check.canAdd, isFalse);
      expect(check.existingRoots.single.path, r'D:\Work\Docs');
    });

    test('a folder containing an existing root asks for a merge', () {
      final check = validator.check(
        candidatePath: r'D:\Work',
        roots: <Root>[root(r'D:\Work\Docs'), root(r'D:\Work\Papers', id: 2)],
      );
      expect(check.issues, contains(RootIssue.containsExistingRoot));
      expect(check.needsConfirmation, isTrue);
      expect(check.canAdd, isTrue);
      expect(check.existingRoots, hasLength(2));
    });

    test('sibling folders with a shared prefix do not count as nesting', () {
      final check = validator.check(
        candidatePath: r'D:\Work\Docs2',
        roots: <Root>[root(r'D:\Work\Docs')],
      );
      expect(check.issues, isEmpty);
    });

    test('normalises the path it reports', () {
      final check = validator.check(candidatePath: r'D:\Work\Docs\..\Docs', roots: const []);
      expect(check.path, r'D:\Work\Docs');
    });
  });
}
