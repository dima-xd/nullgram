import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The kinds of media the rules distinguish.
///
/// TDLib collapses everything that is not a photo or a video into one
/// "other" bucket, and so does Telegram's own settings screen.
enum AutoDownloadKind { photo, video, other }

/// The connections the rules can differ between.
///
/// Roaming is deliberately absent: nothing in the plugin layer reports it, so
/// a roaming switch here would be a control that does nothing.
enum AutoDownloadNetwork {
  mobile('networkTypeMobile'),
  wifi('networkTypeWiFi');

  const AutoDownloadNetwork(this.tdlibType);

  /// The `networkType*` name TDLib knows this connection by.
  ///
  /// The human-readable name lives in the settings page: a service has no
  /// `BuildContext` and so no way to translate one.
  final String tdlibType;
}

/// What may be fetched without the user asking, on one kind of connection.
@immutable
class AutoDownloadRules {
  const AutoDownloadRules({
    this.isEnabled = true,
    this.maxPhotoBytes = _defaultPhotoBytes,
    this.maxVideoBytes = _defaultVideoBytes,
    this.maxOtherBytes = _defaultOtherBytes,
  });

  static const int _defaultPhotoBytes = 10 * 1024 * 1024;
  static const int _defaultVideoBytes = 15 * 1024 * 1024;
  static const int _defaultOtherBytes = 3 * 1024 * 1024;

  /// The master switch. When false nothing downloads on its own, whatever the
  /// size limits say.
  final bool isEnabled;

  final int maxPhotoBytes;
  final int maxVideoBytes;
  final int maxOtherBytes;

  /// Everything off, for a metered connection.
  static const AutoDownloadRules off = AutoDownloadRules(isEnabled: false);

  /// The byte ceiling for [kind]. Zero means "never".
  int limitFor(AutoDownloadKind kind) => switch (kind) {
    AutoDownloadKind.photo => maxPhotoBytes,
    AutoDownloadKind.video => maxVideoBytes,
    AutoDownloadKind.other => maxOtherBytes,
  };

  AutoDownloadRules copyWith({
    bool? isEnabled,
    int? maxPhotoBytes,
    int? maxVideoBytes,
    int? maxOtherBytes,
  }) => AutoDownloadRules(
    isEnabled: isEnabled ?? this.isEnabled,
    maxPhotoBytes: maxPhotoBytes ?? this.maxPhotoBytes,
    maxVideoBytes: maxVideoBytes ?? this.maxVideoBytes,
    maxOtherBytes: maxOtherBytes ?? this.maxOtherBytes,
  );

  /// The TDLib `autoDownloadSettings` object these rules stand for.
  ///
  /// The preload and call fields are TDLib's own concern and are left at
  /// values that match the app's behaviour rather than exposed as settings.
  Map<String, dynamic> toTdlib() => {
    "@type": "autoDownloadSettings",
    "isAutoDownloadEnabled": isEnabled,
    "maxPhotoFileSize": maxPhotoBytes,
    "maxVideoFileSize": maxVideoBytes,
    "maxOtherFileSize": maxOtherBytes,
    "videoUploadBitrate": 0,
    "preloadLargeVideos": false,
    "preloadNextAudio": false,
    "preloadStories": false,
    "useLessDataForCalls": false,
  };
}

/// Decides what the app fetches by itself, and remembers the choice.
///
/// Without this every photo needed a tap before it appeared, which is the
/// one thing about a messenger nobody expects to have to do.
class AutoDownloadService extends ChangeNotifier {
  AutoDownloadService._();

  static final AutoDownloadService instance = AutoDownloadService._();

  /// Swapped out in tests, which have no platform channels.
  @visibleForTesting
  static Connectivity connectivity = Connectivity();

  final Map<AutoDownloadNetwork, AutoDownloadRules> _rules = {
    for (final network in AutoDownloadNetwork.values)
      network: const AutoDownloadRules(),
  };

  AutoDownloadNetwork _current = AutoDownloadNetwork.wifi;

  /// Whether TDLib has been told the network at least once.
  bool _hasReportedNetwork = false;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// The connection in use right now.
  AutoDownloadNetwork get current => _current;

  /// The rules for [network].
  AutoDownloadRules rulesFor(AutoDownloadNetwork network) =>
      _rules[network] ?? const AutoDownloadRules();

