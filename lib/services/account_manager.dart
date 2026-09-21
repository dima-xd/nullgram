import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/services/auto_download.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/services/notification_service.dart';
import 'package:nullgram/services/push_service.dart';
import 'package:nullgram/services/tdlib_bootstrap.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A production filter, or a release build logs nothing at all, including the
// line that says an account could not be brought online for a push.
final _log = Logger(filter: ProductionFilter());

/// One account known to the app, signed in or half-way through signing in.
@immutable
class Account {
  /// Creates an account record. A freshly added account has no [userId] yet.
  const Account({
    required this.id,
    required this.directory,
    this.isPending = false,
    this.userId = 0,
    this.name = '',
    this.phoneNumber = '',
  });

  /// Reads a record written by [toJson].
  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: (json['id'] as num).toInt(),
        directory: json['directory'] as String? ?? '',
        isPending: json['isPending'] as bool? ?? false,
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
      );

  /// Identifies the account's TDLib client in the native bridge.
  final int id;

  /// The account's database directory, relative to the documents directory.
  ///
  /// Empty for the account that predates multi-account support: its database
  /// is the documents directory itself. Moving it would look like a fresh
  /// install and sign the user out, so the empty value is preserved forever.
  final String directory;

  /// Whether this account was added but never finished signing in, which makes
  /// it disposable.
  ///
  /// Stored rather than derived from [userId]: at startup a client has not
  /// answered `getMe` yet, and treating "no user id yet" as "never signed in"
  /// would let a switch discard a perfectly good account.
  final bool isPending;

  /// The signed-in user's id, or zero before its client has answered.
  final int userId;

  /// The signed-in user's display name, cached so the switcher can be drawn
  /// before any of TDLib's clients have answered.
  final String name;

  /// The signed-in user's phone number, without a leading plus.
  final String phoneNumber;

  /// Returns a copy with the given fields replaced.
  Account copyWith({
    bool? isPending,
    int? userId,
    String? name,
    String? phoneNumber,
  }) =>
      Account(
        id: id,
        directory: directory,
        isPending: isPending ?? this.isPending,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        phoneNumber: phoneNumber ?? this.phoneNumber,
      );

  /// The record as stored in preferences.
  Map<String, dynamic> toJson() => {
        'id': id,
        'directory': directory,
        'isPending': isPending,
        'userId': userId,
        'name': name,
        'phoneNumber': phoneNumber,
      };
}

/// The id to give the next added account.
///
/// Ids are never reused, so a directory left behind by a removed account can
/// never be adopted by a different one.
int nextAccountId(Iterable<Account> accounts) {
  if (accounts.isEmpty) return TDLibClient.defaultAccountId;
  return accounts.map((account) => account.id).reduce(max) + 1;
}

/// The database directory of the account with [id], relative to the documents
/// directory.
String accountDirectory(int id) => 'account_$id';

/// Decodes the persisted account list, tolerating a missing or corrupt value.
List<Account> decodeAccounts(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map<String, dynamic>) Account.fromJson(entry),
    ];
  } catch (e) {
    _log.w('Discarding unreadable account list', error: e);
    return const [];
  }
}

/// Encodes an account list for [decodeAccounts].
String encodeAccounts(Iterable<Account> accounts) =>
    jsonEncode([for (final account in accounts) account.toJson()]);

/// Keeps every account signed in at once and decides which one is on screen.
///
/// Each account has its own TDLib client and its own database directory, and
/// all of them stay connected, so an account that is not on screen still
/// delivers notifications and unread counts. Switching therefore costs nothing
/// but a repaint: no client is torn down and nothing is re-downloaded.
class AccountManager extends ChangeNotifier {
  AccountManager._();

  /// The shared instance.
  static final AccountManager instance = AccountManager._();

  static const String _accountsKey = 'accounts.list';
  static const String _activeKey = 'accounts.active';

  List<Account> _accounts = const [];
  int _activeId = TDLibClient.defaultAccountId;
  bool _isSwitching = false;

  final Map<int, Map<String, dynamic>> _profiles = {};
  final Map<int, int> _unread = {};

  /// Accounts told to log out, mapped to the directory to delete once TDLib
  /// reports their client closed.
  final Map<int, String> _closing = {};

