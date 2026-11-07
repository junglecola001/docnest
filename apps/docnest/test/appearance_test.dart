import 'package:docnest/app/appearance_controller.dart';
import 'package:docnest/app/appearance_settings.dart';
import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts from the shipped defaults', () {
    final container = ProviderContainer.test();

    expect(container.read(appearanceProvider), const AppearanceSettings());
  });

  test('every setter replaces its field and keeps the rest', () {
    final container = ProviderContainer.test();
    // The app root watches the provider for its lifetime; the test does too,
    // so the auto-dispose notifier is not dropped mid-test.
    final subscription = container.listen(appearanceProvider, (_, _) {});
    addTearDown(subscription.close);
    final appearance = container.read(appearanceProvider.notifier);

    appearance.setSeed(AppearanceSettings.presetSeeds[2]);
    expect(container.read(appearanceProvider).seed, AppearanceSettings.presetSeeds[2]);

    appearance.setStyle(ColorStyle.vivid);
    expect(container.read(appearanceProvider).style, ColorStyle.vivid);

    appearance.setMode(ThemeMode.dark);
    expect(container.read(appearanceProvider).mode, ThemeMode.dark);

    appearance.setGlass(LiquidGlassQuality.ultra);
    expect(container.read(appearanceProvider).glass, LiquidGlassQuality.ultra);

    appearance.setTextScale(1.3);
    final changed = container.read(appearanceProvider);
    expect(changed.textScale, 1.3);
    expect(changed.seed, AppearanceSettings.presetSeeds[2]);
    expect(changed.style, ColorStyle.vivid);
    expect(changed.mode, ThemeMode.dark);
    expect(changed.glass, LiquidGlassQuality.ultra);
  });

  test('clearing the glass keeps the other choices', () {
    final container = ProviderContainer.test();
    final subscription = container.listen(appearanceProvider, (_, _) {});
    addTearDown(subscription.close);
    final appearance = container.read(appearanceProvider.notifier);

    appearance.setGlass(LiquidGlassQuality.standard);
    appearance.setMode(ThemeMode.light);
    appearance.setGlass(null);

    final settings = container.read(appearanceProvider);
    expect(settings.glass, isNull);
    expect(settings.mode, ThemeMode.light);
  });
}
