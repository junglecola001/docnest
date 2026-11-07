import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chinese = DocNestUiLocalizations.lookup(const Locale('zh'));
  final english = DocNestUiLocalizations.lookup(const Locale('en'));

  test('Chinese strings are non-empty and differ from English', () {
    expect(chinese.back, isNotEmpty);
    expect(chinese.search, isNotEmpty);
    expect(chinese.cancel, isNotEmpty);
    expect(chinese.back, isNot(english.back));
    expect(chinese.search, isNot(english.search));
    expect(chinese.cancel, isNot(english.cancel));
  });

  test('every string prism asks for is present in both languages', () {
    for (final strings in <DocNestUiLocalizations>[chinese, english]) {
      expect(
        <String>[
          strings.back,
          strings.cancel,
          strings.clearSearch,
          strings.close,
          strings.copy,
          strings.cut,
          strings.dialog,
          strings.hidePassword,
          strings.more,
          strings.noSearchResults,
          strings.paste,
          strings.reset,
          strings.search,
          strings.select,
          strings.selectAll,
          strings.showLess,
          strings.showMore,
          strings.showPassword,
          strings.sort,
          strings.submit,
          strings.retry,
          strings.loadFailed,
        ].every((String value) => value.isNotEmpty),
        isTrue,
      );
    }
  });

  test('the delegate loads synchronously and only claims zh and en', () async {
    expect(DocNestUiLocalizations.delegate.isSupported(const Locale('zh', 'CN')), isTrue);
    expect(DocNestUiLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(DocNestUiLocalizations.delegate.isSupported(const Locale('fr')), isFalse);

    final loaded = await DocNestUiLocalizations.delegate.load(const Locale('zh'));
    expect(loaded, isA<DocNestUiLocalizations>());
    expect((loaded as DocNestUiLocalizations).search, chinese.search);
  });

  test('an unsupported language falls back to English', () {
    expect(DocNestUiLocalizations.lookup(const Locale('fr')).search, english.search);
  });
}
