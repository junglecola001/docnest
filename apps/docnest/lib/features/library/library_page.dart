import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// The library destination: whitelisted folders and the documents inside them.
///
/// Nothing is indexed yet, so the page tells the truth: there are no folders
/// to show until M1's scanner lands. No sample rows stand in for them.
class LibraryPage extends StatelessWidget {
  /// Creates the library's content.
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NullStatus(
      label: l10n.libraryEmptyTitle,
      description: l10n.libraryEmptyBody,
      illustration: Illustration.search,
    );
  }
}
