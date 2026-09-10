import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// How long the app may stay in the background before it locks again.
enum PasscodeTimeout {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  oneHour(Duration(hours: 1));

  const PasscodeTimeout(this.duration);

  /// How long the app may stay away before the lock re-engages.
  ///
  /// The label belongs to the settings page, which has a context to
  /// translate with.
  final Duration duration;
}

/// The passcode's stored form: a PBKDF2 digest and the salt it used.
///
/// Kept as one record so the two can never be written apart, which would
/// leave a hash that no passcode can ever match.
typedef _StoredPasscode = ({String saltBase64, String hashBase64});

/// Arguments for the isolate that stretches a passcode.
typedef PasscodeDeriveRequest = ({
  String passcode,
  List<int> salt,
  int iterations,
});

/// A local lock over the whole app, independent of the Telegram account.
///
/// Telegram's own passcode works the same way: it guards the app on this
/// device and has nothing to do with two-step verification, which guards the
/// account on the server.
class PasscodeService extends ChangeNotifier {
  PasscodeService._();

  static final PasscodeService instance = PasscodeService._();

  /// Cost of verifying one passcode attempt.
  ///
  /// A four-digit code has almost no entropy of its own, so the stretching is
  /// what makes an offline guess expensive. Kept low enough to stay under a
  /// second on a mid-range phone, and run off the UI isolate either way.
  static const int _iterations = 50000;

  static const String _hashKey = 'passcode.hash';
  static const String _saltKey = 'passcode.salt';
  static const String _timeoutKey = 'passcode.timeout';
  static const String _biometricKey = 'passcode.biometric';

  /// Replaced in tests, which have no Keystore.
  @visibleForTesting
  static FlutterSecureStorage storage = const FlutterSecureStorage();

  /// Replaced in tests, which have no biometric hardware.
  @visibleForTesting
  static LocalAuthentication localAuth = LocalAuthentication();

  _StoredPasscode? _stored;

  PasscodeTimeout _timeout = PasscodeTimeout.immediately;

  bool _isBiometricEnabled = false;

  /// Whether the lock screen is up right now.
  final ValueNotifier<bool> isLocked = ValueNotifier(false);

  /// When the app last went to the background, used to decide whether the
  /// timeout has elapsed.
  DateTime? _backgroundedAt;

  /// Whether a passcode has been set.
  bool get isEnabled => _stored != null;

  PasscodeTimeout get timeout => _timeout;

  /// Whether a fingerprint or face may be used instead of typing the code.
  bool get isBiometricEnabled => _isBiometricEnabled;

  /// Loads the stored passcode and locks straight away if there is one.
  ///
  /// Locking on start is the only correct default: the app has just been
  /// opened, which is exactly the moment the passcode is for.
  Future<void> init() async {
    final hash = await storage.read(key: _hashKey);
    final salt = await storage.read(key: _saltKey);
    if (hash != null && salt != null) {
      _stored = (saltBase64: salt, hashBase64: hash);
    }
    _timeout = _parseTimeout(await storage.read(key: _timeoutKey));
    _isBiometricEnabled = await storage.read(key: _biometricKey) == 'true';

    isLocked.value = isEnabled;
    notifyListeners();
  }

  /// Sets or replaces the passcode.
  Future<void> setPasscode(String passcode) async {
    final salt = _randomSalt();
    final hash = await compute(derivePasscode, (
      passcode: passcode,
      salt: salt,
      iterations: _iterations,
    ));

    _stored = (
      saltBase64: base64Encode(salt),
      hashBase64: base64Encode(hash),
    );
    await storage.write(key: _saltKey, value: _stored!.saltBase64);
    await storage.write(key: _hashKey, value: _stored!.hashBase64);
    notifyListeners();
  }

  /// Removes the passcode and unlocks.
  Future<void> disable() async {
    _stored = null;
    _isBiometricEnabled = false;
    await storage.delete(key: _hashKey);
    await storage.delete(key: _saltKey);
    await storage.delete(key: _biometricKey);
    isLocked.value = false;
    notifyListeners();
  }

  Future<void> setTimeout(PasscodeTimeout timeout) async {
    _timeout = timeout;
    await storage.write(key: _timeoutKey, value: timeout.name);
    notifyListeners();
  }

  /// Turns biometric unlock on or off.
  ///
  /// Returns false when the device cannot do it, so the caller can explain
  /// why the switch snapped back.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled && !await canUseBiometrics()) return false;
    _isBiometricEnabled = enabled;
    await storage.write(key: _biometricKey, value: '$enabled');
    notifyListeners();
    return true;
  }

  /// Whether this device has usable biometric hardware enrolled.
  Future<bool> canUseBiometrics() async {
    try {
      if (!await localAuth.canCheckBiometrics) return false;
      return (await localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Checks [passcode] and unlocks on a match.
  Future<bool> unlockWithPasscode(String passcode) async {
    final stored = _stored;
    if (stored == null) {
      isLocked.value = false;
      return true;
    }

    final hash = await compute(derivePasscode, (
      passcode: passcode,
      salt: base64Decode(stored.saltBase64),
      iterations: _iterations,
    ));
    if (!_matches(hash, base64Decode(stored.hashBase64))) return false;

    isLocked.value = false;
    return true;
  }

  /// Asks the OS for a fingerprint or face and unlocks on success.
  ///
  /// [reason] is the sentence the system prompt shows. It is passed in rather
  /// than built here: this service has no `BuildContext` to translate with.
  Future<bool> unlockWithBiometrics({required String reason}) async {
    if (!_isBiometricEnabled) return false;
    try {
      final authenticated = await localAuth.authenticate(
        localizedReason: reason,
        // Biometrics only: the device PIN is not the app's passcode, so
        // falling back to it would defeat the point of having one.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) return false;
    } catch (_) {
      return false;
    }
    isLocked.value = false;
    return true;
  }

  /// Records that the app went to the background.
  void onBackgrounded() {
    if (!isEnabled || isLocked.value) return;
    _backgroundedAt = DateTime.now();
  }

  /// Locks again if the app was away for longer than the timeout.
  void onForegrounded() {
    if (!isEnabled) return;
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if (DateTime.now().difference(since) >= _timeout.duration) {
      isLocked.value = true;
    }
  }

  static PasscodeTimeout _parseTimeout(String? name) =>
      PasscodeTimeout.values.firstWhere(
        (timeout) => timeout.name == name,
        orElse: () => PasscodeTimeout.immediately,
      );

  static List<int> _randomSalt() {
    final random = Random.secure();
    return [for (var i = 0; i < 16; i++) random.nextInt(256)];
  }

  /// Compares two digests without leaking where they first differ.
  static bool _matches(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

/// Stretches a passcode with PBKDF2-HMAC-SHA256.
///
/// Top-level and public so it can run through [compute]: 50 000 HMAC rounds
/// would drop frames on the UI isolate.
List<int> derivePasscode(PasscodeDeriveRequest request) {
  final hmac = Hmac(sha256, utf8.encode(request.passcode));
  // One block is enough: the derived key is exactly SHA-256's output length,
  // so the block index is always 1.
  var block = hmac.convert([...request.salt, 0, 0, 0, 1]).bytes;
  final result = List<int>.of(block);

  for (var round = 1; round < request.iterations; round++) {
    block = hmac.convert(block).bytes;
    for (var i = 0; i < result.length; i++) {
      result[i] ^= block[i];
    }
  }
  return result;
}
