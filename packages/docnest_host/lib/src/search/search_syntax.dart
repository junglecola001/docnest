import 'dart:math' as math;

import 'package:docnest_core/docnest_core.dart';

/// Result of parsing a search box: free text plus structured filters.
typedef SearchParseResult = ({String keywords, DocQuery filters});

/// Parses the search syntax shown in the search box (plan §4.5.4).
///
/// ## Grammar
///
/// The input is split on whitespace. A token of the form `key:value` is a
/// filter when `key` is one of the operators below and `value` is valid;
/// otherwise the whole token is kept verbatim in [SearchParseResult.keywords]
/// so that a typo (or a URL such as `https://…`) never silently disappears.
///
/// * `type:pdf|word|excel|spreadsheet|ppt|presentation|text|markdown|image`
///   adds a [DocKind] to the filter. `excel` and `spreadsheet` are synonyms, as
///   are `ppt` and `presentation`.
/// * `ext:pdf` (a leading dot is allowed) adds one extension. Repeatable.
/// * `tag:3` adds tag id 3. Repeatable.
/// * `root:2` restricts the query to root 2. The last valid occurrence wins.
/// * `size:>10mb`, `size:>=1kb`, `size:<500kb`, `size:<=2gb`,
///   `size:1.5mb`. Units are `b`, `kb`, `mb`, `gb` (binary multiples: 1 kb =
///   1024 bytes); no unit means bytes. `>` excludes the boundary (minimum is
///   `bytes + 1`), `<` excludes it (maximum is `bytes - 1`), and a bare value
///   or `=` means exactly that size. Repeatable; the tightest bounds win.
/// * `modified:` accepts:
///   * `2026-10` — the whole month.
///   * `2026-10-03` — the whole day.
///   * `>2026-01-01` — strictly after that day (from the next day's 00:00).
///   * `>=2026-01-01` — from the start of that day.
///   * `<2026-01-01` — strictly before that day (until 1 ms before it).
///   * `<=2026-01-01` — until the last millisecond of that day.
///   * `last7d`, `last12h`, `last30m` — a sliding window ending at [now].
///
///   Dates are local time, matching the file-system timestamps they are
///   compared against. Repeatable; the tightest bounds win.
///
/// [SearchParseResult.keywords] is the remaining free text with single spaces,
/// and [SearchParseResult.filters] never has its `text` field set: the caller
/// combines the keywords with FTS or a name match. A filter value that fails to
/// parse is not an error; the token simply stays in the keywords, which keeps
/// the query tolerant while the user is typing.
abstract final class SearchSyntax {
  /// `type:` aliases, including the spreadsheet/presentation spellings users
  /// know from other file managers.
  static const Map<String, DocKind> typeAliases = <String, DocKind>{
    'pdf': DocKind.pdf,
    'word': DocKind.word,
    'excel': DocKind.spreadsheet,
    'spreadsheet': DocKind.spreadsheet,
    'ppt': DocKind.presentation,
    'presentation': DocKind.presentation,
    'text': DocKind.text,
    'markdown': DocKind.markdown,
    'image': DocKind.image,
  };

  /// Parses [input].
  ///
  /// [now] is injectable so the `last…` windows are deterministic in tests;
  /// it defaults to `DateTime.now()`.
  static SearchParseResult parse(String input, {DateTime? now}) {
    final keywords = <String>[];
    final kinds = <DocKind>{};
    final exts = <String>{};
    final tagIds = <TagId>[];
    RootId? rootId;
    DateTime? modifiedAfter;
    DateTime? modifiedBefore;
    int? minSize;
    int? maxSize;

    for (final token in input.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final colon = token.indexOf(':');
      if (colon <= 0 || colon == token.length - 1) {
        keywords.add(token);
        continue;
      }
      final key = token.substring(0, colon).toLowerCase();
      final value = token.substring(colon + 1);
      var consumed = true;

      switch (key) {
        case 'type':
          {
            final kind = typeAliases[value.toLowerCase()];
            if (kind == null) {
              consumed = false;
            } else {
              kinds.add(kind);
            }
          }
        case 'ext':
          {
            final ext = _normalizeExtension(value);
            if (ext == null) {
              consumed = false;
            } else {
              exts.add(ext);
            }
          }
        case 'tag':
          {
            final id = int.tryParse(value);
            if (id == null || id <= 0) {
              consumed = false;
            } else if (!tagIds.contains(TagId(id))) {
              tagIds.add(TagId(id));
            }
          }
        case 'root':
          {
            final id = int.tryParse(value);
            if (id == null || id < 0) {
              consumed = false;
            } else {
              rootId = RootId(id);
            }
          }
        case 'size':
          {
            final range = _parseSize(value);
            if (range == null) {
              consumed = false;
            } else {
              final lower = range.min;
              if (lower != null) {
                final current = minSize;
                minSize = current == null ? lower : math.max(current, lower);
              }
              final upper = range.max;
              if (upper != null) {
                final current = maxSize;
                maxSize = current == null ? upper : math.min(current, upper);
              }
            }
          }
        case 'modified':
          {
            final range = _parseModified(value, now ?? DateTime.now());
            if (range == null) {
              consumed = false;
            } else {
              final after = range.after;
              if (after != null) {
                modifiedAfter = _later(modifiedAfter, after);
              }
              final before = range.before;
              if (before != null) {
                modifiedBefore = _earlier(modifiedBefore, before);
              }
            }
          }
        default:
          consumed = false;
      }

      if (!consumed) keywords.add(token);
    }

    return (
      keywords: keywords.join(' '),
      filters: DocQuery(
        kinds: kinds,
        exts: exts,
        tagIds: tagIds,
        rootId: rootId,
        modifiedAfter: modifiedAfter,
        modifiedBefore: modifiedBefore,
        minSize: minSize,
        maxSize: maxSize,
      ),
    );
  }

