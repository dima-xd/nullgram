import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/tdlib/td_bytes.dart';

void main() {
  group('TdBytes.decode', () {
    test('decodes a base64 string', () {
      final encoded = base64Encode([1, 2, 254]);

      expect(TdBytes.decode(encoded), [1, 2, 254]);
    });

    test('decodes a plain list of byte values', () {
      expect(TdBytes.decode([1, 2, 254]), [1, 2, 254]);
    });

    test('wraps signed bytes back into the unsigned range', () {
      // The bridge can emit Java's signed bytes, where 254 arrives as -2.
      expect(TdBytes.decode([-2]), [254]);
    });

    test('returns null for empty or missing data', () {
      expect(TdBytes.decode(null), isNull);
      expect(TdBytes.decode(''), isNull);
      expect(TdBytes.decode(const <int>[]), isNull);
    });

    test('returns null rather than throwing on malformed base64', () {
      expect(TdBytes.decode('not base64!!'), isNull);
    });
  });
}
