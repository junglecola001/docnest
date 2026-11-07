import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../l10n/docnest_ui_localizations.dart';
import '../theme/app_tokens.dart';

/// Builds the content [AsyncView] shows once it has data.
typedef AsyncDataBuilder<T> = Widget Function(BuildContext context, T data);

/// Builds the state [AsyncView] shows when its load failed.
typedef AsyncErrorBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);

/// Draws the three states of a [AsyncValue] in DocNest's own vocabulary.
///
/// Without it every screen writes its own skeleton, its own failure text and
/// its own retry wiring, and the app reads as several apps. The defaults here
/// use prism's [SkeletonPill] for loading and [NullStatus] for failure, so the
/// states match the empty states the rest of the app draws.
class AsyncView<T> extends StatelessWidget {
  /// Draws [value], delegating each state to the builders below.
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
    this.retryLabel,
  });

  /// The value to draw; refreshing keeps the previous data on screen, because
  /// `when` only takes the loading branch when nothing has arrived yet.
  final AsyncValue<T> value;

  /// Builds the content for the loaded value.
  final AsyncDataBuilder<T> data;

  /// Replaces the skeleton while the first load runs.
  final WidgetBuilder? loading;

  /// Replaces the failure state; the default shows the error and a retry
  /// button, and is enough for most screens.
  final AsyncErrorBuilder? error;

  /// Makes the default failure state offer retry; without it no button is
  /// drawn, for a failure that retrying cannot fix.
  final VoidCallback? onRetry;

  /// Overrides the localized label of the retry button.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (T result) => data(context, result),
      error: (Object error, StackTrace stackTrace) =>
          this.error?.call(context, error, stackTrace) ??
          _ErrorStatus(error: error, onRetry: onRetry, retryLabel: retryLabel),
      loading: () => loading?.call(context) ?? const _LoadingSkeleton(),
    );
  }
}

/// The default failure state: what went wrong, and the action that retries.
class _ErrorStatus extends StatelessWidget {
  const _ErrorStatus({required this.error, this.onRetry, this.retryLabel});

  final Object error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final localizations = DocNestUiLocalizations.maybeOf(context);
    final onRetry = this.onRetry;
    return NullStatus(
      label: localizations?.loadFailed,
      description: error.toString(),
      // Prism ships one public illustration; a failure is not a search miss,
      // but the mark stays neutral and the error text carries the meaning.
      illustration: Illustration.search,
      action: onRetry == null
          ? null
          : TonalButton(label: retryLabel ?? localizations?.retry ?? 'Retry', onPressed: onRetry),
    );
  }
}

/// The placeholder rows shown while a first load runs.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonPill(width: 240, height: 16),
            SizedBox(height: AppSpacing.sm),
            SkeletonPill(width: 320, height: 12),
            SizedBox(height: AppSpacing.xs),
            SkeletonPill(width: 280, height: 12),
          ],
        ),
      ),
    );
  }
}
