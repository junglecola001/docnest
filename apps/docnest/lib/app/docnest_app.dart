import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import 'appearance_controller.dart';
import 'routes.dart';
import 'shell_page.dart';

/// DocNest's root: the current appearance choices turned into prism's app.
///
/// The app listens to [appearanceProvider], so a swatch or a theme switch in
/// settings rebuilds both themes and the whole window with them. The locale is
/// pinned to Simplified Chinese for now; the English strings are already
/// registered and only wait for a language setting.
class DocNestApp extends ConsumerWidget {
  /// Creates the root widget.
  const DocNestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return DocNestAppRoot(
      home: const ShellPage(),
      theme: AppTheme.build(
        seed: appearance.seed,
        style: appearance.style,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.build(
        seed: appearance.seed,
        style: appearance.style,
        brightness: Brightness.dark,
      ),
      themeMode: appearance.mode,
      liquidGlass: appearance.glass,
      textScale: appearance.textScale,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      navigatorKey: AppRoutes.rootNavigatorKey,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
