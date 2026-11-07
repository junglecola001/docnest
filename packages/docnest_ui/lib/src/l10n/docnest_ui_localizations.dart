import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// The strings DocNest's own widgets show, in the two languages it ships.
///
/// Prism's components read their own text — "Cancel", "Select all" and so on —
/// through [UiLocalizations], so this class is the single delegate that gives
/// both prism and DocNest their words. It carries two getters prism does not
/// declare ([retry] and [loadFailed]) for the async scaffolding DocNest adds;
/// they are reachable through [maybeOf], which returns the concrete type.
abstract class DocNestUiLocalizations implements UiLocalizations {
  /// Const so the two variants can be held as compile-time constants.
  const DocNestUiLocalizations();

  /// The languages this package has strings for.
  ///
  /// Chinese leads because the product is built for a Chinese-speaking user
  /// first; a device in any other language resolves to English.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh'), Locale('en')];

  /// The delegate registered on the app root.
  static const LocalizationsDelegate<UiLocalizations> delegate = _DocNestUiLocalizationsDelegate();

  /// The strings for [locale], falling back to English.
  ///
  /// [delegate] only forwards supported locales here; the fallback covers
  /// direct calls and tests, so this never throws.
  static DocNestUiLocalizations lookup(Locale locale) {
    return switch (locale.languageCode) {
      'zh' => const _ChineseLocalizations(),
      _ => const _EnglishLocalizations(),
    };
  }

  /// The DocNest strings in scope at [context], or null when the app
  /// registered someone else's delegate.
  static DocNestUiLocalizations? maybeOf(BuildContext context) {
    final localizations = Localizations.of<UiLocalizations>(context, UiLocalizations);
    return localizations is DocNestUiLocalizations ? localizations : null;
  }

  /// Label of the action that retries a load that failed.
  String get retry;

  /// Title of the state shown when a load has failed.
  String get loadFailed;
}

/// Simplified Chinese strings.
class _ChineseLocalizations extends DocNestUiLocalizations {
  const _ChineseLocalizations();

  @override
  String get back => '返回';

  @override
  String get cancel => '取消';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get close => '关闭';

  @override
  String get copy => '复制';

  @override
  String get cut => '剪切';

  @override
  String get dialog => '对话框';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get loadFailed => '加载失败';

  @override
  String get more => '更多';

  @override
  String get noSearchResults => '没有搜索结果';

  @override
  String get paste => '粘贴';

  @override
  String get reset => '重置';

  @override
  String get retry => '重试';

  @override
  String get search => '搜索';

  @override
  String get select => '选择';

  @override
  String get selectAll => '全选';

  @override
  String get showLess => '收起';

  @override
  String get showMore => '展开';

  @override
  String get showPassword => '显示密码';

  @override
  String get sort => '排序';

  @override
  String get submit => '提交';
}

/// English strings.
class _EnglishLocalizations extends DocNestUiLocalizations {
  const _EnglishLocalizations();

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get dialog => 'Dialog';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loadFailed => 'Could not load';

  @override
  String get more => 'More';

  @override
  String get noSearchResults => 'No results';

  @override
  String get paste => 'Paste';

  @override
  String get reset => 'Reset';

  @override
  String get retry => 'Retry';

  @override
  String get search => 'Search';

  @override
  String get select => 'Select';

  @override
  String get selectAll => 'Select all';

  @override
  String get showLess => 'Show less';

  @override
  String get showMore => 'Show more';

  @override
  String get showPassword => 'Show password';

  @override
  String get sort => 'Sort';

  @override
  String get submit => 'Submit';
}

/// Loads the strings synchronously; they are const, nothing is parsed.
class _DocNestUiLocalizationsDelegate extends LocalizationsDelegate<UiLocalizations> {
  const _DocNestUiLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => DocNestUiLocalizations.supportedLocales.any(
    (Locale supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<UiLocalizations> load(Locale locale) =>
      SynchronousFuture<UiLocalizations>(DocNestUiLocalizations.lookup(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<UiLocalizations> old) => false;
}
