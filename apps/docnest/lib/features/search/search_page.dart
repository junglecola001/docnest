import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// The search destination: the host index's results, full-text and filters.
///
/// Search runs against the host index, which does not exist until M1, so the
/// page is an empty state rather than a field that would query nothing.
class SearchPage extends StatelessWidget {
  /// Creates the search destination's content.
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NullStatus(
      label: l10n.searchEmptyTitle,
      description: l10n.searchEmptyBody,
      illustration: Illustration.search,
    );
  }
}
