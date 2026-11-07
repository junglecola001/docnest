import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'appearance_settings.dart';

part 'appearance_controller.g.dart';

/// The appearance choices the running window is drawn with.
///
/// In-memory only. Persistence arrives with the settings table in M1, which
/// will seed [build] and write every change; until then this collection holds
/// no storage layer, real or fake, so nothing claims to have been saved.
@riverpod
class Appearance extends _$Appearance {
  @override
  AppearanceSettings build() => const AppearanceSettings();

  /// Seeds both themes from [seed]; the swatches pass preset values.
  void setSeed(Color seed) => state = state.copyWith(seed: seed);

  /// Switches prism's palette family.
  void setStyle(ColorStyle style) => state = state.copyWith(style: style);

  /// Follows the platform or pins one brightness.
  void setMode(ThemeMode mode) => state = state.copyWith(mode: mode);

  /// Chooses the window material; null draws no glass.
  void setGlass(LiquidGlassQuality? glass) =>
      state = state.copyWith(glass: glass, clearGlass: glass == null);

  /// Scales every font in the app, within the range the slider offers.
  void setTextScale(double textScale) => state = state.copyWith(textScale: textScale);
}