  /// Loads the stored rules and starts following the connection.
  ///
  /// Safe to call more than once; a second call only refreshes the network.
  Future<void> init() async {
    await _restore();
    await _applyConnectivity(await connectivity.checkConnectivity());
    _subscription ??= connectivity.onConnectivityChanged.listen(
      _applyConnectivity,
    );
  }

  /// Tells an account's TDLib client which network it is on.
  ///
  /// Each account has its own client, and a client only learns the network
  /// type from a call like this one, so the account brought on screen by a
  /// switch has to be told again.
  Future<void> reportNetwork({int? accountId}) =>
      TDLibClient.setNetworkType(_current.tdlibType, accountId: accountId);

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  /// Stores [rules] for [network] and tells TDLib about them.
  Future<void> update(
    AutoDownloadNetwork network,
    AutoDownloadRules rules,
  ) async {
    _rules[network] = rules;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(network, 'enabled'), rules.isEnabled);
    await preferences.setInt(_key(network, 'photo'), rules.maxPhotoBytes);
    await preferences.setInt(_key(network, 'video'), rules.maxVideoBytes);
    await preferences.setInt(_key(network, 'other'), rules.maxOtherBytes);

    // Mirrored to the server so the same limits apply on other clients.
    await TDLibClient.setAutoDownloadSettings(
      settings: rules.toTdlib(),
      networkType: network.tdlibType,
    );
  }

  /// Whether a [kind] file of [sizeBytes] may be fetched without a tap.
  ///
  /// An unknown size (TDLib reports zero until the file is known) is treated
  /// as too large, so a surprise download can never start on mobile data.
  bool shouldDownload(AutoDownloadKind kind, int sizeBytes) {
    final rules = rulesFor(_current);
    if (!rules.isEnabled) return false;
    if (sizeBytes <= 0) return false;
    return sizeBytes <= rules.limitFor(kind);
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    for (final network in AutoDownloadNetwork.values) {
      const fallback = AutoDownloadRules();
      _rules[network] = AutoDownloadRules(
        isEnabled:
            preferences.getBool(_key(network, 'enabled')) ?? fallback.isEnabled,
        maxPhotoBytes:
            preferences.getInt(_key(network, 'photo')) ??
            fallback.maxPhotoBytes,
        maxVideoBytes:
            preferences.getInt(_key(network, 'video')) ??
            // Mobile data starts stricter than Wi-Fi, as Telegram does.
            (network == AutoDownloadNetwork.mobile
                ? 0
                : fallback.maxVideoBytes),
        maxOtherBytes:
            preferences.getInt(_key(network, 'other')) ??
            fallback.maxOtherBytes,
      );
    }
    notifyListeners();
  }

  Future<void> _applyConnectivity(List<ConnectivityResult> results) async {
    // A device can report several transports at once (Wi-Fi behind a VPN, for
    // instance). Mobile is the metered one, so it wins the tie.
    final network = results.contains(ConnectivityResult.mobile)
        ? AutoDownloadNetwork.mobile
        : AutoDownloadNetwork.wifi;
    // The first call always goes through: TDLib has to be told the network
    // even when it happens to match this service's starting guess.
    if (network == _current && _hasReportedNetwork) return;
    _current = network;
    _hasReportedNetwork = true;
    notifyListeners();

    await TDLibClient.setNetworkType(network.tdlibType);
  }

  static String _key(AutoDownloadNetwork network, String field) =>
      'autoDownload.${network.name}.$field';
}

/// Starts an automatic download of [file] when the rules allow it.
///
/// Returns whether a download was started, so a caller can fall back to
/// showing a tap-to-download affordance.
bool autoDownloadFile(Map<String, dynamic>? file, AutoDownloadKind kind) {
  if (file == null) return false;

  final local = file['local'] as Map<String, dynamic>?;
  if (local?['isDownloadingCompleted'] == true) return false;
  if (local?['isDownloadingActive'] == true) return false;

  final size = (file['size'] as num?)?.toInt() ?? 0;
  final bytes = size > 0
      ? size
      : (file['expectedSize'] as num?)?.toInt() ?? 0;
  if (!AutoDownloadService.instance.shouldDownload(kind, bytes)) return false;

  final fileId = (file['id'] as num?)?.toInt();
  if (fileId == null) return false;
  TDLibClient.downloadFile(fileId: fileId).catchError((_) {});
  return true;
}
