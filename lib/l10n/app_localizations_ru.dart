// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get comments => 'Комментарии';

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментариев',
      few: '$count комментария',
      one: '1 комментарий',
    );
    return '$_temp0';
  }

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ответов',
      few: '$count ответа',
      one: '1 ответ',
    );
    return '$_temp0';
  }

  @override
  String get leaveComment => 'Оставить комментарий';

  @override
  String get noCommentsYet => 'Комментариев пока нет';

  @override
  String get noCommentsHint => 'Прокомментируйте этот пост первым.';

  @override
  String get joinDiscussion => 'Присоединиться к обсуждению';

  @override
  String get threadUnavailable => 'У этого сообщения нет обсуждения.';

  @override
  String get passcodeSubtitle => 'Локальная блокировка самого приложения';

  @override
  String get passcodeExplanation =>
      'Код-пароль блокирует приложение на этом устройстве. Это не то же, что двухэтапная проверка, которая защищает сам аккаунт.';

  @override
  String get twoStepSubtitle => 'Пароль в дополнение к коду входа';

  @override
  String get videoMessageHint => 'Круглое видео, до минуты';

  @override
  String get amoledDark => 'AMOLED-тёмная';

  @override
  String get about => 'О себе';

  @override
  String get accept => 'Принять';

  @override
  String get add => 'Добавить';

  @override
  String get addProxy => 'Добавить прокси';

  @override
  String get addAnswer => 'Добавить вариант';

  @override
  String get addFromCopiedLink => 'Добавить из скопированной ссылки';

  @override
  String get addLink => 'Добавить ссылку';

  @override
  String get addMembers => 'Добавить участников';

  @override
  String get all => 'Все';

  @override
  String get anonymousVoting => 'Анонимное голосование';

  @override
  String get passcodeDisableWarning =>
      'Любой, кто разблокирует телефон, сможет открыть приложение.';

  @override
  String get sharedMediaEmpty =>
      'Всё, что отправляют в этот чат, покажется здесь.';

  @override
  String get archivedChatsTitle => 'Архив';

  @override
  String get archivedChats => 'Архив';

  @override
  String get atLeastFourCharacters => 'Не менее 4 символов';

  @override
  String get autoDeleteMessages => 'Автоудаление сообщений';

  @override
  String get automaticMediaDownload => 'Автозагрузка медиа';

  @override
  String get backspace => 'Стереть';

  @override
  String get bio => 'О себе';

  @override
  String get blockedUsers => 'Заблокированные';

  @override
  String get botCommands => 'Команды бота';

  @override
  String get call => 'Позвонить';

  @override
  String get callBack => 'Перезвонить';

  @override
  String get calls => 'Звонки';

  @override
  String get callsEmpty => 'Здесь появятся исходящие и входящие звонки.';

  @override
  String get camera => 'Камера';

  @override
  String get cameraAccessDenied => 'Нет доступа к камере';

  @override
  String get cancel => 'Отмена';

  @override
  String get changePasscode => 'Изменить код-пароль';

  @override
  String get changePhoto => 'Изменить фото';

  @override
  String get channels => 'Каналы';

  @override
  String get checkAgain => 'Проверить снова';

  @override
  String get clear => 'Очистить';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheQuestion => 'Очистить кэш?';

  @override
  String get clearHistory => 'Очистить историю';

  @override
  String get clearHistoryQuestion => 'Очистить историю?';

  @override
  String get contact => 'Контакт';

  @override
  String get contacts => 'Контакты';

  @override
  String get contactsEmpty =>
      'Контакты, добавленные в Telegram, появятся здесь.';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get copied => 'Скопировано';

  @override
  String get copiedToClipboard => 'Скопировано в буфер';

  @override
  String get copy => 'Копировать';

  @override
  String get copyLink => 'Копировать ссылку';

  @override
  String get copyTranslation => 'Копировать перевод';

  @override
  String get passwordChangeFailed =>
      'Не удалось сменить пароль. Проверьте старый.';

  @override
  String get joinFailed => 'Не удалось войти в чат';

  @override
  String get secretChatFailed => 'Не удалось создать секретный чат';

  @override
  String get createPoll => 'Создать опрос';

  @override
  String get createYourAccount => 'Создайте аккаунт';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get dark => 'Тёмная';

  @override
  String get dataAndStorage => 'Данные и память';

  @override
  String get decline => 'Отклонить';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get deleteForMe => 'Удалить у себя';

  @override
  String get deliveredWhenBack => 'Будет доставлено, когда они вернутся';

  @override
  String get description => 'Описание';

  @override
  String get descriptionOptional => 'Описание (необязательно)';

  @override
  String get devices => 'Устройства';

  @override
  String get document => 'Файл';

  @override
  String get downloadAutomatically => 'Загружать автоматически';

  @override
  String get downloadedMedia => 'Загруженные медиа';

  @override
  String get clearCacheExplanation =>
      'Загруженные фото, видео и файлы будут удалены с этого устройства. В Telegram они останутся и загрузятся снова при открытии.';

  @override
  String get edit => 'Изменить';

  @override
  String get editBio => 'Изменить описание';

  @override
  String get editMessage => 'Изменить сообщение';

  @override
  String get editName => 'Изменить имя';

  @override
  String get editUsername => 'Изменить имя пользователя';

  @override
  String get endCall => 'Завершить';

  @override
  String get enterTheCode => 'Введите код';

  @override
  String get enterYourPassword => 'Введите пароль';

  @override
  String get enterPhoneToContinue => 'Введите номер телефона, чтобы продолжить';

  @override
  String get files => 'Файлы';

  @override
  String get filesAndVoice => 'Файлы и голосовые';

  @override
  String get findPeopleAndGroups => 'Найти людей и группы';

  @override
  String get biometricsHint => 'Отпечаток или лицо, если настроены';

  @override
  String get firstName => 'Имя';

  @override
  String get flipCamera => 'Развернуть';

  @override
  String get forEveryone => 'У всех';

  @override
  String get forward => 'Переслать';

  @override
  String get forwardTo => 'Переслать…';

  @override
  String get gif => 'GIF';

  @override
  String get generatingQrCode => 'Создание QR-кода…';

  @override
  String get groups => 'Группы';

  @override
  String get hintOptional => 'Подсказка (необязательно)';

  @override
  String get scheduledEmptyHint =>
      'Зажмите кнопку отправки в чате, чтобы отложить сообщение.';

  @override
  String get holdToRecord => 'Удерживайте для записи голосового';

  @override
  String get notificationScopeHint =>
      'У отдельных чатов свои настройки звука, они важнее этих общих.';

  @override
  String get inviteLink => 'Ссылка-приглашение';

  @override
  String get inviteLinkCopied => 'Ссылка скопирована';

  @override
  String get join => 'Войти';

  @override
  String get languagePacks => 'Языковые пакеты';

  @override
  String get lastName => 'Фамилия';

  @override
  String get lastNameOptional => 'Фамилия (необязательно)';

  @override
  String get leaveChat => 'Покинуть чат';

  @override
  String get light => 'Светлая';

  @override
  String get links => 'Ссылки';

  @override
  String get localDatabase => 'Локальная база';

  @override
  String get lockTheApp => 'Блокировать приложение';

  @override
  String get loginByQrCode => 'Войти по QR-коду';

  @override
  String get loginByPhone => 'Войти по номеру телефона';

  @override
  String get logOut => 'Выйти';

  @override
  String get logOutQuestion => 'Выйти?';

  @override
  String get media => 'Медиа';

  @override
  String get autoDownloadExplanation =>
      'Медиа меньше этих размеров появляются сами. У более крупных останется кнопка загрузки.';

  @override
  String get members => 'Участники';

  @override
  String get messageActions => 'Действия с сообщением';

  @override
  String get microphonePermissionRequired => 'Нужен доступ к микрофону';

  @override
  String get minimize => 'Свернуть';

  @override
  String get more => 'Ещё';

  @override
  String get multipleAnswers => 'Несколько ответов';

  @override
  String get music => 'Музыка';

  @override
  String get mute => 'Выключить звук';

  @override
  String get myProfile => 'Мой профиль';

  @override
  String get name => 'Название';

  @override
  String get newChannelTitle => 'Новый канал';

  @override
  String get newGroupTitle => 'Новая группа';

  @override
  String get newChannel => 'Новый канал';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get newMessage => 'Новое сообщение';

  @override
  String get autoDeleteExplanation =>
      'Новые сообщения в этом чате удаляются у всех через выбранное время. Уже отправленные не затрагиваются.';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get newPoll => 'Новый опрос';

  @override
  String get noProxyLinkInClipboard =>
      'В буфере нет ссылки на прокси Telegram.';

  @override
  String get noCallsYet => 'Звонков пока нет';

  @override
  String get noChatsYet => 'Чатов пока нет';

  @override
  String get noContacts => 'Нет контактов';

  @override
  String get noContactsFound => 'Контакты не найдены';

  @override
  String get noCountriesFound => 'Страны не найдены';

  @override
  String get noMembersToShow => 'Нет участников для показа';

  @override
  String get noMessagesFound => 'Сообщения не найдены';

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get noProxiesYet =>
      'Прокси пока нет. Добавьте вручную или скопируйте ссылку t.me/proxy и нажмите вставку.';

  @override
  String get noSavedGifs => 'Нет сохранённых GIF';

  @override
  String get noStickersYet => 'Стикеров пока нет';

  @override
  String get noInteractionInfo =>
      'На это сообщение никто не отреагировал, а кто его прочитал, Telegram здесь не сообщает.';

  @override
  String get nobodyBlocked =>
      'Никто не заблокирован. Заблокированные не могут писать вам и не видят, когда вы в сети.';

  @override
  String get nothingScheduled => 'Ничего не отложено';

  @override
  String get notificationsAndSounds => 'Уведомления и звуки';

  @override
  String get appLocked => 'Nullgram заблокирован';

  @override
  String get qrInstructions =>
      'Откройте Telegram на телефоне, зайдите в Настройки → Устройства → Подключить устройство и отсканируйте код.';

  @override
  String get passcode => 'Код-пароль';

  @override
  String get passcodeLock => 'Код-пароль';

  @override
  String get password => 'Пароль';

  @override
  String get passwordOptional => 'Пароль (необязательно)';

  @override
  String get phone => 'Телефон';

  @override
  String get phoneNumber => 'Номер телефона';

  @override
  String get photos => 'Фото';

  @override
  String get pickDateAndTime => 'Выберите дату и время';

  @override
  String get poll => 'Опрос';

  @override
  String get port => 'Порт';

  @override
  String get privacyAndSecurity => 'Конфиденциальность';

  @override
  String get privateChats => 'Личные чаты';

  @override
  String get proxy => 'Прокси';

  @override
  String get question => 'Вопрос';

  @override
  String get reactionsAndViews => 'Реакции и просмотры';

  @override
  String get recoveryEmailIsSet => 'Резервная почта задана';

  @override
  String get remove => 'Убрать';

  @override
  String get removeFromGroup => 'Исключить из группы';

  @override
  String get repeatThePasscode => 'Повторите код-пароль';

  @override
  String get reply => 'Ответить';

  @override
  String get resendCode => 'Отправить код снова';

  @override
  String get save => 'Сохранить';

  @override
  String get savedMessages => 'Избранное';

  @override
  String get savedToGallery => 'Сохранено в галерею';

  @override
  String get scheduleMessage => 'Отложить сообщение';

  @override
  String get scheduledMessages => 'Отложенные сообщения';

  @override
  String get search => 'Поиск';

  @override
  String get searchChatsAndMessages => 'Поиск чатов и сообщений';

  @override
  String get searchChatsHint => 'Поиск чатов…';

  @override
  String get searchContacts => 'Поиск контактов';

  @override
  String get searchCountry => 'Поиск страны';

  @override
  String get searchInChat => 'Поиск в чате';

  @override
  String get searchMessages => 'Поиск сообщений';

  @override
  String get searchMessagesHint => 'Поиск сообщений…';

  @override
  String get secret => 'Секретный';

  @override
  String get select => 'Выбрать';

  @override
  String get selectMessages => 'Выбрать сообщения';

  @override
  String get sendHoldForOptions => 'Отправить (удерживайте для опций)';

  @override
  String get chatEmptyHint => 'Отправьте сообщение, чтобы начать разговор.';

  @override
  String get sendMessage => 'Отправить сообщение';

  @override
  String get sendAsAlbumHint => 'Отправьте одно или несколько альбомом';

  @override
  String get sendWhenOnline => 'Отправить, когда будет в сети';

  @override
  String get sendWithoutSound => 'Отправить без звука';

  @override
  String get server => 'Сервер';

  @override
  String get setAPasscode => 'Задать код-пароль';

  @override
  String get settings => 'Настройки';

  @override
  String get share => 'Поделиться';

  @override
  String get shareAContact => 'Отправить контакт';

  @override
  String get sharedMedia => 'Общие медиа';

  @override
  String get showInChat => 'Показать в чате';

  @override
  String get signOut => 'Завершить';

  @override
  String get signOutDeviceQuestion => 'Завершить сеанс на этом устройстве?';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get speaker => 'Громкая связь';

  @override
  String get startSecretChat => 'Начать секретный чат';

  @override
  String get submit => 'Подтвердить';

  @override
  String get system => 'Системная';

  @override
  String get termsOfService => 'Условия использования';

  @override
  String get passwordNotAccepted => 'Пароль не принят.';

  @override
  String get mtprotoSecretHint => 'Секрет в hex или base64 из ссылки на прокси';

  @override
  String get silentSendHint => 'Получатель не получит уведомление';

  @override
  String get buttonNotSupported => 'Эта кнопка пока не поддерживается';

  @override
  String get cannotBeUndone => 'Это действие нельзя отменить.';

  @override
  String get memberListHidden =>
      'Этот чат не показывает вам список участников.';

  @override
  String get thisDevice => 'Это устройство';

  @override
  String get noBiometricsEnrolled =>
      'На этом устройстве не настроена биометрия.';

  @override
  String get inviteLinkInvalid => 'Эта ссылка-приглашение больше не действует';

  @override
  String get registrationSubtitle =>
      'Этот номер ещё не зарегистрирован. Выберите имя, которое увидят другие.';

  @override
  String get translate => 'Перевести';

  @override
  String get translation => 'Перевод';

  @override
  String get tryDifferentSearch => 'Попробуйте другой запрос.';

  @override
  String get turnOff => 'Выключить';

  @override
  String get turnOffPasscodeQuestion => 'Выключить код-пароль?';

  @override
  String get turnOffTwoStep => 'Выключить двухэтапную проверку';

  @override
  String get turnOffTwoStepQuestion => 'Выключить двухэтапную проверку?';

  @override
  String get twoStepVerification => 'Двухэтапная проверка';

  @override
  String get twoStepUnavailable => 'Двухэтапная проверка сейчас недоступна.';

  @override
  String get searchInChatHint =>
      'Наберите текст, чтобы найти сообщения в этом чате.';

  @override
  String get searchGlobalHint => 'Наберите текст для поиска по Telegram.';

  @override
  String get unblock => 'Разблокировать';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get unlockPrompt => 'Разблокировать Nullgram';

  @override
  String get unlockWithBiometrics => 'Разблокировка биометрией';

  @override
  String get unreadMessages => 'Непрочитанные сообщения';

  @override
  String get useAProxy => 'Использовать прокси';

  @override
  String get useBiometrics => 'Использовать биометрию';

  @override
  String get amoledDarkSubtitle => 'Истинно чёрные поверхности';

  @override
  String get username => 'Имя пользователя';

  @override
  String get usernameOptional => 'Имя пользователя (необязательно)';

  @override
  String get verify => 'Проверить';

  @override
  String get video => 'Видео';

  @override
  String get videoCall => 'Видеозвонок';

  @override
  String get videoMessage => 'Видеосообщение';

  @override
  String get videos => 'Видео';

  @override
  String get voice => 'Голосовое';

  @override
  String get welcomeToNullgram => 'Добро пожаловать в Nullgram';

  @override
  String get writeAMessage => 'Напишите сообщение…';

  @override
  String get wrongNumber => 'Неверный номер?';

  @override
  String get logOutWarning =>
      'Чтобы снова пользоваться приложением, придётся войти заново.';

  @override
  String get twoStepDisableWarning =>
      'Аккаунт будет защищён только кодом входа.';

  @override
  String get chatsEmptyHint => 'Здесь появятся ваши беседы.';

  @override
  String get clearCacheNote =>
      'Сообщения не затрагиваются — удаляются только файлы в кэше этого устройства.';

  @override
  String get proxyInUse => '· используется';

  @override
  String get never => 'Никогда';

  @override
  String get passcodeMinLengthHint => 'Не менее 4 цифр';

  @override
  String get codesDoNotMatch => 'Коды не совпадают';

  @override
  String get wrongPasscode => 'Неверный код-пароль';

  @override
  String get language => 'Язык';

  @override
  String get appearance => 'Оформление';

  @override
  String get preferences => 'Настройки';

  @override
  String get account => 'Аккаунт';

  @override
  String get mobileData => 'Мобильная сеть';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get lockImmediately => 'Сразу';

  @override
  String get lockAfterOneMinute => 'Через 1 минуту';

  @override
  String get lockAfterFiveMinutes => 'Через 5 минут';

  @override
  String get lockAfterOneHour => 'Через 1 час';

  @override
  String get autoDeleteOff => 'Автоудаление: выкл.';

  @override
  String get autoDeleteOn => 'Автоудаление: вкл.';

  @override
  String get off => 'Выключено';

  @override
  String get oneDay => '1 день';

  @override
  String get oneWeek => '1 неделя';

  @override
  String get oneMonth => '1 месяц';

  @override
  String get viewProfile => 'Профиль';

  @override
  String get chatInfo => 'Инфо о чате';

  @override
  String get unmute => 'Включить звук';

  @override
  String get blockUser => 'Заблокировать';

  @override
  String get unblockUser => 'Разблокировать';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get reactions => 'Реакции';

  @override
  String get readBy => 'Прочитали';

  @override
  String get editProxy => 'Изменить прокси';

  @override
  String get proxyRouteHint => 'Направлять соединение через выбранный сервер';

  @override
  String get addProxyFirst => 'Сначала добавьте прокси';

  @override
  String get proxyChecking => 'проверка…';

  @override
  String get proxyUnavailable => 'недоступен';

  @override
  String get translationFailed => 'Telegram не смог перевести это сообщение.';

  @override
  String get accountCreationFailed =>
      'Не удалось создать аккаунт. Попробуйте ещё раз.';

  @override
  String get acceptTermsQuestion => 'Вы принимаете Условия использования?';

  @override
  String get incorrectPassword => 'Неверный пароль. Попробуйте снова.';

  @override
  String get passwordUpdated => 'Пароль обновлён';

  @override
  String get twoStepDisabled => 'Двухэтапная проверка выключена';

  @override
  String get confirmYourPassword => 'Подтвердите пароль';

  @override
  String get twoStepPassword => 'Пароль двухэтапной проверки';

  @override
  String get passwordIsOn => 'Пароль включён';

  @override
  String get passwordIsOff => 'Пароль выключён';

  @override
  String get setPassword => 'Задать пароль';

  @override
  String get changePassword => 'Изменить пароль';

  @override
  String get notifyPrivateDescription => 'Сообщения от людей и ботов';

  @override
  String get notifyGroupsDescription => 'Сообщения в группах, где вы участник';

  @override
  String get notifyChannelsDescription =>
      'Публикации из каналов, на которые вы подписаны';

  @override
  String get followSystem => 'Как в системе';

  @override
  String get interfaceLanguage => 'Язык интерфейса';

  @override
  String get groupName => 'Название группы';

  @override
  String get channelName => 'Название канала';

  @override
  String get createGroup => 'Создать группу';

  @override
  String get createChannel => 'Создать канал';

  @override
  String get groupCreateFailed =>
      'Не удалось создать группу. Попробуйте ещё раз.';

  @override
  String get channelCreateFailed =>
      'Не удалось создать канал. Попробуйте ещё раз.';

  @override
  String get nothingSharedYet => 'Здесь пока ничего нет';

  @override
  String get searchChats => 'Поиск чатов';

  @override
  String get noChatsFound => 'Чаты не найдены';

  @override
  String get keyboard => 'Клавиатура';

  @override
  String get emojiAndStickers => 'Эмодзи и стикеры';

  @override
  String appVersionLabel(String version) {
    return 'Nullgram $version';
  }

  @override
  String pollAnswerLabel(int number) {
    return 'Вариант $number';
  }

  @override
  String hintWithText(String hint) {
    return 'Подсказка: $hint';
  }

  @override
  String joinChatQuestion(String title) {
    return 'Войти в $title?';
  }

  @override
  String usernameNotFound(String username) {
    return 'Аккаунт Telegram @$username не найден';
  }

  @override
  String resendCodeIn(int seconds) {
    return 'Отправить снова через $seconds с';
  }

  @override
  String forwardedFrom(String name) {
    return 'Переслано от $name';
  }

  @override
  String upToSize(String size) {
    return 'До $size';
  }

  @override
  String reactionsWithCount(int count) {
    return 'Реакции · $count';
  }

  @override
  String readByWithCount(int count) {
    return 'Прочитали · $count';
  }

  @override
  String failedToDownload(String error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String failedToPlay(String error) {
    return 'Не удалось воспроизвести: $error';
  }

  @override
  String failedToSave(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String failedToShare(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String membersCount(String count) {
    return '$count участников';
  }

  @override
  String subscribersCount(String count) {
    return '$count подписчиков';
  }

  @override
  String pingMilliseconds(int milliseconds) {
    return '$milliseconds мс';
  }

  @override
  String autoDeleteAfterDays(int days) {
    return 'Автоудаление: $days дн.';
  }

  @override
  String get addAccount => 'Добавить аккаунт';

  @override
  String get switchAccounts => 'Переключить аккаунт';

  @override
  String logOutAccountQuestion(String name) {
    return 'Выйти из аккаунта $name?';
  }

  @override
  String accountUnreadMessages(int count) {
    return '$count непрочитанных';
  }

  @override
  String get phoneNumberInvalid => 'Неверный номер телефона.';

  @override
  String get appVerificationFailed =>
      'Telegram не смог проверить это приложение. Для входа нужен свой api_id с my.telegram.org.';

  @override
  String get apiIdPublishedFlood =>
      'Этот api_id опубликован, и Telegram больше не пускает по нему. Получите свой на my.telegram.org.';

  @override
  String signInFailed(String reason) {
    return 'Не удалось войти: $reason';
  }
}
