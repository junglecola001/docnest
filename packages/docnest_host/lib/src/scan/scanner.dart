import 'dart:io';

import 'package:docnest_core/docnest_core.dart';
import 'package:path/path.dart' as p;

import '../ext/doc_kind_map.dart';
import '../fs/default_excludes.dart';
import '../fs/exclude_globs.dart';
import 'scanned_file.dart';

/// Progress of a running scan, reported once per visited directory.
final class ScanProgressUpdate {
  const ScanProgressUpdate({
    required this.currentRelPath,
    required this.directoriesVisited,
    required this.filesSeen,
    required this.foldersSeen,
  });

  /// Directory being enumerated, `/`-separated; empty for the root itself.
  final String currentRelPath;

  /// Directories enumerated so far, including the root.
  final int directoriesVisited;

  /// Files accepted into the index so far.
  final int filesSeen;

  /// Folders accepted into the index so far.
  final int foldersSeen;
}

/// Everything one scan found.
final class ScanBatch {
  const ScanBatch({required this.files, required this.folders, required this.completed});

  /// Files whose extension is in the root's index set.
  final List<ScannedFile> files;

  /// Folders below the root that the scan entered.
  final List<ScannedFolder> folders;

  /// Whether the whole root was walked.
  ///
  /// False when the root is missing, or when any directory could not be
  /// listed (drive unplugged, access denied). The reconciler must not mark
  /// unseen rows missing in that case.
  final bool completed;

  /// Number of files found.
  int get fileCount => files.length;

  /// Number of folders found.
  int get folderCount => folders.length;

  @override
  String toString() =>
      'ScanBatch(${files.length} files, ${folders.length} folders, completed: $completed)';
}

/// Walks a [Root] on disk and turns it into a [ScanBatch].
///
/// The walk is breadth-first and synchronous: on Windows a directory listing
/// already returns size and timestamps, and the production FFI enumerator
/// (`FindFirstFileExW`) is synchronous too, so making this async would only add
/// noise. Callers run it on an isolate for large roots.
///
/// Safety rules baked in here:
///  * links and junctions are never followed (`followLinks: false`), so a scan
///    cannot leave the root or loop;
///  * `.docnest` is skipped even if the user removed it from the exclude list,
///    because it holds the trash and staging trees;
///  * default excludes (appendix B) always apply on top of the root's own
///    patterns, since Office lock files and VCS directories are never
///    documents.
final class DirectoryScanner {
  DirectoryScanner({required this.root, this.includeImages = false})
    : _extensions = resolveIndexExtensions(
        configured: root.includeExts,
        includeImages: includeImages,
      ),
      _excludes = ExcludeGlobs(<String>[...defaultExcludeGlobs, ...root.excludeGlobs]);

  /// Root being scanned; provides path, recursion and hidden-file policy.
  final Root root;

  /// Whether images are indexed for this scan (opt-in per root).
  final bool includeImages;

  final Set<String> _extensions;
  final ExcludeGlobs _excludes;

  /// Walks the root and returns everything worth reconciling.
  ///
  /// [onProgress] is called after each directory with the current path and
  /// running counts; the UI turns it into a progress line. A missing root
  /// yields an empty, incomplete batch instead of throwing, matching
  /// [RootStatus.offline] handling.
  ScanBatch scan({void Function(ScanProgressUpdate progress)? onProgress}) {
    final files = <ScannedFile>[];
    final folders = <ScannedFolder>[];
    var completed = true;

    if (!Directory(root.path).existsSync()) {
      return const ScanBatch(files: <ScannedFile>[], folders: <ScannedFolder>[], completed: false);
    }

    // `recursive: false` is a depth of zero: the root's own files, no subdirs.
    final maxDepth = root.recursive ? (root.maxDepth ?? -1) : 0;
    final pending = <_PendingDirectory>[const _PendingDirectory(<String>[], 0)];
    var visited = 0;

    for (var cursor = 0; cursor < pending.length; cursor++) {
      final directory = pending[cursor];
      final relPath = directory.segments.join('/');
      final fullPath = directory.segments.isEmpty
          ? root.path
          : p.joinAll(<String>[root.path, ...directory.segments]);
      final entries = _listSync(fullPath);
      if (entries == null) {
        completed = false;
        continue;
      }
      // Windows returns directory entries in name order, but that is not a
      // documented guarantee; sorting keeps plans and test expectations stable.
      entries.sort(
        (FileSystemEntity a, FileSystemEntity b) =>
            p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()),
      );

      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (name == '.docnest') continue;
        final isDirectory = entry is Directory;
        // Links and junctions are neither: skipping them is what makes
        // `followLinks: false` effective on Windows.
        if (!isDirectory && entry is! File) continue;

        final childRelPath = relPath.isEmpty ? name : '$relPath/$name';
        if (_excludes.matches(childRelPath, isDirectory: isDirectory)) continue;

        final hidden = _isHiddenName(name);
        if (hidden && !root.includeHidden) continue;

        if (isDirectory) {
          final depth = directory.depth + 1;
          if (maxDepth >= 0 && depth > maxDepth) continue;
          folders.add(ScannedFolder(relPath: childRelPath));
          pending.add(_PendingDirectory(<String>[...directory.segments, name], depth));
          continue;
        }

        final extension = _extensionOf(name);
        if (extension == null || !_extensions.contains(extension)) continue;
        // A file that vanished or is locked between listing and stat is
        // skipped; the next scan picks it up. That is not a failed scan.
        final stat = _statSync(entry.path);
        if (stat == null || stat.type == FileSystemEntityType.notFound) continue;
        files.add(
          ScannedFile(
            relPath: childRelPath,
            size: stat.size,
            modifiedAt: stat.modified,
            isHidden: hidden,
          ),
        );
      }

      visited++;
      onProgress?.call(
        ScanProgressUpdate(
          currentRelPath: relPath,
          directoriesVisited: visited,
          filesSeen: files.length,
          foldersSeen: folders.length,
        ),
      );
    }

    return ScanBatch(files: files, folders: folders, completed: completed);
  }

  static List<FileSystemEntity>? _listSync(String path) {
    try {
      return Directory(path).listSync(followLinks: false);
    } on FileSystemException {
      return null;
    }
  }

  static FileStat? _statSync(String path) {
    try {
      return FileStat.statSync(path);
    } on FileSystemException {
      return null;
    }
  }

  /// Dot-files are the portable part of "hidden".
  ///
  /// The Windows hidden/system attributes need `GetFileAttributesW`; until the
  /// `docnest_win32` lane exists they are not visible here, and the default
  /// excludes cover the usual offenders (`Thumbs.db`, `desktop.ini`).
  static bool _isHiddenName(String name) => name.startsWith('.');

  /// Lowercased extension, or null when [name] has none.
  static String? _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Directory queued for enumeration.
final class _PendingDirectory {
  const _PendingDirectory(this.segments, this.depth);

  /// Path segments below the root, in order.
  final List<String> segments;

  /// Depth relative to the root: 0 for the root itself.
  final int depth;
}
