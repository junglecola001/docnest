import '../ids.dart';

/// Handle returned by a delete operation so the UI can offer "Undo" without
/// going through the Windows recycle bin.
///
/// The host moves files into `<root>/.docnest/trash/` immediately and only
/// hands them to the system recycle bin after the undo window expires.
class TrashTicket {
  const TrashTicket({required this.token, required this.docIds, required this.expiresAt});

  /// Opaque, single-use token. Holding it is the only way to restore.
  final String token;

  final List<DocId> docIds;

  /// When the host will push the files into the recycle bin.
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  @override
  String toString() => 'TrashTicket($token, ${docIds.length} docs)';
}
