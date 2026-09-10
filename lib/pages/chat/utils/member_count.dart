import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:nullgram/l10n/l10n.dart';

/// "12,345 members", or subscribers for a channel.
///
/// Shared by the chat header and the profile page, which showed the same line
/// with two copies of the same formatting.
String memberCountLabel(
  BuildContext context,
  int count, {
  required bool isChannel,
}) {
  // Group separators differ by language, so the number follows the locale
  // rather than a hard-coded en_US pattern.
  final formatted = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(count);

  return isChannel
      ? context.l10n.subscribersCount(formatted)
      : context.l10n.membersCount(formatted);
}
