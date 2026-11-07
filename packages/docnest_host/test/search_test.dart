import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/src/ext/doc_kind_map.dart';
import 'package:docnest_host/src/search/name_index.dart';
import 'package:docnest_host/src/search/search_syntax.dart';
import 'package:docnest_host/src/search/tokenizer.dart';
import 'package:test/test.dart';

void main() {
  group('DocKindMap', () {
    test('maps the default document extensions to their kind', () {
      expect(kindForExtension('pdf'), DocKind.pdf);
      expect(kindForExtension('.DOCX'), DocKind.word);
      expect(kindForExtension('xlsx'), DocKind.spreadsheet);
      expect(kindForExtension('pptx'), DocKind.presentation);
      expect(kindForExtension('txt'), DocKind.text);
      expect(kindForExtension('md'), DocKind.markdown);
      expect(kindForExtension('epub'), DocKind.ebook);
      expect(kindForExtension('PNG'), DocKind.image);
      expect(kindForExtension('zip'), DocKind.archive);
    });

    test('unknown and empty extensions fall back to other', () {
      expect(kindForExtension('totallyunknown'), DocKind.other);
      expect(kindForExtension(''), DocKind.other);
      expect(kindForExtension('.'), DocKind.other);
    });

    test('an empty configured set means the default index set', () {
      expect(resolveIndexExtensions(configured: <String>{}), defaultIndexExtensions);
      expect(resolveIndexExtensions(configured: <String>{}), isNot(contains('png')));
    });

    test('images are opt-in and normalised', () {
      expect(
        resolveIndexExtensions(configured: <String>{}, includeImages: true),
        containsAll(<String>['pdf', 'png', 'jpg']),
      );
      expect(resolveIndexExtensions(configured: <String>{'.PNG', ' PDF '}), <String>{'png', 'pdf'});
    });
  });

  group('NameIndex', () {
    test('builds pinyin and initials from the stem, not the extension', () {
      final index = NameIndex.of('合同管理.pdf');
      expect(index.nameNorm, '合同管理.pdf');
      expect(index.pinyin, contains('hetongguanli'));
      expect(index.initials, 'htgl');
      // `pdf` must not leak into the pinyin keys.
      expect(index.pinyin, isNot(contains('pdf')));
    });

    test('folds full-width ASCII, case and surrounding whitespace', () {
      final index = NameIndex.of('  ＲＥＰＯＲＴ．ＰＤＦ  ');
      expect(index.nameNorm, 'report.pdf');
      expect(index.nameNorm, contains('report'));
    });

    test('keeps latin words searchable through the pinyin key', () {
      final index = NameIndex.of('Annual Report 2026.docx');
      expect(index.pinyin, contains('annualreport2026'));
      expect(index.initials, 'ar2');
    });

    test('handles a name without an extension', () {
      final index = NameIndex.of('Notes');
      expect(index.nameNorm, 'notes');
      expect(index.pinyin, 'notes');
    });
  });

  group('SearchTokenizer.indexTokens', () {
    test('splits a Chinese run into overlapping bigrams', () {
      expect(SearchTokenizer.indexTokens('合同管理'), <String>['合同', '同管', '管理']);
    });

    test('keeps a single Chinese character as one token', () {
      expect(SearchTokenizer.indexTokens('合'), <String>['合']);
    });

    test('lowercases latin and digit words and drops punctuation', () {
      expect(SearchTokenizer.indexTokens('Hello, World 2026!'), <String>['hello', 'world', '2026']);
    });

    test('keeps bigrams and latin words in order', () {
      expect(SearchTokenizer.indexTokens('合同管理 Report'), <String>['合同', '同管', '管理', 'report']);
    });

    test('returns nothing for empty or punctuation-only text', () {
      expect(SearchTokenizer.indexTokens(''), isEmpty);
      expect(SearchTokenizer.indexTokens(' --- !!! '), isEmpty);
    });
  });

  group('SearchTokenizer.ftsQuery', () {
    test('ANDs the bigrams so a two-character word matches', () {
      expect(SearchTokenizer.ftsQuery('合同管理'), '"合同" AND "同管" AND "管理"');
      expect(SearchTokenizer.ftsQuery('报告'), '"报告"');
    });

    test('uses a prefix query for a single Chinese character', () {
      expect(SearchTokenizer.ftsQuery('合'), '"合"*');
    });

    test('makes a trailing latin word a prefix query', () {
      expect(SearchTokenizer.ftsQuery('合同 abc'), '"合同" AND "abc"*');
      expect(SearchTokenizer.ftsQuery('abc'), '"abc"*');
    });

    test('does not add a prefix when the input ends with whitespace', () {
      expect(SearchTokenizer.ftsQuery('abc '), '"abc"');
    });

    test('does not prefix a mid-query word', () {
      expect(SearchTokenizer.ftsQuery('abc 合同'), '"abc" AND "合同"');
    });

    test('quotes FTS operators so they are literal text', () {
      expect(SearchTokenizer.ftsQuery('foo" OR "bar'), '"foo" AND "or" AND "bar"*');
      expect(SearchTokenizer.ftsQuery('NEAR(x)'), '"near" AND "x"');
    });

    test('never emits an unbalanced quote', () {
      final matcher = RegExp(r'^"[^"]*"(\*)?( AND "[^"]*"(\*)?)*$');
      for (final input in <String>[
        '合同管理',
        'foo" OR "bar',
        'a"b"c',
        '合 同 "管理"',
        '"""',
        'a AND b*',
      ]) {
        final query = SearchTokenizer.ftsQuery(input);
        if (query.isEmpty) continue;
        expect(query, matches(matcher), reason: 'input: $input');
      }
    });

    test('returns an empty expression when nothing is searchable', () {
      expect(SearchTokenizer.ftsQuery(''), '');
      expect(SearchTokenizer.ftsQuery('   '), '');
      expect(SearchTokenizer.ftsQuery('***'), '');
      expect(SearchTokenizer.ftsQuery('"'), '');
    });
  });

  group('SearchSyntax', () {
    test('keeps free text as keywords and leaves the query text unset', () {
      final result = SearchSyntax.parse('合同 报告');
      expect(result.keywords, '合同 报告');
      expect(result.filters.text, isNull);
    });

    test('type: maps every alias to a DocKind', () {
      final expected = <String, DocKind>{
        'pdf': DocKind.pdf,
        'word': DocKind.word,
        'excel': DocKind.spreadsheet,
        'spreadsheet': DocKind.spreadsheet,
        'ppt': DocKind.presentation,
        'presentation': DocKind.presentation,
        'text': DocKind.text,
        'markdown': DocKind.markdown,
        'image': DocKind.image,
      };
      for (final entry in expected.entries) {
        final result = SearchSyntax.parse('type:${entry.key}');
        expect(result.filters.kinds, <DocKind>{entry.value});
        expect(result.keywords, isEmpty);
      }
    });

    test('ext: accepts a leading dot and any case', () {
      final result = SearchSyntax.parse('ext:.PDF ext:DOCX');
      expect(result.filters.exts, <String>{'pdf', 'docx'});
    });

    test('tag: and root: parse ids', () {
      final result = SearchSyntax.parse('tag:3 tag:4 root:7');
      expect(result.filters.tagIds, <TagId>[const TagId(3), const TagId(4)]);
      expect(result.filters.rootId, const RootId(7));
    });

    test('size: understands comparison operators and units', () {
      expect(SearchSyntax.parse('size:>10mb').filters.minSize, 10 * 1024 * 1024 + 1);
      expect(SearchSyntax.parse('size:>=1kb').filters.minSize, 1024);
      expect(SearchSyntax.parse('size:<1kb').filters.maxSize, 1023);
      expect(SearchSyntax.parse('size:<=2mb').filters.maxSize, 2 * 1024 * 1024);
      expect(SearchSyntax.parse('size:1.5mb').filters.minSize, 1572864);
      expect(SearchSyntax.parse('size:1.5mb').filters.maxSize, 1572864);
      expect(SearchSyntax.parse('size:10').filters.minSize, 10);
      expect(SearchSyntax.parse('size:>500b').filters.minSize, 501);
      expect(SearchSyntax.parse('size:2gb').filters.minSize, 2 * 1024 * 1024 * 1024);
    });

    test('size: keeps the tightest bounds when repeated', () {
      final result = SearchSyntax.parse('size:>=1kb size:>=2kb size:<=10mb size:<=5mb');
      expect(result.filters.minSize, 2048);
      expect(result.filters.maxSize, 5 * 1024 * 1024);
    });

    test('modified: parses a whole month', () {
      final filters = SearchSyntax.parse('modified:2026-10').filters;
      expect(filters.modifiedAfter, DateTime(2026, 10));
      expect(filters.modifiedBefore, DateTime(2026, 10, 31, 23, 59, 59, 999));
    });

    test('modified: parses a whole day', () {
      final filters = SearchSyntax.parse('modified:2026-10-03').filters;
      expect(filters.modifiedAfter, DateTime(2026, 10, 3));
      expect(filters.modifiedBefore, DateTime(2026, 10, 3, 23, 59, 59, 999));
    });

    test('modified: understands the comparison operators', () {
      expect(
        SearchSyntax.parse('modified:>2026-01-01').filters.modifiedAfter,
        DateTime(2026, 1, 2),
      );
      expect(
        SearchSyntax.parse('modified:>=2026-01-01').filters.modifiedAfter,
        DateTime(2026, 1, 1),
      );
      expect(
        SearchSyntax.parse('modified:<2026-01-01').filters.modifiedBefore,
        DateTime(2025, 12, 31, 23, 59, 59, 999),
      );
      expect(
        SearchSyntax.parse('modified:<=2026-01-01').filters.modifiedBefore,
        DateTime(2026, 1, 1, 23, 59, 59, 999),
      );
    });

    test('modified: supports a sliding window', () {
      final now = DateTime(2026, 11, 7, 12);
      final filters = SearchSyntax.parse('modified:last7d', now: now).filters;
      expect(filters.modifiedAfter, now.subtract(const Duration(days: 7)));
      expect(filters.modifiedBefore, isNull);
    });

    test('modified: rejects impossible dates', () {
      final result = SearchSyntax.parse('modified:2026-02-30');
      expect(result.keywords, 'modified:2026-02-30');
      expect(result.filters.modifiedAfter, isNull);
      expect(result.filters.modifiedBefore, isNull);
    });

    test('unknown keys and invalid values stay in the keywords', () {
      final result = SearchSyntax.parse('foo:bar type:alien size:huge root:abc tag:x ext:a-b');
      expect(result.keywords, 'foo:bar type:alien size:huge root:abc tag:x ext:a-b');
      expect(result.filters.kinds, isEmpty);
      expect(result.filters.exts, isEmpty);
      expect(result.filters.tagIds, isEmpty);
      expect(result.filters.rootId, isNull);
      expect(result.filters.minSize, isNull);
    });

    test('leaves a URL in the keywords', () {
      final result = SearchSyntax.parse('see https://example.com/a.pdf');
      expect(result.keywords, 'see https://example.com/a.pdf');
    });

    test('combines filters with free text', () {
      final result = SearchSyntax.parse('合同 type:pdf size:>1kb 报告');
      expect(result.keywords, '合同 报告');
      expect(result.filters.kinds, <DocKind>{DocKind.pdf});
      expect(result.filters.minSize, 1025);
    });
  });
}
