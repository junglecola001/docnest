import 'package:docnest_core/docnest_core.dart';
import 'package:docnest_ui/docnest_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the named kinds keep their fixed hues', () {
    final scheme = AppTheme.light().colorScheme;
    expect(HSLColor.fromColor(fileKindColor(DocKind.pdf, scheme)).hue, closeTo(4, 2));
    expect(HSLColor.fromColor(fileKindColor(DocKind.spreadsheet, scheme)).hue, closeTo(142, 2));
    expect(HSLColor.fromColor(fileKindColor(DocKind.markdown, scheme)).hue, closeTo(270, 2));
  });

  test('plain text is neutral and a PDF is not', () {
    final scheme = AppTheme.light().colorScheme;
    final text = HSLColor.fromColor(fileKindColor(DocKind.text, scheme));
    expect(text.saturation, 0);
    final pdf = HSLColor.fromColor(fileKindColor(DocKind.pdf, scheme));
    expect(pdf.saturation, greaterThan(0.3));
  });

  test('dark surfaces lighten the same hues', () {
    final light = HSLColor.fromColor(fileKindColor(DocKind.word, AppTheme.light().colorScheme));
    final darkWord = HSLColor.fromColor(fileKindColor(DocKind.word, AppTheme.dark().colorScheme));
    expect(darkWord.lightness, greaterThan(light.lightness));
    expect(darkWord.hue, closeTo(light.hue, 2));
  });
}
