import 'package:lpinyin/lpinyin.dart';

/// Normalises text for the three file-name search keys.
///
/// "NFKC-ish" on purpose: the host must not depend on `package:characters` or
/// on full Unicode normalisation for every entry, but full-width ASCII and the
/// ideographic space are the variants users actually type (Chinese IMEs emit
/// them), so those are folded here, followed by lowercasing and trimming.
/// Collapsing internal whitespace keeps `"report   2026"` and `"report 2026"`
/// on the same key.
String normalizeSearchText(String input) {
  if (input.isEmpty) return '';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      // Full-width ASCII block maps 1:1 onto ASCII.
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000 || rune == 0x00A0) {
      buffer.writeCharCode(0x20);
    } else if (rune == 0x200B || rune == 0xFEFF) {
      // Zero-width space / BOM: invisible characters would otherwise turn up
      // in prefixes and make equality checks fail mysteriously.
      continue;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Whether [rune] belongs to a script written without spaces between words.
///
/// Covers CJK ideographs, kana and Hangul; shared with the tokenizer so that
/// pinyin generation and bigram splitting agree on what a "word" is.
bool isCjkRune(int rune) {
  if (rune >= 0x3040 && rune <= 0x30FF) return true; // Hiragana, katakana.
  if (rune >= 0x3400 && rune <= 0x4DBF) return true; // CJK extension A.
  if (rune >= 0x4E00 && rune <= 0x9FFF) return true; // CJK unified.
  if (rune >= 0xAC00 && rune <= 0xD7AF) return true; // Hangul syllables.
  if (rune >= 0xF900 && rune <= 0xFAFF) return true; // CJK compatibility.
  if (rune >= 0x20000 && rune <= 0x2FA1F) return true; // CJK extensions B+.
  return false;
}

final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Whether [rune] is a letter or digit, excluding CJK (see [isCjkRune]).
bool isWordRune(int rune) => !isCjkRune(rune) && _letterOrDigit.hasMatch(String.fromCharCode(rune));

/// The three file-name search keys stored for every indexed document.
///
/// Matching is `contains` on any of them, so prefix, pinyin and initials
/// queries all work without a dedicated index (plan §4.5.4). Values are
/// lowercase and whitespace-insensitive; punctuation is kept in [nameNorm] but
/// dropped from [pinyin] and [initials] because they are search keys, not
/// display strings.
final class NameIndex {
  const NameIndex({required this.nameNorm, required this.pinyin, required this.initials});

  /// Builds the keys for [fileName].
  ///
  /// `合同管理.pdf` yields `nameNorm == '合同管理.pdf'`, a pinyin key starting
  /// with `hetongguanli` and initials starting with `htgl`. The extension is
  /// excluded from the pinyin keys: nobody types `pdf` as pinyin, and leaving
  /// it in would make every PDF share the `pdf` suffix. Latin and digit words
  /// are kept whole, so `Annual Report 2026` gives initials `ar2026` rather
  /// than one letter per letter.
  factory NameIndex.of(String fileName) {
    final normalized = normalizeSearchText(fileName);
    final nameNorm = normalized;
    final stem = _stemOf(normalized);

    final tokens = <String>[];
    final runes = stem.runes.toList(growable: false);
    var start = 0;
    var current = _Script.separator;
    for (var i = 0; i <= runes.length; i++) {
      final next = i == runes.length
          ? _Script.separator
          : (isCjkRune(runes[i])
                ? _Script.cjk
                : (isWordRune(runes[i]) ? _Script.word : _Script.separator));
      if (next == current) continue;
      if (current != _Script.separator) {
        final run = String.fromCharCodes(runes.sublist(start, i));
        if (current == _Script.cjk) {
          // `getPinyinE` emits one token per syllable with `separator` between
          // them, keeping the most common reading for polyphonic characters.
          final pinyin = PinyinHelper.getPinyinE(
            run,
            separator: ' ',
            defPinyin: '',
            format: PinyinFormat.WITHOUT_TONE,
          );
          tokens.addAll(pinyin.split(' ').where((String token) => token.isNotEmpty));
        } else {
          tokens.add(run);
        }
      }
      start = i;
      current = next;
    }

    final pinyin = tokens.join();
    final initials = tokens.map(_firstRune).join();
    return NameIndex(nameNorm: nameNorm, pinyin: pinyin, initials: initials);
  }

  /// Lowercased, half-width, trimmed file name including its extension.
  final String nameNorm;

  /// Pinyin of the stem with tone marks and separators removed.
  final String pinyin;

  /// First letter of every pinyin syllable (or of every latin/digit word).
  final String initials;

  @override
  String toString() => 'NameIndex($nameNorm, $pinyin, $initials)';
}

enum _Script { cjk, word, separator }

/// Strips the final extension so `合同管理.pdf` becomes `合同管理`.
///
/// Runs after normalisation so a full-width dot also counts. A leading dot
/// means a dotfile, not an extension, hence `dot > 0`.
String _stemOf(String normalizedName) {
  final dot = normalizedName.lastIndexOf('.');
  return dot > 0 ? normalizedName.substring(0, dot) : normalizedName;
}

String _firstRune(String token) => String.fromCharCode(token.runes.first);
