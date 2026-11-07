/// Case-insensitive glob matching for per-root exclude patterns.
library;

/// Matches paths against the exclude patterns stored on a root.
///
/// Supported syntax, matching the defaults in the plan's appendix B:
///  * `*` any run of characters except `/`
///  * `?` one character except `/`
///  * `**` any run of characters including `/`
///  * a trailing `/` marks a directory: the pattern then matches that
///    directory and everything below it
///  * a pattern without `/` matches a name in any directory, so `node_modules/`
///    and `~$*` work at every depth
class ExcludeGlobs {
  ExcludeGlobs(Iterable<String> patterns) : _patterns = patterns.map(_compile).toList();

  final List<_CompiledGlob> _patterns;

  bool get isEmpty => _patterns.isEmpty;

  /// [relPath] is `/`-separated and relative to the root.
  ///
  /// [isDirectory] is accepted for call sites that know the kind, but the
  /// answer never depends on it: a file below an excluded directory is
  /// excluded too, so unseen files cannot slip through.
  bool matches(String relPath, {bool isDirectory = false}) {
    if (_patterns.isEmpty || relPath.isEmpty) return false;
    for (final pattern in _patterns) {
      if (pattern.regExp.hasMatch(relPath)) return true;
      if (!pattern.matchesDirectoryOnly) continue;
      // Directory pattern: walk the ancestors so `.git/` also hides
      // `.git/config`.
      var candidate = relPath;
      while (true) {
        final index = candidate.lastIndexOf('/');
        if (index <= 0) break;
        candidate = candidate.substring(0, index);
        if (pattern.regExp.hasMatch(candidate)) return true;
      }
    }
    return false;
  }

  static _CompiledGlob _compile(String raw) {
    var pattern = raw.trim();
    var directoryOnly = false;
    if (pattern.endsWith('/')) {
      directoryOnly = true;
      pattern = pattern.substring(0, pattern.length - 1);
    }
    if (pattern.startsWith('./')) pattern = pattern.substring(2);
    final anchored = pattern.contains('/');
    final body = _translate(pattern);
    final prefix = anchored ? '^' : r'(^|.*/)';
    return _CompiledGlob(
      RegExp('$prefix$body\$', caseSensitive: false),
      matchesDirectoryOnly: directoryOnly,
    );
  }

  static String _translate(String pattern) {
    final buffer = StringBuffer();
    for (var i = 0; i < pattern.length; i++) {
      final char = pattern[i];
      switch (char) {
        case '*':
          if (i + 1 < pattern.length && pattern[i + 1] == '*') {
            buffer.write('.*');
            i++;
          } else {
            buffer.write('[^/]*');
          }
        case '?':
          buffer.write('[^/]');
        default:
          buffer.write(RegExp.escape(char));
      }
    }
    return buffer.toString();
  }
}

class _CompiledGlob {
  const _CompiledGlob(this.regExp, {required this.matchesDirectoryOnly});

  final RegExp regExp;
  final bool matchesDirectoryOnly;
}
