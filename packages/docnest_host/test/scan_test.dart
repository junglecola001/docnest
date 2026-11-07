import 'dart:io';

import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_host/src/scan/index_store.dart';
import 'package:docnest_host/src/scan/reconciler.dart';
import 'package:docnest_host/src/scan/scanned_file.dart';
import 'package:docnest_host/src/scan/scanner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const RootId _rootId = RootId(1);

ScannedFile _scanned(String relPath, {int size = 100, DateTime? modifiedAt, String? fileId}) =>
    ScannedFile(
      relPath: relPath,
      size: size,
      modifiedAt: modifiedAt ?? DateTime(2026, 1, 1),
      fileId: fileId,
    );

IndexedDoc _indexed(
  int id,
  String relPath, {
  int size = 100,
  DateTime? modifiedAt,
  String? fileId,
  DocState state = DocState.active,
  RootId rootId = _rootId,
}) => IndexedDoc(
  id: DocId(id),
  rootId: rootId,
  relPath: relPath,
  size: size,
  modifiedAt: modifiedAt ?? DateTime(2026, 1, 1),
  fileId: fileId,
  state: state,
);

void main() {
  group('DirectoryScanner', () {
    late Directory temp;
    late String rootPath;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('docnest_scan_');
      rootPath = p.join(temp.path, 'Root');
      Directory(p.join(rootPath, 'sub', 'deep')).createSync(recursive: true);
      Directory(p.join(rootPath, '.git')).createSync(recursive: true);
      Directory(p.join(rootPath, '.docnest')).createSync(recursive: true);
      File(p.join(rootPath, 'a.pdf')).writeAsStringSync('a');
      File(p.join(rootPath, 'b.txt')).writeAsStringSync('b');
      File(p.join(rootPath, 'skip.tmp')).writeAsStringSync('tmp');
      File(p.join(rootPath, '.hidden.pdf')).writeAsStringSync('h');
      File(p.join(rootPath, '.git', 'x.pdf')).writeAsStringSync('x');
      File(p.join(rootPath, '.docnest', 'staging.pdf')).writeAsStringSync('s');
      File(p.join(rootPath, 'sub', 'c.docx')).writeAsStringSync('c');
      File(p.join(rootPath, 'sub', 'deep', 'd.md')).writeAsStringSync('d');
      File(p.join(rootPath, 'photo.png')).writeAsStringSync('png');
      File(p.join(rootPath, 'README')).writeAsStringSync('no extension');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Root rootFor({
      bool recursive = true,
      int? maxDepth,
      bool includeHidden = false,
      List<String> excludeGlobs = const <String>[],
      Set<String> includeExts = const <String>{},
    }) => Root(
      id: _rootId,
      path: rootPath,
      name: 'Test',
      recursive: recursive,
      maxDepth: maxDepth,
      includeHidden: includeHidden,
      includeExts: includeExts,
      excludeGlobs: excludeGlobs,
    );

    Set<String> pathsOf(ScanBatch batch) =>
        batch.files.map((ScannedFile file) => file.relPath).toSet();

    test('walks files in subfolders and applies the default excludes', () {
      final batch = DirectoryScanner(root: rootFor()).scan();

      expect(batch.completed, isTrue);
      expect(pathsOf(batch), <String>{'a.pdf', 'b.txt', 'sub/c.docx', 'sub/deep/d.md'});
      expect(batch.folders.map((ScannedFolder folder) => folder.relPath).toSet(), <String>{
        'sub',
        'sub/deep',
      });
      // Lock files, VCS metadata, the staging directory, extensions outside the
      // default set and files without an extension are all left out.
      expect(pathsOf(batch), isNot(contains('skip.tmp')));
      expect(pathsOf(batch), isNot(contains('.git/x.pdf')));
      expect(pathsOf(batch), isNot(contains('.docnest/staging.pdf')));
      expect(pathsOf(batch), isNot(contains('photo.png')));
      expect(pathsOf(batch), isNot(contains('README')));
    });

    test('reports the size and modification time from the file system', () {
      final batch = DirectoryScanner(root: rootFor()).scan();
      final file = batch.files.singleWhere((ScannedFile entry) => entry.relPath == 'b.txt');
      final stat = File(p.join(rootPath, 'b.txt')).statSync();

      expect(file.size, stat.size);
      expect(file.modifiedAt, stat.modified);
    });

    test('non-recursive scanning stops at the root files', () {
      final batch = DirectoryScanner(root: rootFor(recursive: false)).scan();

      expect(pathsOf(batch), <String>{'a.pdf', 'b.txt'});
      expect(batch.folders, isEmpty);
    });

    test('maxDepth limits how far down the walk goes', () {
      final oneLevel = DirectoryScanner(root: rootFor(maxDepth: 1)).scan();
      expect(pathsOf(oneLevel), <String>{'a.pdf', 'b.txt', 'sub/c.docx'});
      expect(oneLevel.folders.single.relPath, 'sub');

      final rootOnly = DirectoryScanner(root: rootFor(maxDepth: 0)).scan();
      expect(pathsOf(rootOnly), <String>{'a.pdf', 'b.txt'});
      expect(rootOnly.folders, isEmpty);
    });

    test('hidden files are excluded unless the root includes them', () {
      final hidden = DirectoryScanner(root: rootFor(includeHidden: true)).scan();
      expect(pathsOf(hidden), contains('.hidden.pdf'));

      final hiddenFolders = hidden.folders.map((ScannedFolder folder) => folder.relPath);
      expect(hiddenFolders, isNot(contains('.git')));
      expect(hiddenFolders, isNot(contains('.docnest')));
    });

    test('a root exclude glob prunes the whole subtree', () {
      final batch = DirectoryScanner(root: rootFor(excludeGlobs: <String>['sub/'])).scan();

      expect(pathsOf(batch), <String>{'a.pdf', 'b.txt'});
      expect(batch.folders, isEmpty);
    });

    test('images are indexed only when opted in', () {
      final withImages = DirectoryScanner(root: rootFor(), includeImages: true).scan();
      expect(pathsOf(withImages), contains('photo.png'));

      final onlyImages = DirectoryScanner(root: rootFor(includeExts: <String>{'.PNG'})).scan();
      expect(pathsOf(onlyImages), <String>{'photo.png'});
    });

    test('a missing root yields an incomplete empty batch', () {
      final batch = DirectoryScanner(
        root: Root(id: _rootId, path: p.join(temp.path, 'gone'), name: 'Gone'),
      ).scan();

      expect(batch.completed, isFalse);
      expect(batch.files, isEmpty);
      expect(batch.folders, isEmpty);
    });

    test('reports progress for every visited directory', () {
      final visited = <String>[];
      final batch = DirectoryScanner(
        root: rootFor(),
      ).scan(onProgress: (ScanProgressUpdate progress) => visited.add(progress.currentRelPath));

      expect(visited.first, isEmpty);
      expect(visited, containsAll(<String>['', 'sub', 'sub/deep']));
      expect(batch.completed, isTrue);
    });
  });

  group('planReconcile', () {
    test('same path and metadata is unchanged', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('a.pdf')],
        indexed: <IndexedDoc>[_indexed(1, 'a.pdf')],
      );

      expect(plan.unchanged, hasLength(1));
      expect(plan.unchanged.single.doc.id, const DocId(1));
      expect(plan.hasChanges, isFalse);
    });

    test('changed size or modification time is an update', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('a.pdf', size: 200, modifiedAt: DateTime(2026, 2, 2))],
        indexed: <IndexedDoc>[_indexed(1, 'a.pdf')],
      );

      expect(plan.updates, hasLength(1));
      expect(plan.updates.single.doc.id, const DocId(1));
      expect(plan.updates.single.file.size, 200);
      expect(plan.missing, isEmpty);
    });

    test('an unknown path is an insert', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('new.pdf')],
        indexed: const <IndexedDoc>[],
      );

      expect(plan.inserts, hasLength(1));
      expect(plan.inserts.single.file.relPath, 'new.pdf');
    });

    test('a file id matching a missing row is a move', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[
          _scanned('new.pdf', size: 200, fileId: 'f1', modifiedAt: DateTime(2026, 3, 3)),
        ],
        indexed: <IndexedDoc>[_indexed(5, 'old.pdf', fileId: 'f1', state: DocState.missing)],
      );

      expect(plan.inserts, isEmpty);
      expect(plan.moves, hasLength(1));
      final move = plan.moves.single;
      expect(move.doc.id, const DocId(5));
      expect(move.oldRelPath, 'old.pdf');
      expect(move.newRelPath, 'new.pdf');
      expect(plan.missing, isEmpty);
    });

    test('without a file id a new path is an insert and the missing row stays', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('new.pdf')],
        indexed: <IndexedDoc>[_indexed(5, 'old.pdf', state: DocState.missing)],
      );

      expect(plan.inserts, hasLength(1));
      expect(plan.moves, isEmpty);
      expect(plan.missing, isEmpty);
    });

    test('an active row at another path is not a move target', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('copy.pdf', fileId: 'f1')],
        indexed: <IndexedDoc>[_indexed(5, 'original.pdf', fileId: 'f1')],
      );

      expect(plan.moves, isEmpty);
      expect(plan.inserts, hasLength(1));
      expect(plan.missing, hasLength(1));
      expect(plan.missing.single.doc.id, const DocId(5));
    });

    test('unseen active rows become missing only after a completed scan', () {
      final partial = planReconcile(
        rootId: _rootId,
        scanned: const <ScannedFile>[],
        indexed: <IndexedDoc>[_indexed(1, 'a.pdf')],
        scanCompleted: false,
      );
      expect(partial.missing, isEmpty);
      expect(partial.hasChanges, isFalse);

      final complete = planReconcile(
        rootId: _rootId,
        scanned: const <ScannedFile>[],
        indexed: <IndexedDoc>[_indexed(1, 'a.pdf')],
      );
      expect(complete.missing, hasLength(1));
      expect(complete.missing.single.doc.id, const DocId(1));
    });

    test('an already missing row that is still absent produces nothing', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: const <ScannedFile>[],
        indexed: <IndexedDoc>[_indexed(1, 'gone.pdf', state: DocState.missing)],
      );

      expect(plan.actions, isEmpty);
    });

    test('a missing row that is back at the same path is reactivated', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('a.pdf')],
        indexed: <IndexedDoc>[_indexed(1, 'a.pdf', state: DocState.missing)],
      );

      expect(plan.updates, hasLength(1));
      expect(plan.unchanged, isEmpty);
    });

    test('rows of another root are neither reused nor marked missing', () {
      final plan = planReconcile(
        rootId: _rootId,
        scanned: <ScannedFile>[_scanned('a.pdf', fileId: 'f1')],
        indexed: <IndexedDoc>[_indexed(2, 'other.pdf', fileId: 'f1', rootId: const RootId(2))],
      );

      expect(plan.inserts, hasLength(1));
      expect(plan.moves, isEmpty);
      expect(plan.missing, isEmpty);
    });

    test('applying a plan twice yields only unchanged actions', () async {
      final store = MemoryIndexStore();
      await store.upsert(_indexed(1, 'same.pdf'));
      await store.upsert(_indexed(2, 'old.pdf', fileId: 'f1', state: DocState.missing));

      final scanned = <ScannedFile>[
        _scanned('same.pdf'),
        _scanned('new.pdf', size: 200, modifiedAt: DateTime(2026, 3, 3), fileId: 'f1'),
        _scanned('added.pdf', size: 300),
      ];
      final first = planReconcile(
        rootId: _rootId,
        scanned: scanned,
        indexed: await store.docsInRoot(_rootId),
      );
      expect(first.moves, hasLength(1));
      expect(first.inserts, hasLength(1));
      expect(first.unchanged, hasLength(1));
      await store.applyPlan(first);

      final moved = (await store.docsInRoot(
        _rootId,
      )).singleWhere((IndexedDoc doc) => doc.relPath == 'new.pdf');
      expect(moved.id, const DocId(2));
      expect(moved.state, DocState.active);
      expect(moved.fileId, 'f1');

      final second = planReconcile(
        rootId: _rootId,
        scanned: scanned,
        indexed: await store.docsInRoot(_rootId),
      );
      expect(second.hasChanges, isFalse);
      expect(second.unchanged, hasLength(3));
      expect(second.missing, isEmpty);
      expect(second.inserts, isEmpty);
      expect(second.moves, isEmpty);
      expect(second.updates, isEmpty);

      final before = await store.docsInRoot(_rootId);
      await store.applyPlan(second);
      expect(await store.docsInRoot(_rootId), before);
    });
  });

  group('MemoryIndexStore', () {
    test('lists rows of one root only', () async {
      final store = MemoryIndexStore();
      await store.upsert(_indexed(1, 'b.pdf'));
      await store.upsert(_indexed(2, 'a.pdf'));
      await store.upsert(_indexed(3, 'x.pdf', rootId: const RootId(2)));

      final docs = await store.docsInRoot(_rootId);
      expect(docs.map((IndexedDoc doc) => doc.relPath), <String>['a.pdf', 'b.pdf']);
    });

    test('finds a missing row by file id and ignores active rows', () async {
      final store = MemoryIndexStore();
      await store.upsert(_indexed(1, 'active.pdf', fileId: 'f1'));
      await store.upsert(_indexed(2, 'gone.pdf', fileId: 'f2', state: DocState.missing));

      expect(await store.findMissingByFileId(rootId: _rootId, fileId: 'f1'), isNull);
      final found = await store.findMissingByFileId(rootId: _rootId, fileId: 'f2');
      expect(found?.id, const DocId(2));
    });

    test('marks rows missing and removes them', () async {
      final store = MemoryIndexStore();
      await store.upsert(_indexed(1, 'a.pdf'));

      await store.markMissing(<DocId>[const DocId(1)]);
      expect((await store.docsInRoot(_rootId)).single.state, DocState.missing);

      await store.remove(<DocId>[const DocId(1)]);
      expect(await store.docsInRoot(_rootId), isEmpty);
    });
  });
}
