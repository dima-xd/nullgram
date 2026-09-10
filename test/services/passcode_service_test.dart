import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/passcode_service.dart';

/// Renders a digest the way the RFC test vectors are written.
String hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('derivePasscode', () {
    test('matches the published PBKDF2-HMAC-SHA256 vector', () {
      // From the widely used SHA-256 extension of RFC 6070: P = "password",
      // S = "salt", c = 1, dkLen = 32. Checking against an outside vector is
      // what proves this is really PBKDF2 and not merely self-consistent.
      final derived = derivePasscode((
        passcode: 'password',
        salt: utf8.encode('salt'),
        iterations: 1,
      ));

      expect(
        hex(derived),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('matches the vector for two iterations', () {
      final derived = derivePasscode((
        passcode: 'password',
        salt: utf8.encode('salt'),
        iterations: 2,
      ));

      expect(
        hex(derived),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('derives 32 bytes, the length the stored hash assumes', () {
      final derived = derivePasscode((
        passcode: '1234',
        salt: List.filled(16, 7),
        iterations: 10,
      ));

      expect(derived, hasLength(32));
    });

    test('is deterministic for the same passcode and salt', () {
      final salt = List.filled(16, 3);
      final first = derivePasscode(
        (passcode: '1234', salt: salt, iterations: 10),
      );
      final second = derivePasscode(
        (passcode: '1234', salt: salt, iterations: 10),
      );

      expect(first, second);
    });

    test('a different salt gives a different digest', () {
      // Otherwise two users with the same passcode would share a hash, and
      // one leaked digest would unlock both.
      final first = derivePasscode(
        (passcode: '1234', salt: List.filled(16, 1), iterations: 10),
      );
      final second = derivePasscode(
        (passcode: '1234', salt: List.filled(16, 2), iterations: 10),
      );

      expect(first, isNot(second));
    });

    test('a different passcode gives a different digest', () {
      final salt = List.filled(16, 5);
      final first = derivePasscode(
        (passcode: '1234', salt: salt, iterations: 10),
      );
      final second = derivePasscode(
        (passcode: '1235', salt: salt, iterations: 10),
      );

      expect(first, isNot(second));
    });
  });
}
