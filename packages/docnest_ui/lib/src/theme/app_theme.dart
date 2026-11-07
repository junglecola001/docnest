import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// The single place DocNest builds its Prism theme.
///
/// Every surface in the app — host windows and the remote client alike — comes
/// from here, so a seed or style change moves the whole product at once instead
/// of drifting between screens.
abstract final class AppTheme {
  /// The blue DocNest ships with; callers override it for per-user accents.
  static const Color defaultSeed = Color(0xFF007AFF);

  /// Families to fall back to when the platform font lacks a glyph.
  ///
  /// DocNest titles are frequently Chinese; Segoe UI and SF Pro cover Latin
  /// only, and a missing family falls through to the next entry per glyph, so
  /// the three CJK faces are appended after the platform's own.
  static const List<String> fontFamilyFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
  ];

  /// Builds the theme [brightness] calls for on [seed].
  ///
  /// [style] is prism's palette family; the app keeps one style for both
  /// brightnesses so light and dark stay recognisably the same product.
  static ThemeData build({
    required Color seed,
    required ColorStyle style,
    required Brightness brightness,
  }) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness, style: style),
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  /// The light theme, soft-toned on [seed] unless the caller says otherwise.
  static ThemeData light({Color seed = defaultSeed, ColorStyle style = ColorStyle.soft}) =>
      build(seed: seed, style: style, brightness: Brightness.light);

  /// The dark theme, soft-toned on [seed] unless the caller says otherwise.
  static ThemeData dark({Color seed = defaultSeed, ColorStyle style = ColorStyle.soft}) =>
      build(seed: seed, style: style, brightness: Brightness.dark);
}
