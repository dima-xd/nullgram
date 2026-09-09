import 'dart:typed_data';

/// Process-wide caches behind [ChatAvatar].
///
/// Avatars are rebuilt constantly while scrolling a chat list, and both the
/// on-disk existence check and the minithumbnail decode are far too expensive
/// to redo per frame. Keeping them here — rather than threading maps through
/// every widget — means every list, picker and header shares one warm cache.
abstract final class AvatarCache {
  /// Whether the file at a path was found on disk. Absent when not yet checked.
  static final Map<String, bool> fileExists = {};

  /// Decoded minithumbnail bytes per photo path, null when the photo has none.
  static final Map<String, Uint8List?> miniThumbnails = {};

  /// Forgets the cached existence check for [path].
  ///
  /// Call this when TDLib reports the file downloaded, so the next build
  /// re-reads it from disk instead of trusting a stale "missing" result.
  static void invalidate(String path) => fileExists.remove(path);

  /// Drops everything, for sign-out.
  static void clear() {
    fileExists.clear();
    miniThumbnails.clear();
  }
}
