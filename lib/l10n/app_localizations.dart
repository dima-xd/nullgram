import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @passcodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A local lock over the app itself'**
  String get passcodeSubtitle;

  /// No description provided for @passcodeExplanation.
  ///
  /// In en, this message translates to:
  /// **'A passcode locks this app on this device. It is separate from two-step verification, which protects the account itself.'**
  String get passcodeExplanation;

  /// No description provided for @twoStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A password on top of the login code'**
  String get twoStepSubtitle;

  /// No description provided for @videoMessageHint.
  ///
  /// In en, this message translates to:
  /// **'A round clip, up to a minute'**
  String get videoMessageHint;

  /// No description provided for @amoledDark.
  ///
  /// In en, this message translates to:
  /// **'AMOLED dark'**
  String get amoledDark;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addProxy.
  ///
  /// In en, this message translates to:
  /// **'Add a proxy'**
  String get addProxy;

  /// No description provided for @addAnswer.
  ///
  /// In en, this message translates to:
  /// **'Add an answer'**
  String get addAnswer;

  /// No description provided for @addFromCopiedLink.
  ///
  /// In en, this message translates to:
  /// **'Add from a copied link'**
  String get addFromCopiedLink;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLink;

  /// No description provided for @addMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get addMembers;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @anonymousVoting.
  ///
  /// In en, this message translates to:
  /// **'Anonymous voting'**
  String get anonymousVoting;

  /// No description provided for @passcodeDisableWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this phone unlocked will be able to open the app.'**
  String get passcodeDisableWarning;

  /// No description provided for @sharedMediaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Anything shared in this chat shows up here.'**
  String get sharedMediaEmpty;

  /// No description provided for @archivedChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived Chats'**
  String get archivedChatsTitle;

  /// No description provided for @archivedChats.
  ///
  /// In en, this message translates to:
  /// **'Archived chats'**
  String get archivedChats;

  /// No description provided for @atLeastFourCharacters.
  ///
  /// In en, this message translates to:
  /// **'At least 4 characters'**
  String get atLeastFourCharacters;

  /// No description provided for @autoDeleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete messages'**
  String get autoDeleteMessages;

  /// No description provided for @automaticMediaDownload.
  ///
  /// In en, this message translates to:
  /// **'Automatic media download'**
  String get automaticMediaDownload;

  /// No description provided for @backspace.
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get backspace;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @botCommands.
  ///
  /// In en, this message translates to:
  /// **'Bot commands'**
  String get botCommands;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @callBack.
  ///
  /// In en, this message translates to:
  /// **'Call back'**
  String get callBack;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @callsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Calls you make and receive will appear here.'**
  String get callsEmpty;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changePasscode.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get changePasscode;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get clearCacheQuestion;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryQuestion;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @contactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Contacts you add on Telegram will show up here.'**
  String get contactsEmpty;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copyTranslation.
  ///
  /// In en, this message translates to:
  /// **'Copy translation'**
  String get copyTranslation;

  /// No description provided for @passwordChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the password. Check the old one.'**
  String get passwordChangeFailed;

  /// No description provided for @joinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join the chat'**
  String get joinFailed;

  /// No description provided for @secretChatFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start a secret chat'**
  String get secretChatFailed;

  /// No description provided for @createPoll.
  ///
  /// In en, this message translates to:
  /// **'Create poll'**
  String get createPoll;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @dataAndStorage.
  ///
  /// In en, this message translates to:
  /// **'Data and storage'**
  String get dataAndStorage;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @deliveredWhenBack.
  ///
  /// In en, this message translates to:
  /// **'Delivered once they are back'**
  String get deliveredWhenBack;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @downloadAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Download automatically'**
  String get downloadAutomatically;

  /// No description provided for @downloadedMedia.
  ///
  /// In en, this message translates to:
  /// **'Downloaded media'**
  String get downloadedMedia;

  /// No description provided for @clearCacheExplanation.
  ///
  /// In en, this message translates to:
  /// **'Downloaded photos, videos and files will be removed from this device. They stay on Telegram and download again when opened.'**
  String get clearCacheExplanation;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editBio.
  ///
  /// In en, this message translates to:
  /// **'Edit bio'**
  String get editBio;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessage;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @editUsername.
  ///
  /// In en, this message translates to:
  /// **'Edit username'**
  String get editUsername;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endCall;

  /// No description provided for @enterTheCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get enterTheCode;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @enterPhoneToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to continue'**
  String get enterPhoneToContinue;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @filesAndVoice.
  ///
  /// In en, this message translates to:
  /// **'Files and voice'**
  String get filesAndVoice;

  /// No description provided for @findPeopleAndGroups.
  ///
  /// In en, this message translates to:
  /// **'Find people and groups'**
  String get findPeopleAndGroups;

  /// No description provided for @biometricsHint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or face, when enrolled'**
  String get biometricsHint;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @forEveryone.
  ///
  /// In en, this message translates to:
  /// **'For everyone'**
  String get forEveryone;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @forwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get forwardTo;

  /// No description provided for @gif.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get gif;

  /// No description provided for @generatingQrCode.
  ///
  /// In en, this message translates to:
  /// **'Generating QR code...'**
  String get generatingQrCode;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @hintOptional.
  ///
  /// In en, this message translates to:
  /// **'Hint (optional)'**
  String get hintOptional;

  /// No description provided for @scheduledEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the send button in a chat to schedule a message.'**
  String get scheduledEmptyHint;

  /// No description provided for @holdToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record a voice message'**
  String get holdToRecord;

  /// No description provided for @notificationScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Individual chats keep their own mute setting, which overrides these defaults.'**
  String get notificationScopeHint;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLink;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get inviteLinkCopied;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @languagePacks.
  ///
  /// In en, this message translates to:
  /// **'Language packs'**
  String get languagePacks;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @lastNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Last name (optional)'**
  String get lastNameOptional;

  /// No description provided for @leaveChat.
  ///
  /// In en, this message translates to:
  /// **'Leave chat'**
  String get leaveChat;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @localDatabase.
  ///
  /// In en, this message translates to:
  /// **'Local database'**
  String get localDatabase;

  /// No description provided for @lockTheApp.
  ///
  /// In en, this message translates to:
  /// **'Lock the app'**
  String get lockTheApp;

  /// No description provided for @loginByQrCode.
  ///
  /// In en, this message translates to:
  /// **'Log in by QR Code'**
  String get loginByQrCode;

  /// No description provided for @loginByPhone.
  ///
  /// In en, this message translates to:
  /// **'Log in by phone number'**
  String get loginByPhone;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQuestion;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @autoDownloadExplanation.
  ///
  /// In en, this message translates to:
  /// **'Media under these sizes appears without a tap. Anything larger keeps its download button.'**
  String get autoDownloadExplanation;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @messageActions.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get messageActions;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get microphonePermissionRequired;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @multipleAnswers.
  ///
  /// In en, this message translates to:
  /// **'Multiple answers'**
  String get multipleAnswers;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @newChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'New Channel'**
  String get newChannelTitle;

  /// No description provided for @newGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroupTitle;

  /// No description provided for @newChannel.
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get newChannel;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessage;

  /// No description provided for @autoDeleteExplanation.
  ///
  /// In en, this message translates to:
  /// **'New messages in this chat are deleted for everyone after the chosen time. Messages already sent are unaffected.'**
  String get autoDeleteExplanation;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @newPoll.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get newPoll;

  /// No description provided for @noProxyLinkInClipboard.
  ///
  /// In en, this message translates to:
  /// **'No Telegram proxy link found in the clipboard.'**
  String get noProxyLinkInClipboard;

  /// No description provided for @noCallsYet.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get noCallsYet;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @noContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts'**
  String get noContacts;

  /// No description provided for @noContactsFound.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get noContactsFound;

  /// No description provided for @noCountriesFound.
  ///
  /// In en, this message translates to:
  /// **'No countries found'**
  String get noCountriesFound;

  /// No description provided for @noMembersToShow.
  ///
  /// In en, this message translates to:
  /// **'No members to show'**
  String get noMembersToShow;

  /// No description provided for @noMessagesFound.
  ///
  /// In en, this message translates to:
  /// **'No messages found'**
  String get noMessagesFound;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @noProxiesYet.
  ///
  /// In en, this message translates to:
  /// **'No proxies yet. Add one manually, or copy a t.me/proxy link and use the paste button.'**
  String get noProxiesYet;

  /// No description provided for @noSavedGifs.
  ///
  /// In en, this message translates to:
  /// **'No saved GIFs'**
  String get noSavedGifs;

  /// No description provided for @noStickersYet.
  ///
  /// In en, this message translates to:
  /// **'No stickers yet'**
  String get noStickersYet;

  /// No description provided for @noInteractionInfo.
  ///
  /// In en, this message translates to:
  /// **'Nobody has reacted to this message, and Telegram does not report who read it here.'**
  String get noInteractionInfo;

  /// No description provided for @nobodyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Nobody is blocked. Blocked users cannot message you or see when you are online.'**
  String get nobodyBlocked;

  /// No description provided for @nothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get nothingScheduled;

  /// No description provided for @notificationsAndSounds.
  ///
  /// In en, this message translates to:
  /// **'Notifications and sounds'**
  String get notificationsAndSounds;

  /// No description provided for @appLocked.
  ///
  /// In en, this message translates to:
  /// **'Nullgram is locked'**
  String get appLocked;

  /// No description provided for @qrInstructions.
  ///
  /// In en, this message translates to:
  /// **'Open Telegram on your phone, go to Settings › Devices › Link Desktop Device, and scan this code.'**
  String get qrInstructions;

  /// No description provided for @passcode.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcode;

  /// No description provided for @passcodeLock.
  ///
  /// In en, this message translates to:
  /// **'Passcode lock'**
  String get passcodeLock;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get passwordOptional;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @pickDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a date and time'**
  String get pickDateAndTime;

  /// No description provided for @poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get poll;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @privacyAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get privacyAndSecurity;

  /// No description provided for @privateChats.
  ///
  /// In en, this message translates to:
  /// **'Private chats'**
  String get privateChats;

  /// No description provided for @proxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get proxy;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @reactionsAndViews.
  ///
  /// In en, this message translates to:
  /// **'Reactions and views'**
  String get reactionsAndViews;

  /// No description provided for @recoveryEmailIsSet.
  ///
  /// In en, this message translates to:
  /// **'Recovery email is set'**
  String get recoveryEmailIsSet;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeFromGroup;

  /// No description provided for @repeatThePasscode.
  ///
  /// In en, this message translates to:
  /// **'Repeat the passcode'**
  String get repeatThePasscode;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @savedMessages.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get savedMessages;

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get savedToGallery;

  /// No description provided for @scheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'Schedule message'**
  String get scheduleMessage;

  /// No description provided for @scheduledMessages.
  ///
  /// In en, this message translates to:
  /// **'Scheduled messages'**
  String get scheduledMessages;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchChatsAndMessages.
  ///
  /// In en, this message translates to:
  /// **'Search chats and messages'**
  String get searchChatsAndMessages;

  /// No description provided for @searchChatsHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats...'**
  String get searchChatsHint;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get searchContacts;

  /// No description provided for @searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get searchCountry;

  /// No description provided for @searchInChat.
  ///
  /// In en, this message translates to:
  /// **'Search in chat'**
  String get searchInChat;

  /// No description provided for @searchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get searchMessages;

  /// No description provided for @searchMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages...'**
  String get searchMessagesHint;

  /// No description provided for @secret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get secret;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectMessages.
  ///
  /// In en, this message translates to:
  /// **'Select messages'**
  String get selectMessages;

  /// No description provided for @sendHoldForOptions.
  ///
  /// In en, this message translates to:
  /// **'Send (hold for options)'**
  String get sendHoldForOptions;

  /// No description provided for @chatEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Send a message to start the conversation.'**
  String get chatEmptyHint;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @sendAsAlbumHint.
  ///
  /// In en, this message translates to:
  /// **'Send one or several as an album'**
  String get sendAsAlbumHint;

  /// No description provided for @sendWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'Send when online'**
  String get sendWhenOnline;

  /// No description provided for @sendWithoutSound.
  ///
  /// In en, this message translates to:
  /// **'Send without sound'**
  String get sendWithoutSound;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @setAPasscode.
  ///
  /// In en, this message translates to:
  /// **'Set a passcode'**
  String get setAPasscode;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareAContact.
  ///
  /// In en, this message translates to:
  /// **'Share a contact'**
  String get shareAContact;

  /// No description provided for @sharedMedia.
  ///
  /// In en, this message translates to:
  /// **'Shared media'**
  String get sharedMedia;

  /// No description provided for @showInChat.
  ///
  /// In en, this message translates to:
  /// **'Show in chat'**
  String get showInChat;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutDeviceQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign this device out?'**
  String get signOutDeviceQuestion;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @startSecretChat.
  ///
  /// In en, this message translates to:
  /// **'Start secret chat'**
  String get startSecretChat;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @passwordNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'That password was not accepted.'**
  String get passwordNotAccepted;

  /// No description provided for @mtprotoSecretHint.
  ///
  /// In en, this message translates to:
  /// **'The hex or base64 secret from the proxy link'**
  String get mtprotoSecretHint;

  /// No description provided for @silentSendHint.
  ///
  /// In en, this message translates to:
  /// **'The recipient is not notified'**
  String get silentSendHint;

  /// No description provided for @buttonNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This button is not supported yet'**
  String get buttonNotSupported;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @memberListHidden.
  ///
  /// In en, this message translates to:
  /// **'This chat does not expose its member list to you.'**
  String get memberListHidden;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @noBiometricsEnrolled.
  ///
  /// In en, this message translates to:
  /// **'This device has no biometrics enrolled.'**
  String get noBiometricsEnrolled;

  /// No description provided for @inviteLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This invite link is no longer valid'**
  String get inviteLinkInvalid;

  /// No description provided for @registrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This number is not registered yet. Choose the name other people will see.'**
  String get registrationSubtitle;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get tryDifferentSearch;

  /// No description provided for @turnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOff;

  /// No description provided for @turnOffPasscodeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Turn off the passcode?'**
  String get turnOffPasscodeQuestion;

  /// No description provided for @turnOffTwoStep.
  ///
  /// In en, this message translates to:
  /// **'Turn off two-step verification'**
  String get turnOffTwoStep;

  /// No description provided for @turnOffTwoStepQuestion.
  ///
  /// In en, this message translates to:
  /// **'Turn off two-step verification?'**
  String get turnOffTwoStepQuestion;

  /// No description provided for @twoStepVerification.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get twoStepVerification;

  /// No description provided for @twoStepUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is unavailable right now.'**
  String get twoStepUnavailable;

  /// No description provided for @searchInChatHint.
  ///
  /// In en, this message translates to:
  /// **'Type to find messages in this chat.'**
  String get searchInChatHint;

  /// No description provided for @searchGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'Type to search across Telegram.'**
  String get searchGlobalHint;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock Nullgram'**
  String get unlockPrompt;

  /// No description provided for @unlockWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get unlockWithBiometrics;

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'Unread messages'**
  String get unreadMessages;

  /// No description provided for @useAProxy.
  ///
  /// In en, this message translates to:
  /// **'Use a proxy'**
  String get useAProxy;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get useBiometrics;

  /// No description provided for @amoledDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use true black surfaces'**
  String get amoledDarkSubtitle;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get usernameOptional;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @videoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video message'**
  String get videoMessage;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @welcomeToNullgram.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Nullgram'**
  String get welcomeToNullgram;

  /// No description provided for @writeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get writeAMessage;

  /// No description provided for @wrongNumber.
  ///
  /// In en, this message translates to:
  /// **'Wrong number?'**
  String get wrongNumber;

  /// No description provided for @logOutWarning.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use the app.'**
  String get logOutWarning;

  /// No description provided for @twoStepDisableWarning.
  ///
  /// In en, this message translates to:
  /// **'Your account will be protected by the login code alone.'**
  String get twoStepDisableWarning;

  /// No description provided for @chatsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your conversations will appear here.'**
  String get chatsEmptyHint;

  /// No description provided for @clearCacheNote.
  ///
  /// In en, this message translates to:
  /// **'Your messages are not affected — only files cached on this device are removed.'**
  String get clearCacheNote;

  /// No description provided for @proxyInUse.
  ///
  /// In en, this message translates to:
  /// **'· in use'**
  String get proxyInUse;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @passcodeMinLengthHint.
  ///
  /// In en, this message translates to:
  /// **'At least 4 digits'**
  String get passcodeMinLengthHint;

  /// No description provided for @codesDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The codes do not match'**
  String get codesDoNotMatch;

  /// No description provided for @wrongPasscode.
  ///
  /// In en, this message translates to:
  /// **'Wrong passcode'**
  String get wrongPasscode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @mobileData.
  ///
  /// In en, this message translates to:
  /// **'Mobile data'**
  String get mobileData;

  /// No description provided for @wifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get wifi;

  /// No description provided for @lockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get lockImmediately;

  /// No description provided for @lockAfterOneMinute.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get lockAfterOneMinute;

  /// No description provided for @lockAfterFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get lockAfterFiveMinutes;

  /// No description provided for @lockAfterOneHour.
  ///
  /// In en, this message translates to:
  /// **'After 1 hour'**
  String get lockAfterOneHour;

  /// No description provided for @autoDeleteOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete: off'**
  String get autoDeleteOff;

  /// No description provided for @autoDeleteOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete: on'**
  String get autoDeleteOn;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @oneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get oneDay;

  /// No description provided for @oneWeek.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get oneWeek;

  /// No description provided for @oneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get oneMonth;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @chatInfo.
  ///
  /// In en, this message translates to:
  /// **'Chat info'**
  String get chatInfo;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get unblockUser;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @reactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactions;

  /// No description provided for @readBy.
  ///
  /// In en, this message translates to:
  /// **'Read by'**
  String get readBy;

  /// No description provided for @editProxy.
  ///
  /// In en, this message translates to:
  /// **'Edit proxy'**
  String get editProxy;

  /// No description provided for @proxyRouteHint.
  ///
  /// In en, this message translates to:
  /// **'Route the connection through the selected server'**
  String get proxyRouteHint;

  /// No description provided for @addProxyFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a proxy first'**
  String get addProxyFirst;

  /// No description provided for @proxyChecking.
  ///
  /// In en, this message translates to:
  /// **'checking…'**
  String get proxyChecking;

  /// No description provided for @proxyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get proxyUnavailable;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Telegram could not translate this message.'**
  String get translationFailed;

  /// No description provided for @accountCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account. Try again.'**
  String get accountCreationFailed;

  /// No description provided for @acceptTermsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you accept the Terms of Service?'**
  String get acceptTermsQuestion;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get incorrectPassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordUpdated;

  /// No description provided for @twoStepDisabled.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification disabled'**
  String get twoStepDisabled;

  /// No description provided for @confirmYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmYourPassword;

  /// No description provided for @twoStepPassword.
  ///
  /// In en, this message translates to:
  /// **'Two-step password'**
  String get twoStepPassword;

  /// No description provided for @passwordIsOn.
  ///
  /// In en, this message translates to:
  /// **'Password is on'**
  String get passwordIsOn;

  /// No description provided for @passwordIsOff.
  ///
  /// In en, this message translates to:
  /// **'Password is off'**
  String get passwordIsOff;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @notifyPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Messages from people and bots'**
  String get notifyPrivateDescription;

  /// No description provided for @notifyGroupsDescription.
  ///
  /// In en, this message translates to:
  /// **'Messages in groups you are a member of'**
  String get notifyGroupsDescription;

  /// No description provided for @notifyChannelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Posts from channels you follow'**
  String get notifyChannelsDescription;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get followSystem;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get interfaceLanguage;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelName;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @createChannel.
  ///
  /// In en, this message translates to:
  /// **'Create channel'**
  String get createChannel;

  /// No description provided for @groupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the group. Try again.'**
  String get groupCreateFailed;

  /// No description provided for @channelCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the channel. Try again.'**
  String get channelCreateFailed;

  /// No description provided for @nothingSharedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingSharedYet;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get searchChats;

  /// No description provided for @noChatsFound.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get noChatsFound;

  /// No description provided for @keyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboard;

  /// No description provided for @emojiAndStickers.
  ///
  /// In en, this message translates to:
  /// **'Emoji and stickers'**
  String get emojiAndStickers;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Nullgram {version}'**
  String appVersionLabel(String version);

  /// No description provided for @pollAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer {number}'**
  String pollAnswerLabel(int number);

  /// No description provided for @hintWithText.
  ///
  /// In en, this message translates to:
  /// **'Hint: {hint}'**
  String hintWithText(String hint);

  /// No description provided for @joinChatQuestion.
  ///
  /// In en, this message translates to:
  /// **'Join {title}?'**
  String joinChatQuestion(String title);

  /// No description provided for @usernameNotFound.
  ///
  /// In en, this message translates to:
  /// **'No Telegram account found for @{username}'**
  String usernameNotFound(String username);

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resendCodeIn(int seconds);

  /// No description provided for @forwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String forwardedFrom(String name);

  /// No description provided for @upToSize.
  ///
  /// In en, this message translates to:
  /// **'Up to {size}'**
  String upToSize(String size);

  /// No description provided for @reactionsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Reactions · {count}'**
  String reactionsWithCount(int count);

  /// No description provided for @readByWithCount.
  ///
  /// In en, this message translates to:
  /// **'Read by · {count}'**
  String readByWithCount(int count);

  /// No description provided for @failedToDownload.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String failedToDownload(String error);

  /// No description provided for @failedToPlay.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String failedToPlay(String error);

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String failedToSave(String error);

  /// No description provided for @failedToShare.
  ///
  /// In en, this message translates to:
  /// **'Could not share: {error}'**
  String failedToShare(String error);

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(String count);

  /// No description provided for @subscribersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subscribers'**
  String subscribersCount(String count);

  /// No description provided for @pingMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'{milliseconds} ms'**
  String pingMilliseconds(int milliseconds);

  /// No description provided for @autoDeleteAfterDays.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete: {days} days'**
  String autoDeleteAfterDays(int days);

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @switchAccounts.
  ///
  /// In en, this message translates to:
  /// **'Switch accounts'**
  String get switchAccounts;

  /// No description provided for @logOutAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out of {name}?'**
  String logOutAccountQuestion(String name);

  /// No description provided for @accountUnreadMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String accountUnreadMessages(int count);

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'This phone number is not valid.'**
  String get phoneNumberInvalid;

  /// No description provided for @appVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Telegram could not verify this app. Signing in needs an api_id of your own from my.telegram.org.'**
  String get appVerificationFailed;

  /// No description provided for @apiIdPublishedFlood.
  ///
  /// In en, this message translates to:
  /// **'This api_id has been published, so Telegram no longer accepts sign-ins with it. Get one of your own at my.telegram.org.'**
  String get apiIdPublishedFlood;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in: {reason}'**
  String signInFailed(String reason);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
