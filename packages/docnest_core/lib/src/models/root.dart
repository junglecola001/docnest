import '../ids.dart';
import '../root_status.dart';

/// A whitelisted folder and the rules that apply to it.
class Root {
  const Root({
    required this.id,
    required this.path,
    required this.name,
    this.color,
    this.recursive = true,
    this.maxDepth,
    this.includeExts = const <String>{},
    this.excludeGlobs = const <String>[],
    this.includeHidden = false,
    this.followLinks = false,
    this.localReadOnly = false,
    this.remoteVisible = true,
    this.remoteWritable = false,
    this.uploadTarget = false,
    this.contentIndex = true,
    this.status = RootStatus.offline,
    this.docCount = 0,
    this.lastScanAt,
  });

  final RootId id;

  /// Absolute path managed by the host. Never sent to remote devices.
  final String path;

  final String name;

  /// ARGB color chosen by the user, or `null` for the default.
  final int? color;

  final bool recursive;
  final int? maxDepth;

  /// Lowercase extensions without a dot. Empty means "the default set".
  final Set<String> includeExts;

  /// Glob patterns relative to the root, matched case-insensitively.
  final List<String> excludeGlobs;

  final bool includeHidden;
  final bool followLinks;

  /// Local writes are refused when this is set (remote writes follow
  /// [remoteWritable]).
  final bool localReadOnly;

  final bool remoteVisible;
  final bool remoteWritable;

  /// Phones may use this root as an upload destination.
  final bool uploadTarget;

  final bool contentIndex;
  final RootStatus status;
  final int docCount;
  final DateTime? lastScanAt;

  /// Whether any write (local or remote) is allowed.
  bool get writable => !localReadOnly;

  /// Whether a remote device holding [DeviceScope.upload] may write here.
  bool get acceptsUploads => remoteVisible && remoteWritable && uploadTarget;

  Root copyWith({
    String? path,
    String? name,
    int? Function()? color,
    bool? recursive,
    int? Function()? maxDepth,
    Set<String>? includeExts,
    List<String>? excludeGlobs,
    bool? includeHidden,
    bool? followLinks,
    bool? localReadOnly,
    bool? remoteVisible,
    bool? remoteWritable,
    bool? uploadTarget,
    bool? contentIndex,
    RootStatus? status,
    int? docCount,
    DateTime? Function()? lastScanAt,
  }) {
    return Root(
      id: id,
      path: path ?? this.path,
      name: name ?? this.name,
      color: color == null ? this.color : color(),
      recursive: recursive ?? this.recursive,
      maxDepth: maxDepth == null ? this.maxDepth : maxDepth(),
      includeExts: includeExts ?? this.includeExts,
      excludeGlobs: excludeGlobs ?? this.excludeGlobs,
      includeHidden: includeHidden ?? this.includeHidden,
      followLinks: followLinks ?? this.followLinks,
      localReadOnly: localReadOnly ?? this.localReadOnly,
      remoteVisible: remoteVisible ?? this.remoteVisible,
      remoteWritable: remoteWritable ?? this.remoteWritable,
      uploadTarget: uploadTarget ?? this.uploadTarget,
      contentIndex: contentIndex ?? this.contentIndex,
      status: status ?? this.status,
      docCount: docCount ?? this.docCount,
      lastScanAt: lastScanAt == null ? this.lastScanAt : lastScanAt(),
    );
  }

  @override
  String toString() => 'Root(${id.value}, $name, $path, ${status.wire})';
}
