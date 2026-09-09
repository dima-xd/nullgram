import 'dart:convert';
import 'dart:typed_data';

/// Decoding for TDLib `bytes` fields.
///
/// The native bridge is inconsistent about how it encodes Java `byte[]`: some
/// responses arrive as a Base64 string, others as a plain JSON array of
/// unsigned byte values. Callers should never have to care, so both shapes are
/// accepted here.
abstract final class TdBytes {
  /// Decodes [raw] into bytes, or returns null when it holds no usable data.
  static Uint8List? decode(dynamic raw) {
    if (raw is String) {
      if (raw.isEmpty) return null;
      try {
        return base64Decode(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is List) {
      if (raw.isEmpty) return null;
      return Uint8List.fromList(
        raw.map((value) => (value as num).toInt() & 0xff).toList(),
      );
    }
    return null;
  }

  /// Encodes [bytes] the way TDLib requests expect a `bytes` field: a Base64
  /// string without line wrapping.
  static String encode(List<int> bytes) => base64Encode(bytes);
}
