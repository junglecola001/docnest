import 'package:docnest_core/docnest_core.dart';
import 'package:path/path.dart' as p;

import 'resolved_path.dart';

/// Minimal file-system surface the guard needs.
///
/// Implemented by `docnest_win32` on Windows (junctions, `GetFinalPathNameByHandleW`)
/// and by a `dart:io` probe in tests. Injecting it keeps [PathGuard] pure and
/// lets the contract tests simulate reparse-point escapes.
abstract interface class PathProbe {
  /// Whether [fullPath] exists (files, directories, links).
  bool exists(String fullPath);

  /// Whether [fullPath] resolves to a directory. Links are not followed.
  bool isDirectory(String fullPath);

  /// Whether [fullPath] itself is a reparse point (symlink or junction).
  bool isReparsePoint(String fullPath);

  /// Real path of an opened handle, used to close the check-then-use window.
  ///
  /// Returns `null` when the path cannot be opened.
  String? realPath(String fullPath);
}

/// Probe that reports nothing: [PathGuard.resolve] then performs the pure
/// lexical checks only.
class NoopPathProbe implements PathProbe {
  const NoopPathProbe();

  @override
  bool exists(String fullPath) => false;

  @override
  bool isDirectory(String fullPath) => false;

  @override
  bool isReparsePoint(String fullPath) => false;

  @override
  String? realPath(String fullPath) => null;
}

/// The only entry point for turning `(rootId, relative path)` into a file path.
///
/// Every rule here exists to stop remote input from reaching outside a
/// whitelisted folder; see plan §3.9 item 4. Never bypass it, and never accept
/// an absolute path from a client.
class PathGuard {
  const PathGuard({PathProbe probe = const NoopPathProbe()}) : _probe = probe;

  final PathProbe _probe;

  /// Characters Windows refuses in a name.
  static final RegExp _illegalChars = RegExp(r'[<>:"|?*]');

  /// Device names that are reserved even with an extension (`CON.txt`).
  ///
  /// Also covers the superscript digits Windows treats as `1`–`9`.
  static final RegExp _reservedName = RegExp(
    r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(\..*)?$',
    caseSensitive: false,
  );

  /// Percent-encoded dot segments, in case an upstream layer already decoded
  /// once too often. A real file literally named `%2e%2e` is refused: the
  /// ambiguity is not worth the risk.
  static final RegExp _encodedDot = RegExp(r'^%2e(%2e)?$', caseSensitive: false);

  static final RegExp _drivePrefix = RegExp(r'^[A-Za-z]:');

  /// Validates [relPath] against [root] and returns the absolute path.
  ///
  /// Throws [InvalidNameException] for a segment Windows cannot represent and
  /// [PathOutsideRootException] for anything that tries to escape the root.
  ResolvedPath resolve(Root root, String relPath) {
    final segments = _segmentsOf(relPath);
    final rootPath = _normalizedRootPath(root);
    final full = segments.isEmpty
        ? rootPath
        : p.windows.normalize(p.windows.joinAll([rootPath, ...segments]));
    if (!p.windows.isWithin(rootPath, full) && !p.windows.equals(rootPath, full)) {
      throw PathOutsideRootException(
        message: 'Path escapes its root',
        details: {'rootId': root.id.value, 'relPath': relPath},
      );
    }
    final rel = segments.join('/');
    if (!root.followLinks) _checkNoReparsePoints(rootPath, segments, root, relPath);
    _checkRealPath(rootPath, full, root, relPath);
    return ResolvedPath(root: root, relPath: rel, fullPath: full);
  }

  /// Like [resolve], then refuses the path when the caller may not write.
  ResolvedPath resolveWritable(Root root, String relPath) {
    if (!root.writable) {
      throw ReadOnlyException(
        message: 'Root "${root.name}" is read-only',
        details: {'rootId': root.id.value},
      );
    }
    if (!root.status.isOnline) {
      throw RootOfflineException(rootId: root.id.value);
    }
    return resolve(root, relPath);
  }

