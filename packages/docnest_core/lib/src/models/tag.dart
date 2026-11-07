import '../ids.dart';

/// A user-defined tag. Tags are user data: they survive a full reindex.
class Tag {
  const Tag({required this.id, required this.name, this.color, this.sortOrder = 0});

  final TagId id;
  final String name;

  /// ARGB color, or `null` to derive one from the name.
  final int? color;

  final int sortOrder;

  @override
  String toString() => 'Tag(${id.value}, $name)';
}
