import 'package:docnest/app/appearance_settings.dart';
import 'package:docnest/app/docnest_app.dart';
import 'package:docnest/app/shell_page.dart';
import 'package:docnest/features/settings/settings_page.dart';
import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The color the whole window currently draws its primary role in.
///
/// Read from the shell's context, which sits under the theme the app root
/// resolved, so it is the same value every page receives.
Color _primaryOf(WidgetTester tester) {
  final context = tester.element(find.byType(ShellPage));
  return Theme.of(context).colorScheme.primary;
}

/// The brightness the window currently resolved, independent of the platform.
Brightness _brightnessOf(WidgetTester tester) {
  final context = tester.element(find.byType(ShellPage));
  return Theme.of(context).colorScheme.brightness;
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: DocNestApp()));
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationSidebar), matching: find.text('设置')).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four destinations and re-seeds the theme from a swatch', (tester) async {
    await _pumpApp(tester);

    for (final label in <String>['资料库', '搜索', '传输', '设置']) {
      expect(
        find.descendant(of: find.byType(NavigationSidebar), matching: find.text(label)),
        findsWidgets,
      );
    }

    final before = _primaryOf(tester);

    await _openSettings(tester);
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('appearance-seed-5')));
    await tester.pumpAndSettle();

    final expected = AppTheme.build(
      seed: AppearanceSettings.presetSeeds[5],
      style: ColorStyle.soft,
      brightness: Brightness.light,
    ).colorScheme.primary;
    expect(_primaryOf(tester), isNot(before));
    expect(_primaryOf(tester), expected);
  });

  testWidgets('switching theme mode to dark resolves the dark theme', (tester) async {
    await _pumpApp(tester);

    expect(_brightnessOf(tester), Brightness.light);

    await _openSettings(tester);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(_brightnessOf(tester), Brightness.dark);
  });
}
