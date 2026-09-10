import 'package:flutter/widgets.dart';
import 'package:nullgram/l10n/app_localizations.dart';

export 'package:nullgram/l10n/app_localizations.dart';

/// Shorthand for the generated strings.
///
/// `context.l10n.settings` reads better at every call site than
/// `AppLocalizations.of(context)!.settings`, and there are several hundred of
/// them.
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
