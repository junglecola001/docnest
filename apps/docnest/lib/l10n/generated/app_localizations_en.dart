// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DocNest';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navSettings => 'Settings';

  @override
  String get libraryEmptyTitle => 'No folders yet';

  @override
  String get libraryEmptyBody =>
      'Indexing arrives with milestone M1: add whitelisted folders, scan them, then browse, search and preview here.';

  @override
  String get searchEmptyTitle => 'Search is not connected yet';

  @override
  String get searchEmptyBody =>
      'Search runs on the host index. It becomes available once the index database lands in M1.';

  @override
  String get transfersEmptyTitle => 'No transfers';

  @override
  String get transfersEmptyBody => 'Pairing and transfers arrive with milestones M2 and M3.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAccentColor => 'Accent color';

  @override
  String get settingsAccentColorHint => 'One color defines the whole app.';

  @override
  String get settingsColorStyle => 'Color style';

  @override
  String get styleVivid => 'Vivid';

  @override
  String get styleTinted => 'Tinted';

  @override
  String get styleSoft => 'Soft';

  @override
  String get styleMonochrome => 'Monochrome';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsGlass => 'Liquid glass';

  @override
  String get settingsGlassOff => 'Off';

  @override
  String get settingsGlassStandard => 'Standard';

  @override
  String get settingsGlassUltra => 'Ultra';

  @override
  String get settingsTextScale => 'Text size';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }
}
