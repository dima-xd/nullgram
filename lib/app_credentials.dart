import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Compile-time defines, each an empty string when the build passed none.
const String _apiIdDefine = String.fromEnvironment('API_ID');
const String _apiHashDefine = String.fromEnvironment('API_HASH');
const String _databaseKeyDefine = String.fromEnvironment('DB_ENCRYPTION_KEY');

/// The git-ignored file a local build may keep its credentials in.
///
/// It sits inside an asset *directory* on purpose: an asset file named
/// directly in `pubspec.yaml` must exist or the build fails, while a directory
/// may hold nothing, which is what lets a CI build ship no credentials file at
/// all and pass the values as defines instead.
const String _envAsset = 'assets/config/env';

/// The Telegram credentials and local database key this build signs in with.
///
/// They are deliberately not in the repository. A release build receives them
/// as compile-time defines, which CI fills from its own secrets:
///
/// ```shell
/// flutter build apk --release \
///     --dart-define=API_ID=1234567 \
///     --dart-define=API_HASH=… \
///     --dart-define=DB_ENCRYPTION_KEY=…
/// ```
///
/// A development build can leave the defines out and keep the same three keys
/// in `assets/config/env` instead, in `KEY=value` form.
class AppCredentials {
  const AppCredentials({
    required this.apiId,
    required this.apiHash,
    required this.databaseEncryptionKey,
  });

  /// The Telegram application identifier from my.telegram.org.
  ///
  /// An official application's id cannot be used: Telegram then demands an app
  /// verification token that only that application can produce, and every new
  /// sign-in fails.
  final int apiId;

  /// The application hash that pairs with [apiId].
  final String apiHash;

  /// The key TDLib encrypts each account's local database with.
  ///
  /// Changing it leaves the databases already on the device unreadable, so a
  /// build meant to update an installed app must keep the previous value.
  final String databaseEncryptionKey;

  /// Resolves the credentials, preferring the defines over the local file.
  static Future<AppCredentials> resolve() async {
    // Optional: a build configured entirely through defines ships no such
    // asset, and its absence is not an error.
    await dotenv.load(fileName: _envAsset, isOptional: true);

    return AppCredentials(
      apiId: int.parse(_require('API_ID', _apiIdDefine)),
      apiHash: _require('API_HASH', _apiHashDefine),
      databaseEncryptionKey: _require('DB_ENCRYPTION_KEY', _databaseKeyDefine),
    );
  }
}

/// The value of [name], from its compile-time [define] or the local file.
///
/// Throws instead of falling back to a placeholder: TDLib would answer every
/// request with `API_ID_INVALID`, or quietly create a second database it can
/// never decrypt again, and both are harder to recognize than a missing
/// setting reported at startup.
String _require(String name, String define) {
  if (define.isNotEmpty) return define;

  final value = dotenv.maybeGet(name);
  if (value != null && value.isNotEmpty) return value;

  throw StateError(
    'Missing $name. Pass --dart-define=$name=<value> — CI reads it from the '
    'repository secrets — or add it to $_envAsset.',
  );
}