  /// Accounts whose client has already been given its parameters.
  ///
  /// Every client reports `WaitTdlibParameters` the moment it is created, so
  /// that state only means something is wrong once this session has already
  /// configured the account.
  final Set<int> _configured = {};

  /// Accounts whose client started and was configured without throwing,
  /// unlike [_configured], which is set before the options round trip.
  final Set<int> _online = {};

  /// Accounts whose parameters were re-sent after their client turned up
  /// unconfigured, so the repair is attempted at most once per session.
  final Set<int> _reconfigured = {};

  late SharedPreferences _preferences;
  late String _documentsPath;
  late TdlibConfig _config;

  /// Every known account, in the order they were added.
  List<Account> get accounts => List.unmodifiable(_accounts);

  /// The account currently on screen.
  int get activeId => _activeId;

  /// The record of the account currently on screen, if it is still known.
  Account? get active => accountOf(_activeId);

  /// Whether more than one account is signed in.
  bool get hasMultipleAccounts => _accounts.length > 1;

  /// Whether a switch is in flight.
  ///
  /// The app's auth navigation ignores authorization states while this is set:
  /// the account being left behind keeps reporting states — a signed-out one
  /// reports `WaitPhoneNumber` — which would otherwise throw the user onto the
  /// login screen for a frame.
  bool get isSwitching => _isSwitching;

  /// Whether [id] has a started, configured client in this isolate.
  bool isOnline(int id) => _online.contains(id);

  /// The account with [id], or null when it is unknown.
  Account? accountOf(int id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// The `user` object of [id], available once its client has answered.
  ///
  /// Used for the avatar in the switcher: the photo is read straight off disk,
  /// never downloaded, because TDLib file ids belong to the client that issued
  /// them and mean nothing to another account's client.
  Map<String, dynamic>? profileOf(int id) => _profiles[id];

  /// The number of chats with unmuted unread messages in [id].
  int unreadOf(int id) => _unread[id] ?? 0;

  /// The account's database directory as an absolute path.
  String directoryOf(Account account) => account.directory.isEmpty
      ? _documentsPath
      : '$_documentsPath/${account.directory}';

  /// Loads the account list and brings every account online.
  ///
  /// Must run after [TDLibClient.initTdlibUpdates] and before the first frame:
  /// it is what supplies TDLib its parameters, which nothing else does now.
  Future<void> init({
    required String documentsPath,
    required TdlibConfig config,
  }) async {
    _documentsPath = documentsPath;
    _config = config;
    _preferences = await SharedPreferences.getInstance();

    _accounts = decodeAccounts(_preferences.getString(_accountsKey));
    _activeId =
        _preferences.getInt(_activeKey) ?? TDLibClient.defaultAccountId;
    if (_accounts.isEmpty) _accounts = [_legacyAccount()];
    _pruneAbandoned();
    if (accountOf(_activeId) == null) _activeId = _accounts.first.id;
    await _persist();

    // Installed rather than imported the other way round: the push service
    // has no business knowing which accounts exist.
    PushService.instance.reregisterAccounts = _registerAll;

    TDLibClient.unreadCountUpdates.listen(_onUnreadUpdate);
    TDLibClient.backgroundUpdates.listen(_onBackgroundUpdate);
    TDLibClient.authStateUpdates.listen(_onAuthUpdate);

    // Set before the clients start, so the active account's very first
    // authorization state is not mistaken for a background account's.
    _log.i('Accounts ${[
      for (final account in _accounts)
        '${account.id}:${account.directory.isEmpty ? '<legacy>' : account.directory}'
            '${account.isPending ? ':pending' : ''}',
    ].join(', ')}, active $_activeId');

    // Set before the clients start, so the active account's very first
    // authorization state is not mistaken for a background account's.
    await TDLibClient.setActiveAccount(_activeId);
    // Started together: each account's client is independent, and starting
    // them one after another put every account's round trips in front of the
    // first frame.
    await Future.wait(_accounts.map(_startClient));
  }

  /// Registers every signed-in account for pushes again, after a token
  /// refresh made the previous registrations worthless.
  Future<void> _registerAll() async {
    for (final account in _accounts) {
      if (account.isPending) continue;
      await PushService.instance.register(account.id);
    }
  }

