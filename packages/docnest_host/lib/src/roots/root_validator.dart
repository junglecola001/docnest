import 'package:docnest_core/docnest_core.dart';
import 'package:path/path.dart' as p;

/// Why a folder cannot be added to the whitelist, or what the user must confirm
/// first.
enum RootIssue {
  /// The path is not absolute, or has no usable segments.
  invalidPath('invalidPath'),

  /// The path is a whole drive (`D:\`); allowed, but needs a second confirmation.
  driveRoot('driveRoot'),

  /// The path is inside a system or application directory that must never be
  /// whitelisted (`C:\Windows`, `AppData`, the app's own data directory, …).
  systemDirectory('systemDirectory'),

  /// The folder is already a root.
  alreadyAdded('alreadyAdded'),

  /// The new folder is inside an existing root: the user should be told it is
  /// already covered instead of nesting two roots.
  insideExistingRoot('insideExistingRoot'),

  /// The new folder contains one or more existing roots: the user should be
  /// offered a merge.
  containsExistingRoot('containsExistingRoot');

  const RootIssue(this.wire);

  /// Stable name used in diagnostics and tests.
  final String wire;
}

/// Outcome of validating a candidate folder.
class RootCheck {
  const RootCheck({required this.path, required this.issues, this.existingRoots = const []});

  /// Normalised absolute path that was checked.
  final String path;

  final List<RootIssue> issues;

  /// Existing roots the user should be told about, in the order they were found.
  final List<Root> existingRoots;

  /// Whether the folder may be added without asking the user anything.
  ///
  /// `containsExistingRoot` still allows the add; it only requires a merge
  /// confirmation, which the UI obtains from [RootIssue.driveRoot] and this
  /// flag. Everything else blocks the add outright.
  bool get canAdd => !issues.any(
    (issue) =>
        issue == RootIssue.invalidPath ||
        issue == RootIssue.systemDirectory ||
        issue == RootIssue.alreadyAdded ||
        issue == RootIssue.insideExistingRoot,
  );

  /// Issues the user must acknowledge before the add proceeds.
  bool get needsConfirmation =>
      issues.contains(RootIssue.driveRoot) || issues.contains(RootIssue.containsExistingRoot);

  bool get isClean => issues.isEmpty;

  @override
  String toString() => 'RootCheck($path, ${issues.map((i) => i.wire).join(',')})';
}

/// Validates candidate whitelist folders (plan §2.1 item A, "安全校验").
///
/// Pure and injectable: the system directories come from the caller so tests can
/// use a fake Windows layout without depending on the machine running them.
class RootValidator {
  RootValidator({
    required List<String> systemDirectories,
    List<String>? protectedNames,
  }) : _systemDirectories = systemDirectories.where((d) => d.isNotEmpty).toList(),
       _protectedNames = protectedNames ?? defaultProtectedNames;

  /// Directory names that may never appear as any segment of a whitelisted
  /// path, even if the user points at them through a junction-free path.
  static const List<String> defaultProtectedNames = <String>[
    'Windows',
    'Program Files',
    'Program Files (x86)',
    'ProgramData',
    'AppData',
    r'$RECYCLE.BIN',
    'System Volume Information',
  ];

  final List<String> _systemDirectories;
  final List<String> _protectedNames;

  /// Checks [candidatePath] against the already whitelisted [roots].
  RootCheck check({required String candidatePath, required Iterable<Root> roots}) {
    final trimmed = candidatePath.trim();
    if (trimmed.isEmpty || !p.windows.isAbsolute(trimmed)) {
      return RootCheck(
        path: trimmed,
        issues: const <RootIssue>[RootIssue.invalidPath],
      );
    }
    final path = p.windows.normalize(trimmed);
    final issues = <RootIssue>[];
    final related = <Root>[];

    if (p.windows.equals(path, p.windows.rootPrefix(path))) {
      issues.add(RootIssue.driveRoot);
    }

    if (_isUnderSystemDirectory(path)) issues.add(RootIssue.systemDirectory);
    if (_hasProtectedSegment(path)) issues.add(RootIssue.systemDirectory);

    for (final root in roots) {
      final rootPath = p.windows.normalize(root.path);
      if (p.windows.equals(rootPath, path)) {
        issues.add(RootIssue.alreadyAdded);
        related.add(root);
      } else if (p.windows.isWithin(rootPath, path)) {
        issues.add(RootIssue.insideExistingRoot);
        related.add(root);
      } else if (p.windows.isWithin(path, rootPath)) {
        issues.add(RootIssue.containsExistingRoot);
        related.add(root);
      }
    }

    return RootCheck(
      path: path,
      issues: List<RootIssue>.unmodifiable(issues),
      existingRoots: List<Root>.unmodifiable(related),
    );
  }

  bool _isUnderSystemDirectory(String path) {
    for (final directory in _systemDirectories) {
      if (!p.windows.isAbsolute(directory)) continue;
      final normalized = p.windows.normalize(directory);
      if (p.windows.equals(normalized, path) || p.windows.isWithin(normalized, path)) {
        return true;
      }
    }
    return false;
  }

  bool _hasProtectedSegment(String path) {
    final segments = p.windows.split(path);
    for (final segment in segments) {
      for (final name in _protectedNames) {
        if (segment.toLowerCase() == name.toLowerCase()) return true;
      }
    }
    return false;
  }
}
