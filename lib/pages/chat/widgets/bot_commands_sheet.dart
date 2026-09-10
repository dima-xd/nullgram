import 'package:flutter/material.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Lists the commands a chat's bots advertise and resolves to the chosen one,
/// slash included, or null when dismissed.
Future<String?> showBotCommandsSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> commands,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _BotCommandsSheet(commands: commands),
  );
}

class _BotCommandsSheet extends StatelessWidget {
  const _BotCommandsSheet({required this.commands});

  final List<Map<String, dynamic>> commands;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sheetBottomPadding(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.botCommands,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final command in commands)
              _CommandTile(
                command: command['command'] as String? ?? '',
                description: command['description'] as String? ?? '',
              ),
          ],
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.command, required this.description});

  /// The command name as TDLib reports it, without a leading slash.
  final String command;

  final String description;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('/$command'),
      subtitle: description.isEmpty ? null : Text(description),
      onTap: () => Navigator.pop(context, '/$command'),
    );
  }
}