  /// Brings one account online without touching the rest, for the push
  /// isolate and the shade actions, which have only seconds to live.
  Future<void> initSingle({
    required String documentsPath,
    required TdlibConfig config,
    required int accountId,
  }) async {
    _documentsPath = documentsPath;
    _config = config;
    _preferences = await SharedPreferences.getInstance();

    _accounts = decodeAccounts(_preferences.getString(_accountsKey));
    if (_accounts.isEmpty) _accounts = [_legacyAccount()];

    final account = accountOf(accountId);
    if (account == null) {
      _log.w('No account $accountId to bring online');
      return;
    }
    await _startClient(account);
    _activeId = accountId;
    // Assigned rather than set through the bridge: the native active account
    // is process-wide, and retargeting it would hijack the running app.
    TDLibClient.activeAccountId = accountId;
  }

  /// The account of an install that predates multi-account support.
  Account _legacyAccount() {
    _activeId = TDLibClient.defaultAccountId;
    return const Account(id: TDLibClient.defaultAccountId, directory: '');
  }

  /// Forgets accounts whose sign-in was abandoned, for instance because the
  /// app was killed on the login screen of a newly added account.
  void _pruneAbandoned() {
    final abandoned = [
      for (final account in _accounts)
        if (account.isPending && account.id != _activeId) account,
    ];
    if (abandoned.isEmpty) return;
    _accounts = [
      for (final account in _accounts)
        if (!abandoned.contains(account)) account,
    ];
    for (final account in abandoned) {
      _deleteDirectory(account);
    }
  }

  /// Brings one account online.
  Future<void> _startClient(Account account) async {
    final directory = directoryOf(account);
    try {
      await Directory(directory).create(recursive: true);
    } catch (e) {
      _log.e('Cannot create the database directory of account ${account.id}',
          error: e);
      return;
    }

    await TDLibClient.createAccount(account.id);
    await TDLibClient.setTdlibParameters(
      accountId: account.id,
      useTestDc: false,
      databaseDirectory: directory,
      filesDirectory: directory,
      databaseEncryptionKey: _config.databaseEncryptionKey,
      useFileDatabase: true,
      useChatInfoDatabase: true,
      useMessageDatabase: true,
      useSecretChats: true,
      apiId: _config.apiId,
      apiHash: _config.apiHash,
      systemLanguageCode: _config.systemLanguageCode,
      deviceModel: _config.deviceModel,
      systemVersion: _config.systemVersion,
      applicationVersion: _config.applicationVersion,
    );
    _configured.add(account.id);

    // TDLib sends no notification updates at all until the group count is
    // positive, which is what makes the whole notification path work.
    await TDLibClient.setIntOption(
      name: 'notification_group_count_max',
      value: 25,
      accountId: account.id,
    );
    await TDLibClient.setIntOption(
      name: 'notification_group_size_max',
      value: 10,
      accountId: account.id,
    );
    _online.add(account.id);
  }

  /// Brings [accountId] on screen.
  Future<void> switchTo(int accountId) async {
    if (accountId == _activeId || accountOf(accountId) == null) return;
    // A second switch that starts while one is still in flight would find the
    // new account's chats on screen and stash them under the id of the account
    // already left behind, mixing two accounts together for the rest of the
    // session. One switch at a time.
    if (_isSwitching) return;

    final previous = _activeId;

    _isSwitching = true;
    // Claimed before the first await, so nothing that runs in between can
    // still believe the previous account is the one on screen.
    _activeId = accountId;
    notifyListeners();

    // Swapped rather than dropped: the account being left keeps its chats, so
    // coming back to it paints at once instead of re-fetching the whole list.
    ChatStore.instance.swap(from: previous, to: accountId);
    await TDLibClient.setActiveAccount(accountId);

    _isSwitching = false;
    notifyListeners();

    // The new account reached its authorization state long ago and will not
    // report it again, so it is replayed to drive the app's auth navigation.
    await TDLibClient.refreshAuthorizationState();

    // Off the critical path of the switch: a preferences write, the shutdown
    // of an abandoned client and a round trip to TDLib decide nothing about
    // what is on screen, and waiting for them only delayed the new account.
    await _persist();
    await _dropIfPending(previous);
    await AutoDownloadService.instance.reportNetwork();
  }

