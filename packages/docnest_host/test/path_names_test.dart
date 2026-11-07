import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/docnest_host.dart';
import 'package:test/test.dart';

void main() {
  group('NameSanitizer', () {
    test('leaves a normal name alone', () {
      expect(NameSanitizer.sanitize('Lease 2026.pdf'), 'Lease 2026.pdf');
      expect(NameSanitizer.sanitize('合同.pdf'), '合同.pdf');
    });

    test('replaces characters Windows rejects', () {
      expect(NameSanitizer.sanitize('a<b>c:d"e|f?g*h.txt'), 'a_b_c_d_e_f_g_h.txt');
      expect(NameSanitizer.sanitize('path/to\\file.txt'), 'path_to_file.txt');
      expect(NameSanitizer.sanitize('tab\there.txt'), 'tab_here.txt');
    });

    test('strips trailing dots and spaces', () {
      expect(NameSanitizer.sanitize('report.pdf...'), 'report.pdf');
      expect(NameSanitizer.sanitize('report   '), 'report');
    });

    test('prefixes reserved device names but keeps the extension', () {
      expect(NameSanitizer.sanitize('CON'), '_CON');
      expect(NameSanitizer.sanitize('con.txt'), '_con.txt');
      expect(NameSanitizer.sanitize('LPT1.log'), '_LPT1.log');
      expect(NameSanitizer.sanitize('CONSOLE.txt'), 'CONSOLE.txt');
    });

    test('throws when nothing usable is left', () {
      expect(() => NameSanitizer.sanitize('...'), throwsA(isA<InvalidNameException>()));
      expect(() => NameSanitizer.sanitize('   '), throwsA(isA<InvalidNameException>()));
      expect(() => NameSanitizer.sanitize(''), throwsA(isA<InvalidNameException>()));
    });

    test('truncates long names but keeps the extension', () {
      final long = '${'a' * 400}.pdf';
      final sanitized = NameSanitizer.sanitize(long);
      expect(sanitized.length, NameSanitizer.maxLength);
      expect(sanitized, endsWith('.pdf'));
    });

    test('truncation never splits a surrogate pair', () {
      final emoji = '😀' * 200; // 400 UTF-16 units
      final sanitized = NameSanitizer.sanitize(emoji);
      expect(sanitized.length, lessThanOrEqualTo(NameSanitizer.maxLength));
      // A lone surrogate would make this throw.
      expect(() => sanitized.runes.toList(), returnsNormally);
      expect(sanitized.runes.length * 2, sanitized.length);
    });

    test('reports reserved names', () {
      expect(NameSanitizer.isReserved('aux'), isTrue);
      expect(NameSanitizer.isReserved('aux.txt'), isTrue);
      expect(NameSanitizer.isReserved('auxiliary.txt'), isFalse);
    });
  });

  group('ConflictResolver', () {
    test('returns the desired name when it is free', () {
      expect(
        ConflictResolver.resolve(
          desiredName: 'report.pdf',
          existing: {'other.pdf'},
          policy: ConflictPolicy.rename,
        ),
        'report.pdf',
      );
    });

    test('rename appends a counter before the extension', () {
      final existing = {'report.pdf', 'report (1).PDF'};
      expect(
        ConflictResolver.resolve(
          desiredName: 'report.pdf',
          existing: existing,
          policy: ConflictPolicy.rename,
        ),
        'report (2).pdf',
      );
    });

    test('rename handles names without an extension', () {
      expect(
        ConflictResolver.resolve(
          desiredName: 'notes',
          existing: {'notes'},
          policy: ConflictPolicy.rename,
        ),
        'notes (1)',
      );
    });

    test('skip returns null when the name exists and the name when it does not', () {
      expect(
        ConflictResolver.resolve(
          desiredName: 'a.pdf',
          existing: {'a.pdf'},
          policy: ConflictPolicy.skip,
        ),
        isNull,
      );
      expect(
        ConflictResolver.resolve(
          desiredName: 'b.pdf',
          existing: {'a.pdf'},
          policy: ConflictPolicy.skip,
        ),
        'b.pdf',
      );
    });

    test('overwrite returns the desired name', () {
      expect(
        ConflictResolver.resolve(
          desiredName: 'a.pdf',
          existing: {'a.pdf'},
          policy: ConflictPolicy.overwrite,
        ),
        'a.pdf',
      );
    });

    test('comparison is case-insensitive, matching Windows', () {
      expect(
        ConflictResolver.resolve(
          desiredName: 'Report.PDF',
          existing: {'report.pdf'},
          policy: ConflictPolicy.skip,
        ),
        isNull,
      );
    });

    test('falls back to a timestamp after the counter limit', () {
      final existing = {
        'a.pdf',
        for (var i = 1; i <= ConflictResolver.maxRenameAttempts; i++) 'a ($i).pdf',
      };
      final resolved = ConflictResolver.resolve(
        desiredName: 'a.pdf',
        existing: existing,
        policy: ConflictPolicy.rename,
        now: DateTime.utc(2026, 11, 7, 12),
      );
      expect(resolved, endsWith('.pdf'));
      expect(resolved, contains('(1794'));
    });
  });

  group('ExcludeGlobs', () {
    final globs = ExcludeGlobs(defaultExcludeGlobs);

    test('office lock files are excluded at any depth', () {
      expect(globs.matches(r'~$Report.docx'), isTrue);
      expect(globs.matches('Contracts/~\$Report.docx'), isTrue);
      expect(globs.matches('Contracts/Report.docx'), isFalse);
    });

    test('temporary files are excluded', () {
      expect(globs.matches('a/b/write.tmp'), isTrue);
      expect(globs.matches('.~lock.report.odt#'), isTrue);
      expect(globs.matches('report.docx'), isFalse);
    });

    test('directory patterns hide their contents', () {
      expect(globs.matches('node_modules'), isTrue);
      expect(globs.matches('node_modules/pkg/index.js'), isTrue);
      expect(globs.matches('a/b/.git'), isTrue);
      expect(globs.matches('a/b/.git/config'), isTrue);
      expect(globs.matches('.docnest/staging/x.part'), isTrue);
      expect(globs.matches(r'$RECYCLE.BIN/S-1-5/desktop.ini'), isTrue);
    });

    test('shell noise files are excluded', () {
      expect(globs.matches('Thumbs.db'), isTrue);
      expect(globs.matches('deep/Thumbs.db'), isTrue);
      expect(globs.matches('desktop.ini'), isTrue);
    });

    test('glob wildcards work', () {
      final custom = ExcludeGlobs(['drafts/*.txt', '**/skip/**', 'temp-?']);
      expect(custom.matches('drafts/note.txt'), isTrue);
      expect(custom.matches('drafts/note.md'), isFalse);
      expect(custom.matches('a/skip/b/c.pdf'), isTrue);
      expect(custom.matches('temp-1'), isTrue);
      expect(custom.matches('temp-12'), isFalse);
    });

    test('matching is case-insensitive', () {
      expect(globs.matches('THUMBS.DB'), isTrue);
      expect(globs.matches('Node_Modules/x/y.js'), isTrue);
    });

    test('ordinary documents are not excluded', () {
      for (final path in ['Lease.pdf', 'Contracts/2026/Lease.pdf', '合同.docx', 'a.b.c.md']) {
        expect(globs.matches(path), isFalse, reason: path);
      }
    });

    test('an empty pattern list matches nothing', () {
      expect(ExcludeGlobs(const []).matches('~\$a.docx'), isFalse);
      expect(ExcludeGlobs(const []).isEmpty, isTrue);
    });
  });
}
