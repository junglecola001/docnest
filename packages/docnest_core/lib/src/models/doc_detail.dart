import 'doc_entry.dart';
import 'tag.dart';

/// Everything the details panel needs for one document.
class DocDetail {
  const DocDetail({
    required this.entry,
    this.note,
    this.tags = const <Tag>[],
    this.lastOpenedAt,
    this.openCount = 0,
    this.textPreview,
  });

  final DocEntry entry;

  /// User note. User data, never derived from the file.
  final String? note;

  final List<Tag> tags;
  final DateTime? lastOpenedAt;
  final int openCount;

  /// Short plain-text extract used for the details panel.
  final String? textPreview;
}
