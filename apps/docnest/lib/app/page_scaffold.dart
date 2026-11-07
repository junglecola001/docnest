import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

/// The chrome a destination or a pushed page draws around its content.
///
/// Every page keeps the same bar and the same gap over the shell's navigation:
/// prism floats the bar over the page, so the body starts below the height it
/// reports, and on a phone the body ends above the navigation dock the shell
/// floats at the window's foot.
class AppPageScaffold extends StatelessWidget {
  /// Wraps [child] with the title bar and the page's own surface.
  const AppPageScaffold({super.key, required this.title, required this.child});

  /// The page's name in the bar, already localized by the caller.
  final String title;

  /// The page's content, which scrolls or centers itself.
  final Widget child;

  /// Nothing on a page reports progress yet, so the bar's inputs never change.
  static const AlwaysStoppedAnimation<bool> _idle = AlwaysStoppedAnimation<bool>(false);

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      bar: ScaffoldBar(
        isCompact: false,
        listenable: _idle,
        loading: _idle,
        builder: (context) => AppBar(title: Text(title)),
      ),
      body: Builder(
        builder: (context) {
          // Inside the frame the bar's height is already the top padding; a
          // phone also loses the dock's height at the foot.
          final barInset = MediaQuery.paddingOf(context).top;
          final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;
          return Padding(
            padding: EdgeInsets.only(
              top: barInset,
              bottom: compact ? NavigationDock.insetOf(context) : 0,
            ),
            child: child,
          );
        },
      ),
    );
  }
}