  /// Adds an account and takes the user to its login screen.
  Future<void> addAccount() async {
    final id = nextAccountId(_accounts);
    final account = Account(
      id: id,
      directory: accountDirectory(id),
      isPending: true,
    );
    _accounts = [..._accounts, account];
    await _persist();
    await _startClient(account);
    await switchTo(id);
  }

  /// Whether the account on screen was just added and can be abandoned.
  ///
  /// Adding an account replaces the whole navigation stack with a login
  /// screen, so without a way to cancel there would be no route back to the
  /// account that is already signed in.
  bool get canCancelPendingAccount =>
      (active?.isPending ?? false) &&
      _accounts.any((account) => !account.isPending);

  /// Abandons a newly added account and returns to a signed-in one.
  Future<void> cancelPendingAccount() async {
    if (!canCancelPendingAccount) return;
    final replacement = _accounts.firstWhere((account) => !account.isPending);
    await switchTo(replacement.id);
  }

  /// Signs [accountId] out and removes it from the switcher.
  ///
  /// The active account is left first, so the sign-out — which ends with the
  /// login screen — never becomes the thing on screen.
  Future<void> removeAccount(int accountId) async {
    final account = accountOf(accountId);
    if (account == null) return;

    if (accountId == _activeId) {
      final replacement = _accounts.firstWhere(
        (candidate) => candidate.id != accountId,
        orElse: () => account,
      );
      if (replacement.id == accountId) {
        // The last account: sign out in place and let the login screen show.
        await TDLibClient.logOut();
        return;
      }
      await switchTo(replacement.id);
    }

    await _forget(account);
    await TDLibClient.logOut(accountId: accountId);
  }

  /// Drops [account] from the list right away and remembers what to delete
  /// once its client reports itself closed.
  Future<void> _forget(Account account) async {
    _closing[account.id] = account.directory;
    // The single point every removal passes through, so the push registration
    // is dropped here rather than once per way of signing an account out.
    unawaited(PushService.instance.forget(account.id));
    unawaited(NotificationService.instance.clearAccount(account.id));
    ChatStore.instance.forgetSnapshot(account.id);
    _accounts = [
      for (final other in _accounts)
        if (other.id != account.id) other,
    ];
    _profiles.remove(account.id);
    _unread.remove(account.id);
    _online.remove(account.id);
    await _persist();
    notifyListeners();
  }

  /// Removes [accountId] if it was added but never signed in.
  Future<void> _dropIfPending(int accountId) async {
    final account = accountOf(accountId);
    if (account == null || !account.isPending) return;
    ChatStore.instance.forgetSnapshot(accountId);
    _accounts = [
      for (final other in _accounts)
        if (other.id != accountId) other,
    ];
    await _persist();
    await TDLibClient.closeAccount(accountId);
    await _deleteDirectory(account);
    notifyListeners();
  }

  Future<void> _persist() async {
    await _preferences.setString(_accountsKey, encodeAccounts(_accounts));
    await _preferences.setInt(_activeKey, _activeId);
  }

  /// Deletes an account's database, refusing to touch the legacy directory.
  Future<void> _deleteDirectory(Account account) async {
    // The legacy account's database *is* the documents directory, which holds
    // unrelated app data. Deleting it would take the whole install with it.
    if (account.directory.isEmpty) return;
    try {
      await Directory(directoryOf(account)).delete(recursive: true);
    } catch (e) {
      _log.w('Could not delete the database of account ${account.id}',
          error: e);
    }
  }