  /// Validates a single user-supplied file or folder name (no separators).
  ///
  /// Returns the name unchanged; use `NameSanitizer` when the goal is to make
  /// an arbitrary name representable rather than to reject it.
  String resolveName(String name) {
    final segments = _segmentsOf(name);
    if (segments.length != 1 || segments.single != name) {
      throw InvalidNameException(
        message: 'Expected a single path segment',
        details: {'name': name},
      );
    }
    return name;
  }

  List<String> _segmentsOf(String relPath) {
    if (relPath.isEmpty) return const <String>[];
    if (relPath.contains('\u0000')) {
      throw const InvalidNameException(message: 'Name contains a NUL byte');
    }
    // Absolute paths, drive letters, UNC (`\\server\share`) and `\\?\` prefixes
    // are all rejected before splitting, so `\\server\share` cannot look like
    // two innocent segments.
    if (relPath.startsWith('/') || relPath.startsWith(r'\')) {
      throw PathOutsideRootException(
        message: 'Absolute paths are not accepted',
        details: {'relPath': relPath},
      );
    }
    if (_drivePrefix.hasMatch(relPath)) {
      throw PathOutsideRootException(
        message: 'Drive-qualified paths are not accepted',
        details: {'relPath': relPath},
      );
    }
    if (relPath.contains(':')) {
      // Also blocks alternate data streams such as `report.pdf:hidden`.
      throw InvalidNameException(
        message: 'Colons and alternate data streams are not accepted',
        details: {'relPath': relPath},
      );
    }
    final segments = <String>[];
    for (final raw in relPath.split(RegExp(r'[\\/]+'))) {
      if (raw.isEmpty) continue;
      if (raw == '.' || raw == '..') {
        throw PathOutsideRootException(
          message: 'Relative traversal is not accepted',
          details: {'relPath': relPath},
        );
      }
      if (_encodedDot.hasMatch(raw)) {
        throw PathOutsideRootException(
          message: 'Encoded traversal is not accepted',
          details: {'relPath': relPath},
        );
      }
      if (raw.endsWith('.') || raw.endsWith(' ')) {
        throw InvalidNameException(
          message: 'Names may not end with a dot or a space',
          details: {'segment': raw},
        );
      }
      if (_illegalChars.hasMatch(raw)) {
        throw InvalidNameException(
          message: 'Name contains a character Windows does not allow',
          details: {'segment': raw},
        );
      }
      if (raw.codeUnits.any((unit) => unit < 0x20)) {
        throw InvalidNameException(
          message: 'Name contains a control character',
          details: {'segment': raw},
        );
      }
      if (_reservedName.hasMatch(raw)) {
        throw InvalidNameException(
          message: 'Name is reserved by Windows',
          details: {'segment': raw},
        );
      }
      segments.add(raw);
    }
    return segments;
  }

  String _normalizedRootPath(Root root) {
    if (!p.windows.isAbsolute(root.path)) {
      throw InvalidRequestException(
        message: 'Root path is not absolute',
        details: {'rootId': root.id.value},
      );
    }
    return p.windows.normalize(root.path);
  }

  void _checkNoReparsePoints(String rootPath, List<String> segments, Root root, String relPath) {
    var current = rootPath;
    for (final segment in segments) {
      current = p.windows.join(current, segment);
      if (_probe.isReparsePoint(current)) {
        throw PathOutsideRootException(
          message: 'Path crosses a link or junction',
          details: {'rootId': root.id.value, 'relPath': relPath},
        );
      }
    }
  }

  void _checkRealPath(String rootPath, String full, Root root, String relPath) {
    final real = _probe.realPath(full);
    if (real == null) return;
    final normalizedReal = p.windows.normalize(real);
    if (!p.windows.isWithin(rootPath, normalizedReal) &&
        !p.windows.equals(rootPath, normalizedReal)) {
      throw PathOutsideRootException(
        message: 'Resolved path escapes its root',
        details: {'rootId': root.id.value, 'relPath': relPath},
      );
    }
  }
}
