/// DocNest's shared UI layer.
///
/// This is the only library application code imports: it re-exports
/// `package:prism_ui/prism_ui.dart` so no other package ever names prism
/// directly, and adds the DocNest-specific theme, localization and scaffold
/// pieces on top. `tools/bin/check_imports.dart` enforces the rule.
///
/// Prism's `ThemeData`, `ThemeMode`, `ColorScheme`, `Switch` and friends share
/// their names with Material's, which is why DocNest never imports
/// `package:flutter/material.dart` outside `src/bridge/`; both cannot be in
/// scope together at an unprefixed name.
library;

export 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue;
export 'package:prism_ui/prism_ui.dart';

export 'src/app/docnest_app_root.dart';
export 'src/bridge/material_bridge.dart';
export 'src/components/async_view.dart';
export 'src/icons/app_glyphs.dart';
export 'src/l10n/docnest_ui_localizations.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/app_tokens.dart';
