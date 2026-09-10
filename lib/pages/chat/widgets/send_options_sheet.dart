import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/send_options.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Offers the alternatives to an immediate, notifying send.
///
/// Reached by holding the send button, the way Telegram does it. Returns null
/// when the user dismissed the sheet without choosing.
Future<SendOptions?> showSendOptionsSheet({
  required BuildContext context,
  required bool isPrivateChat,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(context.l10n.sendWithoutSound),
            subtitle: Text(context.l10n.silentSendHint),
            onTap: () => Navigator.pop(sheetContext, 'silent'),
          ),
          // TDLib can only wait for a *user* to come online, so this is
          // meaningless in a group or channel.
          if (isPrivateChat)
            ListTile(
              leading: const Icon(Icons.schedule_send_outlined),
              title: Text(context.l10n.sendWhenOnline),
              subtitle: Text(context.l10n.deliveredWhenBack),
              onTap: () => Navigator.pop(sheetContext, 'online'),
            ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(context.l10n.scheduleMessage),
            subtitle: Text(context.l10n.pickDateAndTime),
            onTap: () => Navigator.pop(sheetContext, 'schedule'),
          ),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return null;

  switch (choice) {
    case 'silent':
      return SendOptions.silentNow;
    case 'online':
      return SendOptions.whenOnline;
    case 'schedule':
      final date = await _pickDateTime(context);
      return date == null ? null : SendOptions(sendAtDate: date);
    default:
      return null;
  }
}

/// Asks for a date and then a time, and combines them.
///
/// Returns null if either step was cancelled, and refuses a moment already in
/// the past — TDLib rejects those outright.
Future<DateTime?> _pickDateTime(BuildContext context) async {
  final now = DateTime.now();

  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now,
    // Telegram allows scheduling up to a year out.
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(
      now.add(const Duration(minutes: 10)),
    ),
  );
  if (time == null) return null;

  final scheduled = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  return scheduled.isAfter(now) ? scheduled : null;
}
