import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes report the brightness they were built for', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('every color style builds in both brightnesses', () {
    for (final style in ColorStyle.values) {
      expect(() => AppTheme.light(style: style), returnsNormally);
      expect(() => AppTheme.dark(style: style), returnsNormally);
    }
  });

  test('the seed reaches the scheme, so two seeds give two accents', () {
    final blue = AppTheme.light(seed: const Color(0xFF007AFF));
    final red = AppTheme.light(seed: const Color(0xFFFF3B30));
    expect(blue.colorScheme.primary, isNot(red.colorScheme.primary));
  });

  test('both brightnesses fall back to the CJK families', () {
    expect(AppTheme.light().fontFamilyFallback, contains('Microsoft YaHei UI'));
    expect(AppTheme.dark().fontFamilyFallback, contains('Noto Sans CJK SC'));
  });
}
