/// Lifecycle of a resumable upload session.
///
/// Shared by the host state machine and the wire DTOs so the two cannot drift.
enum UploadState {
  /// Accepting chunks from the client.
  open('open'),

  /// The bytes were delivered (or deliberately skipped); no more chunks.
  completed('completed'),

  /// The client or the user abandoned the upload.
  cancelled('cancelled'),

  /// The session sat idle past its expiry and was swept, including its `.part`.
  expired('expired');

  const UploadState(this.wire);

  /// Stable name used on the wire and in the database.
  final String wire;

  /// Parses [wire], defaulting to [UploadState.expired] so an unknown state on
  /// the host side can never be mistaken for a resumable session.
  static UploadState fromWire(String? wire) {
    for (final state in values) {
      if (state.wire == wire) return state;
    }
    return UploadState.expired;
  }
}