  static final RegExp _sizePattern = RegExp(
    r'^(>=|<=|>|<|=)?(\d+(?:\.\d+)?)(b|kb|mb|gb)?$',
    caseSensitive: false,
  );

  static const Map<String, int> _unitBytes = <String, int>{
    'b': 1,
    'kb': 1024,
    'mb': 1024 * 1024,
    'gb': 1024 * 1024 * 1024,
  };

  static final RegExp _lastWindowPattern = RegExp(r'^last(\d+)([dhm])$');

  static final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _monthPattern = RegExp(r'^(\d{4})-(\d{2})$');

  static ({int? min, int? max})? _parseSize(String value) {
    final match = _sizePattern.firstMatch(value);
    if (match == null) return null;
    final op = match.group(1);
    final amount = double.tryParse(match.group(2)!);
    if (amount == null) return null;
    final multiplier = _unitBytes[match.group(3)?.toLowerCase() ?? 'b']!;
    final bytes = (amount * multiplier).round();
    if (bytes < 0) return null;

    return switch (op) {
      // `>` excludes the boundary, hence the ±1; an exact size is both bounds.
      '>' => (min: bytes + 1, max: null),
      '<' => bytes == 0 ? null : (min: null, max: bytes - 1),
      '>=' => (min: bytes, max: null),
      '<=' => (min: null, max: bytes),
      _ => (min: bytes, max: bytes),
    };
  }

  static ({DateTime? after, DateTime? before})? _parseModified(String value, DateTime now) {
    final window = _lastWindowPattern.firstMatch(value.toLowerCase());
    if (window != null) {
      final amount = int.tryParse(window.group(1)!);
      if (amount == null || amount <= 0) return null;
      final unit = window.group(2);
      final duration = switch (unit) {
        'd' => Duration(days: amount),
        'h' => Duration(hours: amount),
        'm' => Duration(minutes: amount),
        _ => null,
      };
      if (duration == null) return null;
      return (after: now.subtract(duration), before: null);
    }

    final op = _leadingOperator(value);
    final rest = value.substring(op.length);
    final month = _monthPattern.firstMatch(rest);
    if (month != null && op.isEmpty) {
      final year = int.parse(month.group(1)!);
      final monthNumber = int.parse(month.group(2)!);
      if (monthNumber < 1 || monthNumber > 12) return null;
      final start = DateTime(year, monthNumber);
      final end = DateTime(year, monthNumber + 1);
      return (after: start, before: end.subtract(const Duration(milliseconds: 1)));
    }

    final date = _datePattern.firstMatch(rest);
    if (date == null) return null;
    final year = int.parse(date.group(1)!);
    final monthNumber = int.parse(date.group(2)!);
    final day = int.parse(date.group(3)!);
    if (monthNumber < 1 || monthNumber > 12 || day < 1 || day > 31) return null;
    final start = DateTime(year, monthNumber, day);
    // `DateTime` normalises out-of-range days (31 April becomes 1 May), so a
    // round-trip is the cheapest way to reject them.
    if (start.year != year || start.month != monthNumber || start.day != day) return null;
    final nextDay = DateTime(year, monthNumber, day + 1);
    final endOfDay = nextDay.subtract(const Duration(milliseconds: 1));

    return switch (op) {
      '>' => (after: nextDay, before: null),
      '>=' => (after: start, before: null),
      '<' => (after: null, before: start.subtract(const Duration(milliseconds: 1))),
      '<=' => (after: null, before: endOfDay),
      _ => (after: start, before: endOfDay),
    };
  }

  static String _leadingOperator(String value) {
    for (final op in const <String>['>=', '<=', '>', '<']) {
      if (value.startsWith(op)) return op;
    }
    return '';
  }

  static String? _normalizeExtension(String value) {
    var ext = value.toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    return RegExp(r'^[a-z0-9]{1,16}$').hasMatch(ext) ? ext : null;
  }

  static DateTime _later(DateTime? current, DateTime candidate) =>
      current == null || candidate.isAfter(current) ? candidate : current;

  static DateTime _earlier(DateTime? current, DateTime candidate) =>
      current == null || candidate.isBefore(current) ? candidate : current;
}
