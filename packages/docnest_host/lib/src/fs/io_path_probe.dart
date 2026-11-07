import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../path/path_guard.dart';

/// [PathProbe] backed by `dart:io` plus two Win32 calls.
///
/// Two checks matter and neither can be answered from the path text alone:
///
///  * junctions are reported as ordinary directories by `dart:io`, so the
///    `FILE_ATTRIBUTE_REPARSE_POINT` bit is read with `GetFileAttributesW`;
///  * `resolveSymbolicLinksSync` calls `GetFinalPathNameByHandleW`, which is what
///    closes the check-then-use window (plan §3.9 item 4).
///
/// Canonical paths are only used for containment, never to *infer* a reparse
/// point: an 8.3 short name (`RUNNER~1`) or a `subst` drive resolves to a
/// different string without any link being involved.
class IoPathProbe implements PathProbe {
  const IoPathProbe();

  static const int _fileAttributeReparsePoint = 0x400;
  static const int _invalidFileAttributes = 0xFFFFFFFF;

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
    if (type == FileSystemEntityType.notFound) return false;
    if (type == FileSystemEntityType.link) return true;
    if (!Platform.isWindows) return false;
    final attributes = _attributesOf(fullPath);
    return attributes != _invalidFileAttributes && (attributes & _fileAttributeReparsePoint) != 0;
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

  static int _attributesOf(String fullPath) {
    final pointer = fullPath.toNativeUtf16();
    try {
      return _getFileAttributesW(pointer);
    } finally {
      malloc.free(pointer);
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

typedef _GetFileAttributesNative = Uint32 Function(Pointer<Utf16>);
typedef _GetFileAttributesDart = int Function(Pointer<Utf16>);

final _GetFileAttributesDart _getFileAttributesW = DynamicLibrary.process()
    .lookupFunction<_GetFileAttributesNative, _GetFileAttributesDart>('GetFileAttributesW');
