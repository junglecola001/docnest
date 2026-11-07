import 'package:docnest_core/docnest_core.dart';

/// Turns an arbitrary user or client supplied name into one Windows accepts.
///
/// Policy (plan §3.5, "落盘规则"): replace rather than reject, because the name
/// usually comes from another OS (a phone, a Linux share) and refusing it would
/// lose the file. The caller still gets an exception when nothing usable is
/// left.
abstract final class NameSanitizer {
  /// Characters Windows rejects in a file name.
  static final RegExp _illegal = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Longest name Windows accepts, in UTF-16 code units.
  static const int maxLength = 255;

  static final RegExp _reserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])$',
    caseSensitive: false,
  );

  /// Returns a name that Windows will accept, preserving the extension.
  ///
  /// Throws [InvalidNameException] when [raw] has no usable characters.
  static String sanitize(String raw) {
    // Control characters and path separators cannot appear in a file name; a
    // client sending "a/b.txt" means a file called "a/b.txt" only by mistake,
    // so flatten rather than silently create a directory.
    var name = raw.replaceAll(_illegal, '_');

    // Windows strips these on create, which would make the name we report
    // differ from the name on disk.
    name = name.replaceFirst(RegExp(r'[. ]+$'), '');

    if (name.isEmpty || name == '.' || name == '..') {
      throw InvalidNameException(message: 'Name has no usable characters', details: {'raw': raw});
    }

    if (_reserved.hasMatch(_stem(name))) {
      // `_CON` instead of `CON`: still recognisable, no longer a device name.
      name = '_$name';
    }

    if (name.length > maxLength) name = _truncate(name);

    if (name.isEmpty) {
      throw InvalidNameException(message: 'Name has no usable characters', details: {'raw': raw});
    }
    return name;
  }

  /// Whether [name] is a reserved device name (`CON`, `LPT1`, …).
  static bool isReserved(String name) => _reserved.hasMatch(_stem(name));

  /// Base name without its final extension; `''` when [name] is all extension.
  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// Cuts the base name so that `base + extension` fits in [maxLength].
  static String _truncate(String name) {
    final dot = name.lastIndexOf('.');
    final hasExtension = dot > 0 && name.length - dot <= 32;
    final extension = hasExtension ? name.substring(dot) : '';
    final stem = hasExtension ? name.substring(0, dot) : name;
    final budget = maxLength - extension.length;
    if (budget <= 0) return name.substring(0, maxLength).replaceFirst(RegExp(r'[. ]+$'), '');
    // Do not split a surrogate pair: a half pair is an invalid string.
    var cut = budget;
    if (cut > 0 && cut < stem.length) {
      final unit = stem.codeUnitAt(cut - 1);
      final isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
      if (isHighSurrogate) cut -= 1;
    }
    return '${stem.substring(0, cut).replaceFirst(RegExp(r'[. ]+$'), '')}$extension';
  }
}
