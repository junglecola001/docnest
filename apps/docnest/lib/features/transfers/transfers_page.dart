import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// The transfers destination: pairing, uploads and downloads.
///
/// Nothing can be transferred before pairing exists in M2, so the list is
/// empty by fact rather than by a missing sample.
class TransfersPage extends StatelessWidget {
  /// Creates the transfers destination's content.
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NullStatus(
      label: l10n.transfersEmptyTitle,
      description: l10n.transfersEmptyBody,
      illustration: Illustration.search,
    );
  }
}
