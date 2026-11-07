import 'dart:io';

import 'package:path/path.dart' as p;

import '../path/path_guard.dart';

/// [PathProbe] backed by `dart:io`.
///
/// On Windows, `resolveSymbolicLinksSync` is implemented with
/// `GetFinalPathNameByHandleW`, so the real-path check really is performed
/// against an opened handle rather than against the text we were given. That is
/// what closes the check-then-use window the plan calls out (§3.9 item 4).
class IoPathProbe implements PathProbe {
  const IoPathProbe();

  static const String _extendedPrefix = r'\\?\';
  static const String _extendedUncPrefix = r'\\?\UNC\';

  @override
  bool exists(String fullPath) =>
      FileSystemEntity.typeSync(fullPath, followLinks: false) != FileSystemEntityType.notFound;

  @override
  bool isDirectory(String fullPath) =>
      FileSystemEntity.typeSync(fullPath, followLinks: false) == FileSystemEntityType.directory;

  @override
  bool isReparsePoint(String fullPath) {
    final type = FileSystemEntity.typeSync(fullPath, followLinks: false);
    if (type == FileSystemEntityType.link) return true;
    if (type == FileSystemEntityType.notFound) return false;

    // A junction (or a mounted volume) is a directory whose canonical path
    // differs from the path used to reach it. Comparing canonical forms catches
    // both without an FFI dependency; `docnest_win32` later reports the real
    // FILE_ATTRIBUTE_REPARSE_POINT bit instead.
    final canonical = realPath(fullPath);
    if (canonical == null) return false;
    return !p.windows.equals(canonical, _stripExtendedPrefix(p.windows.normalize(fullPath)));
  }

  @override
  String? realPath(String fullPath) {
    try {
      final resolved = FileSystemEntity.isDirectorySync(fullPath)
          ? Directory(fullPath).resolveSymbolicLinksSync()
          : File(fullPath).resolveSymbolicLinksSync();
      return _stripExtendedPrefix(p.windows.normalize(resolved));
    } on FileSystemException {
      // Missing or unopened paths simply skip the extra check.
      return null;
    }
  }

  static String _stripExtendedPrefix(String path) {
    if (path.startsWith(_extendedUncPrefix)) {
      return r'\\' + path.substring(_extendedUncPrefix.length);
    }
    if (path.startsWith(_extendedPrefix)) return path.substring(_extendedPrefix.length);
    return path;
  }
}
