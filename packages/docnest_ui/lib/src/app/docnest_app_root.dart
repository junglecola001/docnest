import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prism_ui/prism_ui.dart';

import '../l10n/docnest_ui_localizations.dart';
import '../theme/app_tokens.dart';

/// The root of every DocNest window, host or remote.
///
/// It is a thin, opinionated [PrismApp]: the delegates prism and Material need
/// are always registered, and a [ViewScope] is published from the ambient
/// [MediaQuery] so no page has to measure the window itself.
class DocNestAppRoot extends StatelessWidget {
  /// Wraps [PrismApp]; every parameter maps one to one onto it.
  const DocNestAppRoot({
    super.key,
    this.home,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.locale,
    this.supportedLocales = DocNestUiLocalizations.supportedLocales,
    this.navigatorKey,
    this.onGenerateRoute,
    this.liquidGlass,
    this.textScale,
    this.localizationsDelegates,
  });

  /// The first route, as [PrismApp.home].
  final Widget? home;

  /// The light theme; built by `AppTheme.light`.
  final ThemeData? theme;

  /// The dark theme; built by `AppTheme.dark`.
  final ThemeData? darkTheme;

  /// Which of the two is drawn; follows the platform by default.
  final ThemeMode themeMode;

  /// Forces a locale instead of following the platform.
  final Locale? locale;

  /// The locales the app promises to render; defaults to the two DocNest has
  /// strings for.
  final Iterable<Locale> supportedLocales;

  /// The key of the root navigator, for callers that push from outside.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Builds a route for names pushed at runtime.
  final RouteFactory? onGenerateRoute;

  /// Null draws no glass, which is the cheap option for an always-on host.
  final LiquidGlassQuality? liquidGlass;

  /// Null follows the platform's text scale.
  final double? textScale;

  /// Extra delegates, appended after the ones DocNest requires.
  ///
  /// The required ones come first so a caller cannot silently drop prism's own
  /// strings or the Material localizations pdfrx and markdown look up.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  @override
  Widget build(BuildContext context) {
    return PrismApp(
      navigatorKey: navigatorKey,
      home: home,
      onGenerateRoute: onGenerateRoute,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      textScale: textScale,
      liquidGlass: liquidGlass,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        DocNestUiLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        ...?localizationsDelegates,
      ],
      builder: _buildWithViewScope,
    );
  }

  /// Publishes the window size and the phone/desktop split above every route.
  ///
  /// [PrismApp] hands the builder the navigator, not the app's own content, so
  /// wrapping here is what puts the scope above the routes rather than beside
  /// them.
  static Widget _buildWithViewScope(BuildContext context, Widget? child) {
    final size = MediaQuery.sizeOf(context);
    return ViewScope(
      size: size,
      isMobile: size.width < AppBreakpoints.mobile,
      child: child ?? const SizedBox.shrink(),
    );
  }
}
