import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance_controller.dart';
import '../../app/appearance_settings.dart';
import '../../l10n/generated/app_localizations.dart';

/// The settings destination: the appearance choices the app currently draws.
///
/// Every control writes to [appearanceProvider], so the whole shell and every
/// page change together while the list scrolls. The page shows what the app
/// actually does; it offers no switch the app cannot honour.
class SettingsPage extends ConsumerWidget {
  /// Creates the settings destination's content.
  const SettingsPage({super.key});

  /// The version this build reports; kept in step with `pubspec.yaml`'s
  /// `version` by hand until the build stamps it.
  static const String appVersion = '0.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appearanceProvider);
    final appearance = ref.read(appearanceProvider.notifier);
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxxl),
      children: [
        _SectionHeader(l10n.settingsAppearance),
        ListRow(
          title: Text(l10n.settingsAccentColor),
          subtitle: Text(l10n.settingsAccentColorHint),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (index, seed) in AppearanceSettings.presetSeeds.indexed)
                _SeedSwatch(
                  key: ValueKey<String>('appearance-seed-$index'),
                  seed: seed,
                  selected: seed == settings.seed,
                  label: '${l10n.settingsAccentColor} ${index + 1}',
                  onPressed: () => appearance.setSeed(seed),
                ),
            ],
          ),
        ),
        const Divider(),
        ListRow(title: Text(l10n.settingsColorStyle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SegmentedControl<ColorStyle>(
            segments: <(ColorStyle, String)>[
              (ColorStyle.vivid, l10n.styleVivid),
              (ColorStyle.tinted, l10n.styleTinted),
              (ColorStyle.soft, l10n.styleSoft),
              (ColorStyle.monochrome, l10n.styleMonochrome),
            ],
            value: settings.style,
            onChanged: appearance.setStyle,
          ),
        ),
        ListRow(title: Text(l10n.settingsThemeMode)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SegmentedControl<ThemeMode>(
            segments: <(ThemeMode, String)>[
              (ThemeMode.system, l10n.themeSystem),
              (ThemeMode.light, l10n.themeLight),
              (ThemeMode.dark, l10n.themeDark),
            ],
            value: settings.mode,
            onChanged: appearance.setMode,
          ),
        ),
        ListRow(title: Text(l10n.settingsGlass)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SegmentedControl<LiquidGlassQuality?>(
            segments: <(LiquidGlassQuality?, String)>[
              (null, l10n.settingsGlassOff),
              (LiquidGlassQuality.standard, l10n.settingsGlassStandard),
              (LiquidGlassQuality.ultra, l10n.settingsGlassUltra),
            ],
            value: settings.glass,
            onChanged: appearance.setGlass,
          ),
        ),
        ListRow(
          title: Text(l10n.settingsTextScale),
          trailing: Text('${settings.textScale.toStringAsFixed(1)}×'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Slider(
            value: settings.textScale,
            min: 0.8,
            max: 1.6,
            divisions: 8,
            label: '${settings.textScale.toStringAsFixed(1)}×',
            onChanged: appearance.setTextScale,
          ),
        ),
        const Divider(),
        _SectionHeader(l10n.settingsAbout),
        ListRow(title: Text(l10n.appTitle), trailing: Text(l10n.settingsVersion(appVersion))),
      ],
    );
  }
}

/// A group heading inside the settings list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      child: Text(
        label,
        style: AppTextStyle.footnote
            .of(context, emphasized: true)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// One tappable accent color, ringed when the app is using it.
class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    super.key,
    required this.seed,
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final Color seed;
  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      container: true,
      child: PressSurface(
        fill: seed,
        shape: AppShape.full,
        side: BorderSide(
          color: selected ? colorScheme.onSurface : colorScheme.outlineVariant,
          width: selected ? 2.5 : 1,
        ),
        ringStandsOff: true,
        selected: selected,
        onPressed: onPressed,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: const SizedBox.square(dimension: 28),
      ),
    );
  }
}
