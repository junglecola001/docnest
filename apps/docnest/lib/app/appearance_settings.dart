import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

/// Everything the user can tune about how DocNest looks.
///
/// One immutable value describes the whole app: both themes derive from
/// [seed], [style] and the chosen [mode], the window material from [glass],
/// and every page's type size from [textScale]. Keeping the choices together
/// means a settings change repaints every surface at once instead of drifting
/// between the shell and the pages inside it.
@immutable
class AppearanceSettings {
  /// Creates a set of choices; every field defaults to what DocNest ships.
  const AppearanceSettings({
    this.seed = AppTheme.defaultSeed,
    this.style = ColorStyle.soft,
    this.mode = ThemeMode.system,
    this.glass,
    this.textScale = 1,
  });

  /// The colors offered as one-tap accents.
  ///
  /// These are the hues Apple's system palette uses for its own accents, so a
  /// user coming from iOS or macOS recognises them; plain constants because the
  /// swatches must be comparable and const.
  static const List<Color> presetSeeds = <Color>[
    AppTheme.defaultSeed,
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF30B0C7),
    Color(0xFF8E8E93),
  ];

  /// The hue both themes are seeded from; [AppTheme.defaultSeed] until changed.
  final Color seed;

  /// Prism's palette family: vivid, tinted, soft or monochrome.
  final ColorStyle style;

  /// Which of the two themes is drawn, or the platform's choice.
  final ThemeMode mode;

  /// The window material; null draws no glass, which is the cheap option.
  final LiquidGlassQuality? glass;

  /// Multiplies every font size; 1 uses the size the design specifies.
  final double textScale;

  /// Returns a copy with the given fields replaced.
  ///
  /// [glass] is nullable, so clearing it needs [clearGlass] rather than null:
  /// null means "keep the current material" like every other field.
  AppearanceSettings copyWith({
    Color? seed,
    ColorStyle? style,
    ThemeMode? mode,
    LiquidGlassQuality? glass,
    bool clearGlass = false,
    double? textScale,
  }) {
    return AppearanceSettings(
      seed: seed ?? this.seed,
      style: style ?? this.style,
      mode: mode ?? this.mode,
      glass: clearGlass ? null : glass ?? this.glass,
      textScale: textScale ?? this.textScale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppearanceSettings &&
        other.seed == seed &&
        other.style == style &&
        other.mode == mode &&
        other.glass == glass &&
        other.textScale == textScale;
  }

  @override
  int get hashCode => Object.hash(seed, style, mode, glass, textScale);

  @override
  String toString() =>
      'AppearanceSettings(seed: $seed, style: $style, mode: $mode, '
      'glass: $glass, textScale: $textScale)';
}
