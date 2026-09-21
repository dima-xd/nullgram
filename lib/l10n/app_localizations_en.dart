// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get comments => 'Comments';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String get leaveComment => 'Leave a comment';

  @override
  String get noCommentsYet => 'No comments yet';

  @override
  String get noCommentsHint => 'Be the first to comment on this post.';

  @override
  String get joinDiscussion => 'Join discussion';

  @override
  String get threadUnavailable => 'This message has no discussion.';

  @override
  String get passcodeSubtitle => 'A local lock over the app itself';

  @override
  String get passcodeExplanation =>
      'A passcode locks this app on this device. It is separate from two-step verification, which protects the account itself.';

  @override
  String get twoStepSubtitle => 'A password on top of the login code';

  @override
  String get videoMessageHint => 'A round clip, up to a minute';

  @override
  String get amoledDark => 'AMOLED dark';

  @override
  String get about => 'About';

  @override
  String get accept => 'Accept';

  @override
  String get add => 'Add';

  @override
  String get addProxy => 'Add a proxy';

  @override
  String get addAnswer => 'Add an answer';

  @override
  String get addFromCopiedLink => 'Add from a copied link';

  @override
  String get addLink => 'Add link';

  @override
  String get addMembers => 'Add members';

  @override
  String get all => 'All';

  @override
  String get anonymousVoting => 'Anonymous voting';

  @override
  String get passcodeDisableWarning =>
      'Anyone with this phone unlocked will be able to open the app.';

  @override
  String get sharedMediaEmpty => 'Anything shared in this chat shows up here.';

  @override
  String get archivedChatsTitle => 'Archived Chats';

  @override
  String get archivedChats => 'Archived chats';

  @override
  String get atLeastFourCharacters => 'At least 4 characters';

  @override
  String get autoDeleteMessages => 'Auto-delete messages';

  @override
  String get automaticMediaDownload => 'Automatic media download';

  @override
  String get backspace => 'Backspace';

  @override
  String get bio => 'Bio';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get botCommands => 'Bot commands';

  @override
  String get call => 'Call';

  @override
  String get callBack => 'Call back';

  @override
  String get calls => 'Calls';

  @override
  String get callsEmpty => 'Calls you make and receive will appear here.';

  @override
  String get camera => 'Camera';

  @override
  String get cameraAccessDenied => 'Camera access denied';

  @override
  String get cancel => 'Cancel';

  @override
  String get changePasscode => 'Change passcode';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get channels => 'Channels';

  @override
  String get checkAgain => 'Check again';

  @override
  String get clear => 'Clear';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheQuestion => 'Clear cache?';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryQuestion => 'Clear history?';

  @override
  String get contact => 'Contact';

  @override
  String get contacts => 'Contacts';

  @override
  String get contactsEmpty => 'Contacts you add on Telegram will show up here.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get copied => 'Copied';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get copyLink => 'Copy link';

  @override
  String get copyTranslation => 'Copy translation';

  @override
  String get passwordChangeFailed =>
      'Could not change the password. Check the old one.';

  @override
  String get joinFailed => 'Could not join the chat';

  @override
  String get secretChatFailed => 'Could not start a secret chat';

  @override
  String get createPoll => 'Create poll';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get currentPassword => 'Current password';

  @override
  String get dark => 'Dark';

  @override
  String get dataAndStorage => 'Data and storage';

  @override
  String get decline => 'Decline';

  @override
  String get delete => 'Delete';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deliveredWhenBack => 'Delivered once they are back';

  @override
  String get description => 'Description';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get devices => 'Devices';

  @override
  String get document => 'Document';

  @override
  String get downloadAutomatically => 'Download automatically';

  @override
  String get downloadedMedia => 'Downloaded media';

  @override
  String get clearCacheExplanation =>
      'Downloaded photos, videos and files will be removed from this device. They stay on Telegram and download again when opened.';

  @override
  String get edit => 'Edit';

  @override
  String get editBio => 'Edit bio';

  @override
  String get editMessage => 'Edit message';

  @override
  String get editName => 'Edit name';

  @override
  String get editUsername => 'Edit username';

  @override
  String get endCall => 'End';

  @override
  String get enterTheCode => 'Enter the code';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get enterPhoneToContinue => 'Enter your phone number to continue';

  @override
  String get files => 'Files';

  @override
  String get filesAndVoice => 'Files and voice';

  @override
  String get findPeopleAndGroups => 'Find people and groups';

  @override
  String get biometricsHint => 'Fingerprint or face, when enrolled';

  @override
  String get firstName => 'First name';

  @override
  String get flipCamera => 'Flip';

  @override
  String get forEveryone => 'For everyone';

  @override
  String get forward => 'Forward';

  @override
  String get forwardTo => 'Forward to…';

  @override
  String get gif => 'GIF';

  @override
  String get generatingQrCode => 'Generating QR code...';

  @override
  String get groups => 'Groups';

  @override
  String get hintOptional => 'Hint (optional)';

  @override
  String get scheduledEmptyHint =>
      'Hold the send button in a chat to schedule a message.';

  @override
  String get holdToRecord => 'Hold to record a voice message';

  @override
  String get notificationScopeHint =>
      'Individual chats keep their own mute setting, which overrides these defaults.';

  @override
  String get inviteLink => 'Invite link';

  @override
  String get inviteLinkCopied => 'Invite link copied';

  @override
  String get join => 'Join';

  @override
  String get languagePacks => 'Language packs';

  @override
  String get lastName => 'Last name';

  @override
  String get lastNameOptional => 'Last name (optional)';

  @override
  String get leaveChat => 'Leave chat';

  @override
  String get light => 'Light';

  @override
  String get links => 'Links';

  @override
  String get localDatabase => 'Local database';

  @override
  String get lockTheApp => 'Lock the app';

  @override
  String get loginByQrCode => 'Log in by QR Code';

  @override
  String get loginByPhone => 'Log in by phone number';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutQuestion => 'Log out?';

  @override
  String get media => 'Media';

  @override
  String get autoDownloadExplanation =>
      'Media under these sizes appears without a tap. Anything larger keeps its download button.';

  @override
  String get members => 'Members';

  @override
  String get messageActions => 'Message actions';

  @override
  String get microphonePermissionRequired => 'Microphone permission required';

  @override
  String get minimize => 'Minimize';

  @override
  String get more => 'More';

  @override
  String get multipleAnswers => 'Multiple answers';

  @override
  String get music => 'Music';

  @override
  String get mute => 'Mute';

  @override
  String get myProfile => 'My Profile';

  @override
  String get name => 'Name';

  @override
  String get newChannelTitle => 'New Channel';

  @override
  String get newGroupTitle => 'New Group';

  @override
  String get newChannel => 'New channel';

  @override
  String get newGroup => 'New group';

  @override
  String get newMessage => 'New message';

  @override
  String get autoDeleteExplanation =>
      'New messages in this chat are deleted for everyone after the chosen time. Messages already sent are unaffected.';

  @override
  String get newPassword => 'New password';

  @override
  String get newPoll => 'New poll';

  @override
  String get noProxyLinkInClipboard =>
      'No Telegram proxy link found in the clipboard.';

  @override
  String get noCallsYet => 'No calls yet';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get noContacts => 'No contacts';

  @override
  String get noContactsFound => 'No contacts found';

  @override
  String get noCountriesFound => 'No countries found';

  @override
  String get noMembersToShow => 'No members to show';

  @override
  String get noMessagesFound => 'No messages found';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get noProxiesYet =>
      'No proxies yet. Add one manually, or copy a t.me/proxy link and use the paste button.';

  @override
  String get noSavedGifs => 'No saved GIFs';

  @override
  String get noStickersYet => 'No stickers yet';

  @override
  String get noInteractionInfo =>
      'Nobody has reacted to this message, and Telegram does not report who read it here.';

  @override
  String get nobodyBlocked =>
      'Nobody is blocked. Blocked users cannot message you or see when you are online.';

  @override
  String get nothingScheduled => 'Nothing scheduled';

  @override
  String get notificationsAndSounds => 'Notifications and sounds';

  @override
  String get appLocked => 'Nullgram is locked';

  @override
  String get qrInstructions =>
      'Open Telegram on your phone, go to Settings › Devices › Link Desktop Device, and scan this code.';

  @override
  String get passcode => 'Passcode';

  @override
  String get passcodeLock => 'Passcode lock';

  @override
  String get password => 'Password';

  @override
  String get passwordOptional => 'Password (optional)';

  @override
  String get phone => 'Phone';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get photos => 'Photos';

  @override
  String get pickDateAndTime => 'Pick a date and time';

  @override
  String get poll => 'Poll';

  @override
  String get port => 'Port';

  @override
  String get privacyAndSecurity => 'Privacy and security';

  @override
  String get privateChats => 'Private chats';

  @override
  String get proxy => 'Proxy';

  @override
  String get question => 'Question';

  @override
  String get reactionsAndViews => 'Reactions and views';

  @override
  String get recoveryEmailIsSet => 'Recovery email is set';

  @override
  String get remove => 'Remove';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get repeatThePasscode => 'Repeat the passcode';

  @override
  String get reply => 'Reply';

  @override
  String get resendCode => 'Resend code';

  @override
  String get save => 'Save';

  @override
  String get savedMessages => 'Saved Messages';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get scheduleMessage => 'Schedule message';

  @override
  String get scheduledMessages => 'Scheduled messages';

  @override
  String get search => 'Search';

  @override
  String get searchChatsAndMessages => 'Search chats and messages';

  @override
  String get searchChatsHint => 'Search chats...';

  @override
  String get searchContacts => 'Search contacts';

  @override
  String get searchCountry => 'Search country';

  @override
  String get searchInChat => 'Search in chat';

  @override
  String get searchMessages => 'Search messages';

  @override
  String get searchMessagesHint => 'Search messages...';

  @override
  String get secret => 'Secret';

  @override
  String get select => 'Select';

  @override
  String get selectMessages => 'Select messages';

  @override
  String get sendHoldForOptions => 'Send (hold for options)';

  @override
  String get chatEmptyHint => 'Send a message to start the conversation.';

  @override
  String get sendMessage => 'Send message';

  @override
  String get sendAsAlbumHint => 'Send one or several as an album';

  @override
  String get sendWhenOnline => 'Send when online';

  @override
  String get sendWithoutSound => 'Send without sound';

  @override
  String get server => 'Server';

  @override
  String get setAPasscode => 'Set a passcode';

  @override
  String get settings => 'Settings';

  @override
  String get share => 'Share';

  @override
  String get shareAContact => 'Share a contact';

  @override
  String get sharedMedia => 'Shared media';

  @override
  String get showInChat => 'Show in chat';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutDeviceQuestion => 'Sign this device out?';

  @override
  String get signUp => 'Sign up';

  @override
  String get speaker => 'Speaker';

  @override
  String get startSecretChat => 'Start secret chat';

  @override
  String get submit => 'Submit';

  @override
  String get system => 'System';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get passwordNotAccepted => 'That password was not accepted.';

  @override
  String get mtprotoSecretHint =>
      'The hex or base64 secret from the proxy link';

  @override
  String get silentSendHint => 'The recipient is not notified';

  @override
  String get buttonNotSupported => 'This button is not supported yet';

  @override
  String get cannotBeUndone => 'This cannot be undone.';

  @override
  String get memberListHidden =>
      'This chat does not expose its member list to you.';

  @override
  String get thisDevice => 'This device';

  @override
  String get noBiometricsEnrolled => 'This device has no biometrics enrolled.';

  @override
  String get inviteLinkInvalid => 'This invite link is no longer valid';

  @override
  String get registrationSubtitle =>
      'This number is not registered yet. Choose the name other people will see.';

  @override
  String get translate => 'Translate';

  @override
  String get translation => 'Translation';

  @override
  String get tryDifferentSearch => 'Try a different search term.';

  @override
  String get turnOff => 'Turn off';

  @override
  String get turnOffPasscodeQuestion => 'Turn off the passcode?';

  @override
  String get turnOffTwoStep => 'Turn off two-step verification';

  @override
  String get turnOffTwoStepQuestion => 'Turn off two-step verification?';

  @override
  String get twoStepVerification => 'Two-step verification';

  @override
  String get twoStepUnavailable =>
      'Two-step verification is unavailable right now.';

  @override
  String get searchInChatHint => 'Type to find messages in this chat.';

  @override
  String get searchGlobalHint => 'Type to search across Telegram.';

  @override
  String get unblock => 'Unblock';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockPrompt => 'Unlock Nullgram';

  @override
  String get unlockWithBiometrics => 'Unlock with biometrics';

  @override
  String get unreadMessages => 'Unread messages';

  @override
  String get useAProxy => 'Use a proxy';

  @override
  String get useBiometrics => 'Use biometrics';

  @override
  String get amoledDarkSubtitle => 'Use true black surfaces';

  @override
  String get username => 'Username';

  @override
  String get usernameOptional => 'Username (optional)';

  @override
  String get verify => 'Verify';

  @override
  String get video => 'Video';

  @override
  String get videoCall => 'Video call';

  @override
  String get videoMessage => 'Video message';

  @override
  String get videos => 'Videos';

  @override
  String get voice => 'Voice';

  @override
  String get welcomeToNullgram => 'Welcome to Nullgram';

  @override
  String get writeAMessage => 'Write a message...';

  @override
  String get wrongNumber => 'Wrong number?';

  @override
  String get logOutWarning => 'You will need to sign in again to use the app.';

  @override
  String get twoStepDisableWarning =>
      'Your account will be protected by the login code alone.';

  @override
  String get chatsEmptyHint => 'Your conversations will appear here.';

  @override
  String get clearCacheNote =>
      'Your messages are not affected — only files cached on this device are removed.';

  @override
  String get proxyInUse => '· in use';

  @override
  String get never => 'Never';

  @override
  String get passcodeMinLengthHint => 'At least 4 digits';

  @override
  String get codesDoNotMatch => 'The codes do not match';

  @override
  String get wrongPasscode => 'Wrong passcode';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get preferences => 'Preferences';

  @override
  String get account => 'Account';

  @override
  String get mobileData => 'Mobile data';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get lockImmediately => 'Immediately';

  @override
  String get lockAfterOneMinute => 'After 1 minute';

  @override
  String get lockAfterFiveMinutes => 'After 5 minutes';

  @override
  String get lockAfterOneHour => 'After 1 hour';

  @override
  String get autoDeleteOff => 'Auto-delete: off';

  @override
  String get autoDeleteOn => 'Auto-delete: on';

  @override
  String get off => 'Off';

  @override
  String get oneDay => '1 day';

  @override
  String get oneWeek => '1 week';

  @override
  String get oneMonth => '1 month';

  @override
  String get viewProfile => 'View profile';

  @override
  String get chatInfo => 'Chat info';

  @override
  String get unmute => 'Unmute';

  @override
  String get blockUser => 'Block user';

  @override
  String get unblockUser => 'Unblock user';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get reactions => 'Reactions';

  @override
  String get readBy => 'Read by';

  @override
  String get editProxy => 'Edit proxy';

  @override
  String get proxyRouteHint =>
      'Route the connection through the selected server';

  @override
  String get addProxyFirst => 'Add a proxy first';

  @override
  String get proxyChecking => 'checking…';

  @override
  String get proxyUnavailable => 'unavailable';

  @override
  String get translationFailed => 'Telegram could not translate this message.';

  @override
  String get accountCreationFailed =>
      'Could not create the account. Try again.';

  @override
  String get acceptTermsQuestion => 'Do you accept the Terms of Service?';

  @override
  String get incorrectPassword => 'Incorrect password. Please try again.';

  @override
  String get passwordUpdated => 'Password updated';

  @override
  String get twoStepDisabled => 'Two-step verification disabled';

  @override
  String get confirmYourPassword => 'Confirm your password';

  @override
  String get twoStepPassword => 'Two-step password';

  @override
  String get passwordIsOn => 'Password is on';

  @override
  String get passwordIsOff => 'Password is off';

  @override
  String get setPassword => 'Set password';

  @override
  String get changePassword => 'Change password';

  @override
  String get notifyPrivateDescription => 'Messages from people and bots';

  @override
  String get notifyGroupsDescription =>
      'Messages in groups you are a member of';

  @override
  String get notifyChannelsDescription => 'Posts from channels you follow';

  @override
  String get followSystem => 'Follow the system';

  @override
  String get interfaceLanguage => 'Interface language';

  @override
  String get groupName => 'Group name';

  @override
  String get channelName => 'Channel name';

  @override
  String get createGroup => 'Create group';

  @override
  String get createChannel => 'Create channel';

  @override
  String get groupCreateFailed => 'Could not create the group. Try again.';

  @override
  String get channelCreateFailed => 'Could not create the channel. Try again.';

  @override
  String get nothingSharedYet => 'Nothing here yet';

  @override
  String get searchChats => 'Search chats';

  @override
  String get noChatsFound => 'No chats found';

  @override
  String get keyboard => 'Keyboard';

  @override
  String get emojiAndStickers => 'Emoji and stickers';

  @override
  String appVersionLabel(String version) {
    return 'Nullgram $version';
  }

  @override
  String pollAnswerLabel(int number) {
    return 'Answer $number';
  }

  @override
  String hintWithText(String hint) {
    return 'Hint: $hint';
  }

  @override
  String joinChatQuestion(String title) {
    return 'Join $title?';
  }

  @override
  String usernameNotFound(String username) {
    return 'No Telegram account found for @$username';
  }

  @override
  String resendCodeIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String forwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String upToSize(String size) {
    return 'Up to $size';
  }

  @override
  String reactionsWithCount(int count) {
    return 'Reactions · $count';
  }

  @override
  String readByWithCount(int count) {
    return 'Read by · $count';
  }

  @override
  String failedToDownload(String error) {
    return 'Download failed: $error';
  }

  @override
  String failedToPlay(String error) {
    return 'Playback failed: $error';
  }

  @override
  String failedToSave(String error) {
    return 'Could not save: $error';
  }

  @override
  String failedToShare(String error) {
    return 'Could not share: $error';
  }

  @override
  String membersCount(String count) {
    return '$count members';
  }

  @override
  String subscribersCount(String count) {
    return '$count subscribers';
  }

  @override
  String pingMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String autoDeleteAfterDays(int days) {
    return 'Auto-delete: $days days';
  }

  @override
  String get addAccount => 'Add account';

  @override
  String get switchAccounts => 'Switch accounts';

  @override
  String logOutAccountQuestion(String name) {
    return 'Log out of $name?';
  }

  @override
  String accountUnreadMessages(int count) {
    return '$count unread';
  }

  @override
  String get phoneNumberInvalid => 'This phone number is not valid.';

  @override
  String get appVerificationFailed =>
      'Telegram could not verify this app. Signing in needs an api_id of your own from my.telegram.org.';

  @override
  String get apiIdPublishedFlood =>
      'This api_id has been published, so Telegram no longer accepts sign-ins with it. Get one of your own at my.telegram.org.';

  @override
  String signInFailed(String reason) {
    return 'Could not sign in: $reason';
  }

  @override
  String get notificationPhoto => 'Photo';

  @override
  String get notificationVideo => 'Video';

  @override
  String get notificationAnimation => 'GIF';

  @override
  String get notificationAudio => 'Audio';

  @override
  String get notificationDocument => 'File';

  @override
  String get notificationVoiceNote => 'Voice message';

  @override
  String get notificationVideoNote => 'Video message';

  @override
  String notificationSticker(String emoji) {
    return '$emoji Sticker';
  }

  @override
  String get notificationContact => 'Contact';

  @override
  String get notificationLocation => 'Location';

  @override
  String notificationPoll(String question) {
    return 'Poll: $question';
  }

  @override
  String get notificationAlbum => 'Album';

  @override
  String get notificationMessage => 'New message';

  @override
  String get notificationSecretChat => 'New secret chat';

  @override
  String get notificationIncomingCall => 'Incoming call';

  @override
  String get notificationReply => 'Reply';

  @override
  String get notificationMarkRead => 'Mark as read';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyLastSeen => 'Last seen and online';

  @override
  String get privacyProfilePhoto => 'Profile photo';

  @override
  String get privacyFindByPhone => 'Who can find me by my number';

  @override
  String get privacyForwardedMessages => 'Link in forwarded messages';

  @override
  String get privacyPeerToPeerCalls => 'Peer-to-peer calls';

  @override
  String get privacyGroupInvites => 'Group invites';

  @override
  String get privacyVoiceMessages => 'Voice and video messages';

  @override
  String get privacyEverybody => 'Everybody';

  @override
  String get privacyMyContacts => 'My contacts';

  @override
  String get privacyNobody => 'Nobody';

  @override
  String get chats => 'Chats';

  @override
  String get create => 'Create';

  @override
  String get chatFolders => 'Chat folders';

  @override
  String get noFoldersYet => 'No folders yet';

  @override
  String get foldersExplanation =>
      'A folder is a tab over your chat list with its own rules.';

  @override
  String get newFolder => 'New folder';

  @override
  String get editFolder => 'Edit folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get folderNameRequired => 'Give the folder a name.';

  @override
  String get folderNeedsChats => 'Add at least one chat or chat type.';

  @override
  String get deleteFolderExplanation =>
      'The chats stay where they are; only the tab goes away.';

  @override
  String get includedChats => 'Included chats';

  @override
  String get excludedChats => 'Excluded chats';

  @override
  String get folderNonContacts => 'Non-contacts';

  @override
  String get folderBots => 'Bots';

  @override
  String get folderMuted => 'Muted';

  @override
  String get folderRead => 'Read';

  @override
  String get newTopic => 'New topic';

  @override
  String get topicName => 'Topic name';

  @override
  String get noTopicsYet => 'No topics yet';

  @override
  String get stickerPacks => 'Sticker packs';

  @override
  String get stickersInstalled => 'Installed';

  @override
  String get stickersTrending => 'Trending';

  @override
  String get searchStickerPacks => 'Search sticker packs';

  @override
  String get searchStickersHint => 'Search by emoji';

  @override
  String get searchGifsHint => 'Search GIFs';

  @override
  String deleteFolderQuestion(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String stickersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stickers',
      one: '1 sticker',
    );
    return '$_temp0';
  }

  @override
  String get notificationYou => 'You';
}
