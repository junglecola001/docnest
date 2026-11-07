import 'package:prism_ui/icons/glyph.dart';

/// DocNest's own icons, drawn on prism's 24 pt glyph grid.
///
/// Prism ships only the glyphs its components paint themselves; the product's
/// four destinations and the actions around them are DocNest's to name. Every
/// shape is a stroked [GlyphPath] at [Glyph.strokeWidth], so swapping a glyph
/// changes the picture and never the drawing style, and filling one on
/// selection thickens its lines instead of turning it into a silhouette.
///
/// The path data is taken from [Lucide](https://lucide.dev), which publishes
/// it under the ISC license.
abstract final class AppGlyphs {
  /// Open books on a shelf; the library destination.
  static const Glyph library = Glyph([
    GlyphPath('m16 6 4 14M12 6v14M8 8v12M4 4v16', role: GlyphRole.line),
  ]);

  /// A magnifier; the search destination.
  static const Glyph search = Glyph([
    GlyphPath('M21 21l-4.3-4.3M19 11a8 8 0 1 1-16 0a8 8 0 0 1 16 0', role: GlyphRole.line),
  ]);

  /// Two arrows passing each other; the transfers destination.
  static const Glyph transfers = Glyph([
    GlyphPath('M8 3 4 7l4 4M4 7h16m-4 14 4-4-4-4M20 17H4', role: GlyphRole.line),
  ]);

  /// Sliders; the settings destination.
  static const Glyph settings = Glyph([
    GlyphPath(
      'M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3M14 2v4M8 10v4M16 18v4',
      role: GlyphRole.line,
    ),
  ]);

  /// A folder; a library entry that holds documents.
  static const Glyph folder = Glyph([
    GlyphPath(
      'M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9'
      'A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z',
      role: GlyphRole.line,
    ),
  ]);

  /// A page with ruled lines; a document.
  static const Glyph fileText = Glyph([
    GlyphPath(
      'M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'
      'M14 2v4a2 2 0 0 0 2 2h4M10 9H8M16 13H8M16 17H8',
      role: GlyphRole.line,
    ),
  ]);

  /// A cross; the action that adds something to the library.
  static const Glyph plus = Glyph([GlyphPath('M5 12h14M12 5v14', role: GlyphRole.line)]);
}
