import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

import '../features/library/library_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/transfers/transfers_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'page_scaffold.dart';
import 'routes.dart';

/// The window's frame: four destinations, and the navigation that reaches them.
///
/// A wide window keeps a sidebar beside the page; a narrow one moves the same
/// destinations into a dock over the page's foot. Either way each destination
/// owns a [Navigator], so opening a page in the library leaves search's stack
/// where the user left it when they switch away and back (ADR 0005).
class ShellPage extends StatefulWidget {
  /// Creates the shell.
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// The area the system's window buttons cover at the sidebar's top start.
  static const Size _windowControls = Size(138, 40);

  int _selected = 0;
  bool _expanded = true;

  /// One navigator per destination, kept alive by the [IndexedStack] below.
  late final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(_pages.length, (_) => GlobalKey<NavigatorState>());

  static const List<Widget> _pages = <Widget>[
    LibraryPage(),
    SearchPage(),
    TransfersPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = <String>[l10n.navLibrary, l10n.navSearch, l10n.navTransfers, l10n.navSettings];
    final stack = IndexedStack(
      index: _selected,
      children: <Widget>[
        for (final (index, page) in _pages.indexed)
          _DestinationNavigator(
            navigatorKey: _navigatorKeys[index],
            title: titles[index],
            page: page,
          ),
      ],
    );
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobile) {
      return Stack(
        children: <Widget>[
          Positioned.fill(child: stack),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationDock(
              destinations: <NavigationDockDestination>[
                NavigationDockDestination(glyph: AppGlyphs.library, label: titles[0]),
                NavigationDockDestination(glyph: AppGlyphs.search, label: titles[1]),
                NavigationDockDestination(glyph: AppGlyphs.transfers, label: titles[2]),
                NavigationDockDestination(glyph: AppGlyphs.settings, label: titles[3]),
              ],
              selectedIndex: _selected,
              onSelected: _select,
            ),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        NavigationSidebar(
          destinations: <SidebarDestination>[
            SidebarDestination(glyph: AppGlyphs.library, label: titles[0]),
            SidebarDestination(glyph: AppGlyphs.search, label: titles[1]),
            SidebarDestination(glyph: AppGlyphs.transfers, label: titles[2]),
            SidebarDestination(glyph: AppGlyphs.settings, label: titles[3]),
          ],
          selectedIndex: _selected,
          expanded: _expanded,
          onSelected: _select,
          onToggle: () => setState(() => _expanded = !_expanded),
          windowControls: _windowControls,
        ),
        Expanded(child: stack),
      ],
    );
  }

  void _select(int index) {
    if (index != _selected) {
      setState(() => _selected = index);
    }
  }
}

/// One destination's page stack, independent of every other destination's.
class _DestinationNavigator extends StatelessWidget {
  const _DestinationNavigator({
    required this.navigatorKey,
    required this.title,
    required this.page,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String title;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        // The first route is the destination itself; anything pushed on top
        // goes through the app's table, so a page can open settings or a
        // sibling destination without knowing which navigator hosts it.
        if (settings.name == Navigator.defaultRouteName) {
          return FadePageRoute<void>(
            builder: (_) => AppPageScaffold(title: title, child: page),
          );
        }
        return AppRoutes.onGenerateRoute(settings);
      },
    );
  }
}
