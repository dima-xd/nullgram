import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger();

/// Reports which language packs this application is served, and whether an
/// official key resolves.
///
/// A pack's strings live in the *current localization target*, and that target
/// belongs to the application behind the `api_id` in use — so how much the
/// platform at translations.telegram.org could contribute to the interface is
/// a question about credentials, not about code. This answers it before any of
/// that is designed in.
Future<void> probeLocalization() async {
  final target = await TDLibClient.getStringOption('localization_target');
  final packs = await TDLibClient.getLocalizationTargetInfo();
  _log.i('localization_target=${target ?? '<unset>'} packs=${packs.length}');

  for (final pack in packs.take(8)) {
    _log.i('pack ${pack['id']} "${pack['name']}" '
        'official=${pack['isOfficial']} installed=${pack['isInstalled']} '
        'strings=${pack['translatedStringCount']}/${pack['totalStringCount']} '
        'local=${pack['localStringCount']}');
  }

  // Real keys of the official Android app: if these resolve, its whole string
  // set is reachable and worth building on.
  final strings = await TDLibClient.getLanguagePackStrings(
    languagePackId: 'ru',
    keys: const ['Settings', 'Cancel', 'SavedMessages'],
  );
  _log.i('sample ru strings=$strings');
}

/// The languages the app itself is translated into.
///
/// Distinct from the far longer list of TDLib language packs: those only
/// translate the strings TDLib generates, and picking one the app has no
/// translation for would leave a half-translated screen.
const Map<String, String> appLanguages = {'en': 'English', 'ru': 'Русский'};

/// Where the chosen language is remembered.
const String _languagePreferenceKey = 'app.locale';

/// The chosen interface language, or null to follow the system.
///
/// Read by `MaterialApp.locale`, so writing it re-renders the whole app.
final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

/// Loads the stored language, if any.
Future<void> restoreLocale() async {
  final preferences = await SharedPreferences.getInstance();
  final code = preferences.getString(_languagePreferenceKey);
  if (code == null || !appLanguages.containsKey(code)) return;
  localeNotifier.value = Locale(code);
}

/// Switches the interface language, or follows the system when [code] is null.
///
/// Also moves TDLib's own language pack, so service messages and server error
/// strings arrive in the same language as the rest of the app.
Future<void> setAppLanguage(String? code) async {
  localeNotifier.value = code == null ? null : Locale(code);

  final preferences = await SharedPreferences.getInstance();
  if (code == null) {
    await preferences.remove(_languagePreferenceKey);
  } else {
    await preferences.setString(_languagePreferenceKey, code);
  }

  // Following the system means handing TDLib the device's language, not
  // clearing the pack: an empty pack id makes it fall back to English.
  await TDLibClient.setLanguagePackId(
    code ?? PlatformDispatcher.instance.locale.languageCode,
  );
}
