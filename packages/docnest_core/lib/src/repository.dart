import 'events.dart';
import 'ids.dart';
import 'models/doc_detail.dart';
import 'models/doc_entry.dart';
import 'models/folder_entry.dart';
import 'models/root.dart';
import 'models/tag.dart';
import 'models/trash.dart';
import 'query.dart';

/// The single seam between the UI and the data source.
///
/// `LocalLibraryRepository` (host) and `RemoteLibraryRepository` (client)
/// implement it, so every library, search and preview screen is shared.
abstract interface class LibraryRepository {
  /// Whitelisted roots, updated in place as status and counts change.
  Stream<List<Root>> watchRoots();

  /// Children of [dirPath] inside [rootId]: folders first, then documents.
  Stream<PageOf<FolderEntry>> watchFolders(RootId rootId, {String dirPath = ''});

  /// Query documents. [cursor] is opaque and comes from a previous page.
  Future<PageOf<DocEntry>> query(DocQuery query, {String? cursor});

  /// Full details for the inspector panel.
  Future<DocDetail> detail(DocId id);

  /// Rename a document; the extension is preserved by the caller's intent.
  Future<DocEntry> rename(DocId id, String newName);

  /// Move documents into the two-phase trash; returns an undo ticket.
  Future<TrashTicket> trash(List<DocId> ids);

  /// Undo a [trash] while [TrashTicket.expiresAt] has not passed.
  Future<void> restore(TrashTicket ticket);

  /// Set the favorite flag.
  Future<void> setFavorite(DocId id, bool favorite);

  /// Replace the note; `null` clears it.
  Future<void> setNote(DocId id, String? note);

  /// Replace the tag set of a document.
  Future<void> setTags(DocId id, List<TagId> tagIds);

  /// All tags known to the host.
  Future<List<Tag>> tags();

  /// Change notifications for live refresh.
  Stream<LibraryEvent> events();

  /// Release resources (sockets, watchers). Safe to call twice.
  Future<void> dispose();
}
