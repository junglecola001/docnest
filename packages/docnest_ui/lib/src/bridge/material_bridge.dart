// This is the only file in the workspace allowed to import Material; see
// `tools/bin/check_imports.dart`. Everything Material comes in prefixed so the
// prism names this package exports (`Theme`, `ThemeData`, `ColorScheme`,
// `Switch`, ...) are the ones in scope unprefixed.
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prism_ui/prism_ui.dart';

/// Hosts Material widgets — pdfrx's viewer, a markdown renderer — under a
/// [PrismApp], which installs neither of the two things they look up.
///
/// A Material widget reads its colours from Material's own theme and its
/// words from `MaterialLocalizations`; under a Prism app both are absent, and
/// the widget either throws or falls back to bare black-on-white. This bridge
/// supplies exactly those two, and nothing else, so the surrounding prism
/// chrome is untouched:
///
/// * a Material theme seeded from the ambient prism [ColorScheme], so the two
///   never disagree about the accent, the surface or the error colour;
/// * the global Material, Widgets and Cupertino delegates, re-registered
///   locally so the subtree works even when the app root omitted them.
class MaterialBridge extends StatelessWidget {
  /// Wraps [child] in the Material theme and localizations it expects.
  const MaterialBridge({super.key, required this.child});

  /// The Material-rendered subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = material.ThemeData(
      brightness: scheme.brightness,
      // Generated, then corrected on the roles a document viewer actually
      // paints with: a seeded scheme's own surface is close to, but not, the
      // prism one behind it, and the mismatch shows at the page edges.
      colorScheme:
          material.ColorScheme.fromSeed(
            seedColor: scheme.primary,
            brightness: scheme.brightness,
          ).copyWith(
            primary: scheme.primary,
            onPrimary: scheme.onPrimary,
            surface: scheme.surface,
            onSurface: scheme.onSurface,
            error: scheme.error,
            onError: scheme.onError,
          ),
    );
    return material.Theme(
      data: theme,
      child: Localizations.override(
        context: context,
        delegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Transparency leaves the prism surface showing through; Material only
        // needs to be an ancestor so ink and text defaults resolve.
        child: material.Material(type: material.MaterialType.transparency, child: child),
      ),
    );
  }
}
