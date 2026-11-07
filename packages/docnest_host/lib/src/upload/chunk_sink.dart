import 'dart:io';
import 'dart:typed_data';

import 'package:docnest_core/docnest_core.dart';

/// Byte sink for one upload's staging file.
///
/// The offset contract is the whole point of this interface: a chunk is only
/// accepted when it starts exactly where the previous one ended. Padding over a
/// gap or overwriting existing bytes would hide a lost chunk until the final
/// size check, so implementations throw [UploadOffsetMismatchException]
/// instead of guessing.
abstract interface class ChunkSink {
  /// Number of bytes currently stored.
  ///
  /// Implementations create the backing storage if it does not exist yet, so a
  /// freshly created sink reports `0` rather than failing.
  Future<int> length();

  /// Appends [data], which must start at [offset].
  ///
  /// Throws [UploadOffsetMismatchException] when [offset] is not the current
  /// length; nothing is written in that case.
  Future<void> appendAt(int offset, List<int> data);

  /// Makes previously appended bytes durable.
  ///
  /// Called before the session offset is persisted; a host crash must never
  /// leave the stored offset ahead of the bytes on disk.
  Future<void> flush();

  /// Removes the staged bytes.
  ///
  /// Safe to call when nothing was written. Later use of this sink recreates
  /// empty storage.
  Future<void> delete();
}

/// [ChunkSink] backed by a file on disk.
///
/// Each operation opens the file, writes, flushes and closes it again. Holding
/// no handle between calls matters on Windows: an open handle blocks both
/// [delete] and the final atomic rename that publishes the upload.
final class FileChunkSink implements ChunkSink {
  /// Creates a sink for [path], creating missing parent directories on first use.
  ///
  /// [truncateTo] drops tail bytes left over from a session whose acknowledged
  /// offset is smaller than the file (a crash between the write and the session
  /// update). Truncation never extends the file: filling a gap with zeros would
  /// silently corrupt the upload.
  FileChunkSink(this.path, {int? truncateTo}) : _truncateTo = truncateTo;

  /// Absolute path of the staging file.
  final String path;

  final int? _truncateTo;

  bool _prepared = false;

  @override
  Future<int> length() async {
    await _prepare();
    return File(path).length();
  }

  @override
  Future<void> appendAt(int offset, List<int> data) async {
    await _prepare();
    final file = File(path);
    final current = await file.length();
    if (offset != current) {
      throw UploadOffsetMismatchException(expected: current);
    }
    if (data.isEmpty) return;

    // A fresh append-mode handle writes at the end of the file. The offset
    // check above guarantees that end is the position the client acknowledged.
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.writeFrom(data);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> flush() async {
    // Every append already flushes and closes its handle, so no bytes are
    // buffered between calls; this exists for sinks that batch writes.
  }

  @override
  Future<void> delete() async {
    _prepared = false;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Ensures the file and its parents exist and applies [truncateTo] once.
  Future<void> _prepare() async {
    if (_prepared) return;
    final file = File(path);
    // Creates missing parent directories as well; does not touch an existing
    // file, which is what resume needs.
    await file.create(recursive: true);

    final truncateTo = _truncateTo;
    if (truncateTo != null) {
      final current = await file.length();
      if (current > truncateTo) {
        final handle = await file.open(mode: FileMode.append);
        try {
          await handle.truncate(truncateTo);
          await handle.flush();
        } finally {
          await handle.close();
        }
      }
    }
    _prepared = true;
  }
}

/// In-memory [ChunkSink] for tests that exercise the state machine only.
final class MemoryChunkSink implements ChunkSink {
  /// Creates a sink, optionally pre-filled with [initial] bytes.
  MemoryChunkSink([List<int> initial = const <int>[]]) : _bytes = List<int>.of(initial);

  final List<int> _bytes;

  /// Copy of the bytes received so far.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<void> appendAt(int offset, List<int> data) async {
    if (offset != _bytes.length) {
      throw UploadOffsetMismatchException(expected: _bytes.length);
    }
    _bytes.addAll(data);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> delete() async {
    _bytes.clear();
  }
}
