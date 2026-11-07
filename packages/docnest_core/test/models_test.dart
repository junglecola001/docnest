import 'package:docnest_core/docnest_core.dart';
import 'package:test/test.dart';

void main() {
  test('PageOf.map keeps the cursor and empties are honestly empty', () {
    const page = PageOf<int>(items: [1, 2, 3], nextCursor: 'abc');
    final mapped = page.map((value) => 'd$value');
    expect(mapped.items, ['d1', 'd2', 'd3']);
    expect(mapped.nextCursor, 'abc');
    expect(mapped.hasMore, isTrue);

    const empty = PageOf<int>.empty();
    expect(empty.items, isEmpty);
    expect(empty.nextCursor, isNull);
    expect(empty.hasMore, isFalse);
  });

  test('DocQuery.cacheKey changes with every meaningful field', () {
    const base = DocQuery();
    final variants = <DocQuery>[
      base.copyWith(text: () => 'contract'),
      base.copyWith(rootId: () => const RootId(1)),
      base.copyWith(dirPath: () => 'Inbox'),
      base.copyWith(kinds: {DocKind.pdf}),
      base.copyWith(exts: {'docx'}),
      base.copyWith(tagIds: const [TagId(4)]),
      base.copyWith(favoritesOnly: true),
      base.copyWith(modifiedAfter: () => DateTime.utc(2026, 1, 1)),
      base.copyWith(minSize: () => 1024),
      base.copyWith(sort: SortField.size),
      base.copyWith(direction: SortDirection.descending),
      base.copyWith(limit: 25),
    ];
    final keys = {base.cacheKey, ...variants.map((q) => q.cacheKey)};
    expect(keys, hasLength(variants.length + 1));
  });

  test('DocQuery.cacheKey is stable for equal queries', () {
    expect(
      const DocQuery(text: 'a', kinds: {DocKind.pdf}).cacheKey,
      const DocQuery(text: 'a', kinds: {DocKind.pdf}).cacheKey,
    );
  });

  test('DocQuery.copyWith can clear nullable filters', () {
    final query = const DocQuery(text: 'x', rootId: RootId(9)).copyWith(text: () => null);
    expect(query.text, isNull);
    expect(query.rootId, const RootId(9));
  });

  test('DocEntry.dirPath handles root-level and nested files', () {
    DocEntry entry(String relPath) => DocEntry(
      id: const DocId(1),
      rootId: const RootId(1),
      relPath: relPath,
      name: relPath.split('/').last,
      ext: 'pdf',
      kind: DocKind.pdf,
      size: 1,
      modifiedAt: DateTime.utc(2026),
    );
    expect(entry('a.pdf').dirPath, '');
    expect(entry('Contracts/2026/a.pdf').dirPath, 'Contracts/2026');
  });

  test('TrashTicket expiry is inclusive of the deadline', () {
    final expires = DateTime.utc(2026, 11, 7, 12);
    final ticket = TrashTicket(token: 't', docIds: const [DocId(1)], expiresAt: expires);
    expect(ticket.isExpiredAt(expires.subtract(const Duration(seconds: 1))), isFalse);
    expect(ticket.isExpiredAt(expires), isTrue);
    expect(ticket.isExpiredAt(expires.add(const Duration(seconds: 1))), isTrue);
  });

  test('ScanProgress.fraction is null without a total and clamped', () {
    const unknown = ScanProgress(rootId: RootId(1), scanned: 10, total: 0, indexed: 1);
    expect(unknown.fraction, isNull);
    const partial = ScanProgress(rootId: RootId(1), scanned: 50, total: 100, indexed: 5);
    expect(partial.fraction, 0.5);
    const over = ScanProgress(rootId: RootId(1), scanned: 150, total: 100, indexed: 5);
    expect(over.fraction, 1.0);
  });

  test('wire ids reject garbage', () {
    expect(RootId.parse('12'), const RootId(12));
    expect(RootId.parse(3), const RootId(3));
    expect(() => RootId.parse('abc'), throwsFormatException);
    expect(() => DocId.parse(3.5), throwsFormatException);
    expect(() => UploadId.parse(''), throwsFormatException);
  });
}