  void _onUnreadUpdate(Map<String, dynamic> update) {
    if (update['chatList']?['@type'] != 'ChatListMain') return;
    final accountId =
        update['@accountId'] as int? ?? TDLibClient.activeAccountId;
    _unread[accountId] = (update['unreadUnmutedCount'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  void _onBackgroundUpdate(Map<String, dynamic> update) {
    if (update['@type'] != updateAuthorizationStateConst) return;
    final accountId = update['@accountId'] as int?;
    if (accountId == null) return;

    switch (update['authorizationState']?['@type']) {
      // A background account is signed in too, and its name and photo are
      // wanted for the switcher, so its identity is read here rather than at
      // startup — where no client has answered yet.
      case 'AuthorizationStateReady':
        _refreshProfile(accountId);
        unawaited(PushService.instance.register(accountId));
      case 'AuthorizationStateWaitTdlibParameters':
        _reconfigure(accountId);
      case 'AuthorizationStateClosed':
        _finishRemoval(accountId);
    }
  }

  /// Re-sends the parameters of a client that turned up unconfigured.
  ///
  /// A client without parameters answers every request with "call unexpected"
  /// and reports no further state, so nothing on screen explains why the
  /// account is dead. Rather than leave the account stuck until the app is
  /// reinstalled, its configuration is simply sent again.
  Future<void> _reconfigure(int accountId) async {
    final account = accountOf(accountId);
    if (account == null) return;
    if (!_configured.contains(accountId)) return;
    if (!_reconfigured.add(accountId)) return;
    _log.w('Account $accountId has no parameters; sending them again');
    await _startClient(account);
  }

  /// Completes a sign-out: the client has closed, so its database can go.
  Future<void> _finishRemoval(int accountId) async {
    final directory = _closing.remove(accountId);
    if (directory == null) return;
    await TDLibClient.closeAccount(accountId);
    await _deleteDirectory(Account(id: accountId, directory: directory));
  }

  void _onAuthUpdate(Map<String, dynamic> state) {
    final accountId = state['@accountId'] as int?;
    if (accountId != null && accountId != _activeId) return;

    switch (state['@type']) {
      case 'AuthorizationStateReady':
        _refreshProfile(_activeId);
        unawaited(PushService.instance.register(_activeId));
      case 'AuthorizationStateWaitTdlibParameters':
        _reconfigure(_activeId);
      case 'AuthorizationStateLoggingOut':
        unawaited(PushService.instance.forget(_activeId));
        _onActiveLoggingOut();
    }
  }

  /// Handles a sign-out started elsewhere, typically from the settings screen.
  ///
  /// With another account available the app moves to it instead of showing the
  /// login screen, which is what makes "log out" behave like Telegram's.
  Future<void> _onActiveLoggingOut() async {
    final account = accountOf(_activeId);
    if (account == null) return;

    if (!hasMultipleAccounts) {
      // Back to a single, signed-out account: forget the cached identity so
      // the switcher does not keep showing a name nobody is signed in as.
      _accounts = [Account(id: account.id, directory: account.directory)];
      _profiles.remove(account.id);
      _unread.remove(account.id);
      await _persist();
      notifyListeners();
      return;
    }

    final replacement =
        _accounts.firstWhere((candidate) => candidate.id != account.id);
    await _forget(account);
    await switchTo(replacement.id);
  }

  /// Reads the signed-in user of [accountId] and caches its name and phone.
  Future<void> _refreshProfile(int accountId) async {
    final me = await TDLibClient.getMe(accountId: accountId);
    final userId = (me?['id'] as num?)?.toInt();
    if (me == null || userId == null || userId == 0) return;

    _profiles[accountId] = me;
    // Reaching `getMe` means the account is signed in, so it stops being
    // disposable.
    final name = [me['firstName'], me['lastName']]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
    _accounts = [
      for (final account in _accounts)
        account.id == accountId
            ? account.copyWith(
                isPending: false,
                userId: userId,
                name: name,
                phoneNumber: me['phoneNumber'] as String? ?? '',
              )
            : account,
    ];
    await _persist();
    notifyListeners();
  }
}

/// Brings [accountId] online in an isolate with no app around it, resolving
/// what `main` would. Safe to repeat: a later push finds it already online.
Future<void> bringAccountOnline(int accountId) async {
  // The callers are entry points of their own isolates, where nothing else
  // has set the binding up that every plugin below needs.
  WidgetsFlutterBinding.ensureInitialized();
  TDLibClient.initTdlibUpdates();

  if (AccountManager.instance.isOnline(accountId)) return;

  final TdlibBootstrap bootstrap;
  try {
    bootstrap = await resolveTdlibBootstrap();
  } catch (e) {
    // Unhandled, this would lose the push without a word: a build with no
    // credentials cannot start a client at all.
    _log.e('Cannot bring account $accountId online', error: e);
    return;
  }

  await AccountManager.instance.initSingle(
    documentsPath: bootstrap.documentsPath,
    accountId: accountId,
    config: bootstrap.config,
  );
}
