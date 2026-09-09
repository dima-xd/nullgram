import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Resolves custom (premium) emoji to the stickers that draw them.
///
/// A custom emoji reaches the client as nothing but an id inside a text entity,
/// so every one of them needs a lookup before it can be shown. Two things make
/// a naive per-emoji fetch a bad idea: a single message can carry dozens, and
/// the same handful repeats across a whole chat. So ids asked for within the
/// same frame are coalesced into one request and the answers are remembered for
/// the session.
abstract final class CustomEmojiCache {
  /// TDLib accepts at most 200 ids per request.
  static const int _maxBatch = 200;

  /// How long ids are collected before a request goes out. About one frame:
  /// long enough for a whole message's emoji to land in the same batch,
  /// short enough not to be noticeable.
  static const Duration _batchWindow = Duration(milliseconds: 16);

  /// Stickers keyed by custom emoji id. A null value means TDLib was asked and
  /// had nothing, which is cached too so it isn't asked again.
  static final Map<int, Map<String, dynamic>?> _resolved = {};

  /// Lookups already in flight, so concurrent callers share one request.
  static final Map<int, Completer<Map<String, dynamic>?>> _pending = {};

  /// Ids waiting for the next batch to go out.
  static final Set<int> _queued = {};

  static Timer? _flushTimer;

  /// The lookup a batch goes through.
  ///
  /// Held as a field so a test can stand in for TDLib and observe how ids
  /// are grouped — the batching is the whole point of this cache, and it is
  /// not observable from the outside otherwise.
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(List<int> ids) fetch =
      (ids) => TDLibClient.getCustomEmojiStickers(customEmojiIds: ids);

  /// The sticker for [customEmojiId] if it is already known.
  ///
  /// Safe to call from `build`; returns null when a [resolve] is still needed.
  static Map<String, dynamic>? cached(int customEmojiId) =>
      _resolved[customEmojiId];

  /// Whether [customEmojiId] has been looked up, whatever the outcome.
  static bool isResolved(int customEmojiId) =>
      _resolved.containsKey(customEmojiId);

  /// The sticker for [customEmojiId], fetching it if needed.
  ///
  /// Resolves to null when Telegram doesn't know the emoji — the caller should
  /// then keep showing the plain-text fallback the entity covers.
  static Future<Map<String, dynamic>?> resolve(int customEmojiId) {
    if (_resolved.containsKey(customEmojiId)) {
      return Future.value(_resolved[customEmojiId]);
    }

    final inFlight = _pending[customEmojiId];
    if (inFlight != null) return inFlight.future;

    final completer = Completer<Map<String, dynamic>?>();
    _pending[customEmojiId] = completer;
    _queued.add(customEmojiId);
    _flushTimer ??= Timer(_batchWindow, _flush);
    return completer.future;
  }

  static Future<void> _flush() async {
    _flushTimer = null;
    if (_queued.isEmpty) return;

    final batch = _queued.take(_maxBatch).toList();
    _queued.removeAll(batch);
    // Anything over the per-request cap goes out in the next window.
    if (_queued.isNotEmpty) _flushTimer ??= Timer(_batchWindow, _flush);

    List<Map<String, dynamic>> stickers = const [];
    try {
      stickers = await fetch(batch);
    } catch (e) {
      logger.w('Failed to resolve custom emoji: $e');
    }

    final byId = <int, Map<String, dynamic>>{};
    for (final sticker in stickers) {
      final id = sticker['fullType']?['customEmojiId'] as int?;
      if (id != null) byId[id] = sticker;
    }

    // Every requested id is recorded, found or not, so a missing emoji falls
    // back to its text once and stays that way.
    for (final id in batch) {
      final sticker = byId[id];
      _resolved[id] = sticker;
      _pending.remove(id)?.complete(sticker);
    }
  }

  /// Forgets everything. Called on sign-out, because the file ids inside the
  /// cached stickers belong to the session that fetched them.
  static void clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _queued.clear();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
    _resolved.clear();
  }
}
