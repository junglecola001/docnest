import 'name_index.dart';

/// Turns extracted text into FTS5 tokens, and user queries into FTS5 MATCH
/// expressions (plan §4.5.4).
///
/// The FTS table is declared with the `unicode61` tokenizer, which treats a run
/// of Han characters as a single token. Chinese and Japanese have no spaces, so
/// the text is pre-split into overlapping bigrams: `合同管理` becomes
/// `合同 同管 管理`. Two-character words then match, which the built-in
/// `trigram` tokenizer cannot do because it requires three characters.
abstract final class SearchTokenizer {
  /// Hard cap on tokens produced for one document.
  ///
  /// A malformed or adversarial file must not be able to make the indexer
  /// allocate without bound; 200k bigrams is far more than the 2 MB text
  /// extraction limit can yield unless the text is pure CJK, in which case the
  /// overflow is silently dropped rather than failing the whole job.
  static const int maxIndexTokens = 200000;

  /// Hard cap on terms in one MATCH expression.
  ///
  /// Keeps a pasted paragraph from turning into a query with tens of thousands
  /// of ANDed terms, which FTS5 would reject for exceeding its expression
  /// depth.
  static const int maxQueryTerms = 64;

  /// Tokens to store for [text].
  ///
  /// Runs of CJK characters become overlapping two-character tokens; a
  /// one-character run is kept as-is (nothing else can represent it). Latin and
  /// digit words are lowercased and kept whole, and everything else separates
  /// tokens.
  static List<String> indexTokens(String text) {
    final tokens = <String>[];
    if (text.isEmpty) return tokens;

    for (final run in _splitRuns(text)) {
      if (tokens.length >= maxIndexTokens) break;
      if (run.isCjk) {
        final runes = run.runes;
        if (runes.length == 1) {
          tokens.add(String.fromCharCodes(runes));
          continue;
        }
        for (var i = 0; i + 1 < runes.length; i++) {
          tokens.add(String.fromCharCodes(<int>[runes[i], runes[i + 1]]));
          if (tokens.length >= maxIndexTokens) break;
        }
      } else {
        final word = normalizeSearchText(String.fromCharCodes(run.runes));
        if (word.isNotEmpty) tokens.add(word);
      }
    }
    return tokens;
  }

  /// Builds an FTS5 MATCH expression for the raw user input [raw].
  ///
  /// Every term is quoted, so FTS5 syntax characters the user typed (`AND`,
  /// `OR`, `NEAR(`, `*`, `-`) are treated as literal text instead of syntax.
  /// The expression is an AND of the bigrams produced by [indexTokens], which
  /// makes a multi-character Chinese query behave like a phrase.
  ///
  /// A single CJK character becomes a prefix query (`"合"*`) because the index
  /// only stores two-character tokens, and the last latin/digit word also
  /// becomes a prefix when the input ends at that word, so results appear while
  /// the user is still typing. Returns the empty string when nothing searchable
  /// remains; callers must skip MATCH in that case.
  static String ftsQuery(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final runs = _splitRuns(text);
    // Trailing detection uses the untrimmed input: a user who typed a space
    // after the last word is done typing that word.
    final trailingPartial = _endsWithWordRune(raw);
    final terms = <String>[];

    for (var index = 0; index < runs.length; index++) {
      final run = runs[index];
      final isLast = index == runs.length - 1;

      if (run.isCjk) {
        final runes = run.runes;
        if (runes.length == 1) {
          terms.add(_quote(String.fromCharCodes(runes), prefix: true));
        } else {
          for (var i = 0; i + 1 < runes.length; i++) {
            terms.add(_quote(String.fromCharCodes(<int>[runes[i], runes[i + 1]])));
          }
        }
      } else {
        final word = normalizeSearchText(String.fromCharCodes(run.runes));
        if (word.isEmpty) continue;
        terms.add(_quote(word, prefix: isLast && trailingPartial));
      }

      if (terms.length >= maxQueryTerms) break;
    }

    return terms.isEmpty ? '' : terms.join(' AND ');
  }

  /// Quotes [term] as an FTS5 string literal.
  ///
  /// FTS5 escapes an embedded double quote by doubling it. Tokens are produced
  /// by the splitter, which treats quotes as separators, so this is defence in
  /// depth rather than the main protection: the output can never be unbalanced
  /// even if the splitter is later relaxed.
  static String _quote(String term, {bool prefix = false}) {
    final escaped = term.replaceAll('"', '""');
    return prefix ? '"$escaped"*' : '"$escaped"';
  }

  /// Splits [text] into maximal runs of CJK or word characters.
  static List<_Run> _splitRuns(String text) {
    final runs = <_Run>[];
    final runes = text.runes.toList(growable: false);
    if (runes.isEmpty) return runs;

    var start = 0;
    var currentClass = _classify(runes.first);
    for (var i = 1; i <= runes.length; i++) {
      final nextClass = i == runes.length ? _CharClass.separator : _classify(runes[i]);
      if (nextClass == currentClass) continue;
      if (currentClass != _CharClass.separator) {
        runs.add(_Run(isCjk: currentClass == _CharClass.cjk, runes: runes.sublist(start, i)));
      }
      start = i;
      currentClass = nextClass;
    }
    return runs;
  }

  static _CharClass _classify(int rune) {
    if (isCjkRune(rune)) return _CharClass.cjk;
    if (isWordRune(rune)) return _CharClass.word;
    return _CharClass.separator;
  }

  static bool _endsWithWordRune(String text) {
    if (text.isEmpty) return false;
    final last = text.runes.last;
    return _classify(last) != _CharClass.separator;
  }
}

/// A maximal run of one character class.
final class _Run {
  const _Run({required this.isCjk, required this.runes});

  final bool isCjk;
  final List<int> runes;
}

enum _CharClass { cjk, word, separator }
