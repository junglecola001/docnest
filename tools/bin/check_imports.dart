// Enforces the dependency rules from plan §6.4. Run from the repository root:
//
//   dart run tools/bin/check_imports.dart
//
// Exit code 1 lists every violation. Cheap on purpose: a text scan over
// `import`/`export` directives is enough for these rules and needs no analyzer.
import 'dart:io';

const _prismPackage = 'package:prism_ui';

/// Packages whose libraries must stay usable without Flutter or `dart:io`.
const _pureDartPackages = {'docnest_core', 'docnest_protocol'};

/// Files allowed to import Material (the bridge layer only).
const _materialBridgeDir = 'packages/docnest_ui/lib/src/bridge/';

/// Files allowed to branch on the platform (composition roots and the platform
/// probes that implement the injected interfaces).
const _platformAllowedSuffixes = [
  'apps/docnest/lib/main.dart',
  'apps/docnest/lib/app/bootstrap_host.dart',
  'apps/docnest/lib/app/bootstrap_remote.dart',
  'packages/docnest_host/lib/src/fs/io_path_probe.dart',
];

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

void main(List<String> args) {
  final root = Directory.current;
  final violations = <String>[];
  var checked = 0;

  for (final file in _dartFiles(root)) {
    final relative = _relative(root, file);
    checked++;
    final source = file.readAsStringSync();
    for (final match in _directive.allMatches(source)) {
      final uri = match.group(1)!;
      final rule = _violation(relative, uri, source);
      if (rule != null) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        violations.add('$relative:$line  $rule  ($uri)');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_imports: $checked files OK');
    return;
  }
  stderr.writeln('check_imports: ${violations.length} violation(s)\n');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exitCode = 1;
}

String? _violation(String relativePath, String uri, String source) {
  // 1. prism_ui may only be imported by docnest_ui.
  if (uri.startsWith(_prismPackage) && !relativePath.startsWith('packages/docnest_ui/')) {
    return 'only docnest_ui may import prism_ui';
  }

  // 2. Material is confined to the bridge.
  if (uri == 'package:flutter/material.dart' && !relativePath.startsWith(_materialBridgeDir)) {
    return 'flutter/material.dart is only allowed in docnest_ui/lib/src/bridge/';
  }

  // 3. core and protocol are pure Dart.
  final package = RegExp(r'^packages/([^/]+)/').firstMatch(relativePath)?.group(1);
  if (package != null && _pureDartPackages.contains(package)) {
    if (uri == 'dart:io' ||
        uri.startsWith('package:flutter/') ||
        uri == 'package:flutter_test/flutter_test.dart') {
      return '$package must stay free of Flutter and dart:io';
    }
  }

  // 4. domain must not import data.
  if (relativePath.contains('/domain/') && uri.contains('/data/')) {
    return 'domain layer must not depend on data layer';
  }

  // 5. Platform branches only in the composition roots.
  if (RegExp(r'Platform\.is(Windows|Android|Linux|MacOS|IOS)').hasMatch(source) &&
      !_platformAllowedSuffixes.any(relativePath.endsWith)) {
    return 'Platform.is* branch belongs in a bootstrap file';
  }

  return null;
}

Iterable<File> _dartFiles(Directory root) sync* {
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart')) continue;
    if (path.contains('/.dart_tool/') ||
        path.contains('/build/') ||
        path.contains('/.git/') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart')) {
      continue;
    }
    yield entity;
  }
}

String _relative(Directory root, File file) =>
    file.path.replaceAll(r'\', '/').replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');
