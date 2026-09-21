import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:nullgram/app_credentials.dart';
import 'package:nullgram/app_info.dart';
import 'package:path_provider/path_provider.dart';

/// The TDLib parameters shared by every account; only the database and files
/// directory differ, and both are derived from the account itself.
typedef TdlibConfig = ({
  List<int> databaseEncryptionKey,
  int apiId,
  String apiHash,
  String systemLanguageCode,
  String deviceModel,
  String systemVersion,
  String applicationVersion,
});

/// Everything a TDLib client needs to start: where the databases live and the
/// parameters every account shares.
typedef TdlibBootstrap = ({String documentsPath, TdlibConfig config});

/// Resolves the credentials, device facts and paths a TDLib client starts
/// with. Throws when the build ships no credentials, so an isolate must catch.
Future<TdlibBootstrap> resolveTdlibBootstrap() async {
  // Three independent platform round trips that everything below waits on, so
  // they are made at once rather than one after another.
  final (credentials, androidInfo, appDir) = await (
    AppCredentials.resolve(),
    DeviceInfoPlugin().androidInfo,
    getApplicationDocumentsDirectory(),
  ).wait;

  return (
    documentsPath: appDir.path,
    config: (
      databaseEncryptionKey: credentials.databaseEncryptionKey.codeUnits,
      apiId: credentials.apiId,
      apiHash: credentials.apiHash,
      systemLanguageCode: PlatformDispatcher.instance.locale.languageCode,
      deviceModel: androidInfo.model,
      systemVersion: androidInfo.version.release,
      applicationVersion: appVersion,
    ),
  );
}
