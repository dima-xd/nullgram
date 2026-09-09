import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';

/// The messages queued to be sent in a chat later.
///
/// TDLib keeps scheduled messages out of the chat history in a separate list,
/// so they need their own screen; sending one now or dropping it are the only
/// two things Telegram offers here.
class ScheduledMessagesPage extends StatefulWidget {
  const ScheduledMessagesPage({super.key, required this.chat});

  final Map<String, dynamic> chat;

  @override
  State<ScheduledMessagesPage> createState() => _ScheduledMessagesPageState();
}

class _ScheduledMessagesPageState extends State<ScheduledMessagesPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _messages =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  int get _chatId => widget.chat['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messages.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await TDLibClient.getChatScheduledMessages(
      chatId: _chatId,
    );
    if (!mounted) return;
    _messages.value = messages;
    _isLoading.value = false;
  }

  Future<void> _delete(Map<String, dynamic> message) async {
    await TDLibClient.deleteMessages(
      chatId: _chatId,
      messageIds: [message['id'] as int],
      revoke: false,
    );
    await _load();
  }

  /// A scheduled message's own delivery time, or a label for the
  /// "when they come online" case, which has no date at all.
  String _whenLabel(Map<String, dynamic> message) {
    final state = message['schedulingState'];
    if (state?['@type'] == 'MessageSchedulingStateSendWhenOnline') {
      return 'When they come online';
    }
    final sendDate = state?['sendDate'] as int?;
    if (sendDate == null) return 'Scheduled';
    final date = DateTime.fromMillisecondsSinceEpoch(sendDate * 1000);
    return '${MessageFormatter.formatDateSeparator(sendDate)} at '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled messages')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _messages,
            builder: (context, messages, child) {
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.schedule_send_outlined,
                  title: 'Nothing scheduled',
                  subtitle:
                      'Hold the send button in a chat to schedule a message.',
                );
              }
              return ListView.separated(
                itemCount: messages.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      messagePreviewText(message),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_whenLabel(message)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(message),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
