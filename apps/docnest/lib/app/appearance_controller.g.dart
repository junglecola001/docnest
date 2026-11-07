// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The appearance choices the running window is drawn with.
///
/// In-memory only. Persistence arrives with the settings table in M1, which
/// will seed [build] and write every change; until then this collection holds
/// no storage layer, real or fake, so nothing claims to have been saved.

@ProviderFor(Appearance)
final appearanceProvider = AppearanceProvider._();

/// The appearance choices the running window is drawn with.
///
/// In-memory only. Persistence arrives with the settings table in M1, which
/// will seed [build] and write every change; until then this collection holds
/// no storage layer, real or fake, so nothing claims to have been saved.
final class AppearanceProvider extends $NotifierProvider<Appearance, AppearanceSettings> {
  /// The appearance choices the running window is drawn with.
  ///
  /// In-memory only. Persistence arrives with the settings table in M1, which
  /// will seed [build] and write every change; until then this collection holds
  /// no storage layer, real or fake, so nothing claims to have been saved.
  AppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceHash();

  @$internal
  @override
  Appearance create() => Appearance();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceSettings>(value),
    );
  }
}

String _$appearanceHash() => r'c332c9d97c0496911f19648c65d86a0e2f77826b';

/// The appearance choices the running window is drawn with.
///
/// In-memory only. Persistence arrives with the settings table in M1, which
/// will seed [build] and write every change; until then this collection holds
/// no storage layer, real or fake, so nothing claims to have been saved.

abstract class _$Appearance extends $Notifier<AppearanceSettings> {
  AppearanceSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppearanceSettings, AppearanceSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppearanceSettings, AppearanceSettings>,
              AppearanceSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
