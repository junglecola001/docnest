import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

import '../features/library/library_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/transfers/transfers_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'page_scaffold.dart';

/// One page the app can push at runtime.
///
/// The shell's four destinations are already in the tree; these routes exist
/// for pushes made from inside a page later on, and they carry the page they
/// open, so a caller says what it wants instead of naming a widget.
sealed class AppRoute {
  /// Const so callers can push without building a value first.
  const AppRoute();

  /// The page's name in its bar, localized by [l10n].
  String titleOf(AppLocalizations l10n);

  /// The page's content, without the bar the route wraps it in.
  Widget buildPage();

  /// Builds the route the window's size asks for.
  ///
  /// A phone slides a card in from the edge; a desktop window fades the page
  /// in place, so the sidebar and the page it opened stay on one surface.
  /// [context] must sit below the view scope the app root publishes above the
  /// navigator; the scope is what tells the two layouts apart.
  PageRoute<void> toRoute(BuildContext context) {
    final page = AppPageScaffold(title: titleOf(AppLocalizations.of(context)), child: buildPage());
    return context.isMobileView
        ? CardPageRoute<void>(builder: (_) => page)
        : FadePageRoute<void>(builder: (_) => page);
  }
}

/// Opens the library destination as a pushed page.
final class LibraryRoute extends AppRoute {
  /// Creates the route.
  const LibraryRoute();

  @override
  String titleOf(AppLocalizations l10n) => l10n.navLibrary;

  @override
  Widget buildPage() => const LibraryPage();
}

/// Opens the search destination as a pushed page.
final class SearchRoute extends AppRoute {
  /// Creates the route.
  const SearchRoute();

  @override
  String titleOf(AppLocalizations l10n) => l10n.navSearch;

  @override
  Widget buildPage() => const SearchPage();
}

/// Opens the transfers destination as a pushed page.
final class TransfersRoute extends AppRoute {
  /// Creates the route.
  const TransfersRoute();

  @override
  String titleOf(AppLocalizations l10n) => l10n.navTransfers;

  @override
  Widget buildPage() => const TransfersPage();
}

/// Opens settings, whether from a destination or from the shell.
final class SettingsRoute extends AppRoute {
  /// Creates the route.
  const SettingsRoute();

  @override
  String titleOf(AppLocalizations l10n) => l10n.navSettings;

  @override
  Widget buildPage() => const SettingsPage();
}

/// The app's route table and the key that reaches the root navigator.
abstract final class AppRoutes {
  /// The key the window's root navigator is registered under.
  ///
  /// It is handed to the app root so code outside a page — a deep link, a
  /// menu command — can push without a [BuildContext].
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Builds a route for an [AppRoute] passed as the push's `arguments`.
  ///
  /// Returns null for names this app does not own and for pushes made before
  /// the root navigator exists; those are programming errors the navigator
  /// reports, not states the app can render.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final route = settings.arguments;
    if (route is! AppRoute) {
      return null;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      return null;
    }
    return route.toRoute(context);
  }
}
