import 'dart:convert';
import 'dart:typed_data';

import 'package:ntgcalls_flutter/tgcalls.dart';

/// Decodes a TDLib `byte[]` value from an incoming update.
///
/// Incoming updates deliver byte arrays as a JSON list of ints; some paths
/// deliver a Base64 string instead. Handle both so keys/signaling/tags survive
/// regardless of source.
Uint8List tdBytes(dynamic value) {
  if (value == null) return Uint8List(0);
  if (value is Uint8List) return value;
  if (value is String) return base64Decode(value);
  if (value is List) return Uint8List.fromList(value.cast<int>());
  return Uint8List(0);
}

/// Builds the transport [TgCallConfig] from a TDLib `callStateReady` map.
TgCallConfig buildTgCallConfig(
  Map<String, dynamic> ready, {
  required bool isOutgoing,
  required bool isVideo,
}) {
  final servers = (ready['servers'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(_mapServer)
      .toList();

  return TgCallConfig(
    isOutgoing: isOutgoing,
    isVideo: isVideo,
    servers: servers,
    encryptionKey: tdBytes(ready['encryptionKey']),
    config: ready['config'] as String? ?? '',
    customParameters: ready['customParameters'] as String? ?? '',
    maxLayer: (ready['protocol']?['maxLayer'] as int?) ?? 92,
    allowP2p: ready['allowP2p'] as bool? ?? false,
  );
}

TgCallServer _mapServer(Map<String, dynamic> s) {
  final type = s['type'] as Map<String, dynamic>;
  final isReflector = type['@type'] == 'CallServerTypeTelegramReflector';
  Uint8List? peerTag;
  if (isReflector && type['peerTag'] != null) {
    peerTag = tdBytes(type['peerTag']);
  }
  return TgCallServer(
    id: s['id'] as int,
    ipAddress: s['ipAddress'] as String? ?? '',
    ipv6Address: s['ipv6Address'] as String? ?? '',
    port: s['port'] as int? ?? 0,
    username: type['username'] as String?,
    password: type['password'] as String?,
    supportsTurn: type['supportsTurn'] as bool? ?? false,
    supportsStun: type['supportsStun'] as bool? ?? false,
    isReflector: isReflector,
    isTcp: type['isTcp'] as bool? ?? false,
    peerTag: peerTag,
  );
}
