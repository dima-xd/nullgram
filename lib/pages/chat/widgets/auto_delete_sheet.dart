import 'package:flutter/material.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The self-destruct timers Telegram offers, in seconds.
///
/// TDLib accepts any value, but every Telegram client offers exactly these,
/// and a chat whose timer came from another client still shows correctly
/// because the current value is always listed.
const List<int> autoDeleteChoices = [0, 86400, 604800, 2678400];

/// How one timer reads in the list.
String autoDeleteChoiceLabel(BuildContext context, int seconds) =>
    switch (seconds) {
      0 => context.l10n.off,
      86400 => context.l10n.oneDay,
      604800 => context.l10n.oneWeek,
      2678400 => context.l10n.oneMonth,
      // A timer set from another client can be any value at all.
      _ => context.l10n.autoDeleteAfterDays(seconds ~/ 86400),
    };

/// Asks for a new self-destruct timer for a chat, in seconds.
///
/// Resolves to null when dismissed, so "no change" is distinguishable from
/// "turn it off".
Future<int?> showAutoDeleteSheet(
  BuildContext context, {
  required int currentSeconds,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _AutoDeleteSheet(current: currentSeconds),
  );
}

class _AutoDeleteSheet extends StatelessWidget {
  const _AutoDeleteSheet({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final sorted = {...autoDeleteChoices, current}.toList()..sort();

    return Padding(
      padding: sheetBottomPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.autoDeleteMessages,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.autoDeleteExplanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          RadioGroup<int>(
            groupValue: current,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final seconds in sorted)
                  RadioListTile<int>(
                    value: seconds,
                    title: Text(autoDeleteChoiceLabel(context, seconds)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
