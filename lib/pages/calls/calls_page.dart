import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/services/call_service.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The call log.
///
/// TDLib has no dedicated call list: calls are ordinary `messageCall` messages,
/// which `searchCallMessages` collects from every chat.
class CallsPage extends StatefulWidget {
  const CallsPage({super.key});

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _calls =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _calls.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await TDLibClient.searchCallMessages();
    if (!mounted) return;
    _calls.value = result?.messages ?? const [];
    _isLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.calls)),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _calls,
            builder: (context, calls, child) {
              if (calls.isEmpty) {
                return EmptyState(
                  icon: Icons.phone_outlined,
                  title: context.l10n.noCallsYet,
                  subtitle: context.l10n.callsEmpty,
                );
              }
              return RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: withBottomSafeArea(context),
                  itemCount: calls.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 72,
                  ),
                  itemBuilder: (context, index) =>
                      _CallTile(message: calls[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One row of the call log, with a redial button.
class _CallTile extends StatelessWidget {
  const _CallTile({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = message['content'] as Map<String, dynamic>?;
    final isOutgoing = message['isOutgoing'] == true;
    final isVideo = content?['isVideo'] == true;
    final duration = content?['duration'] as int? ?? 0;
    final discardReason = content?['discardReason']?['@type'] as String?;
    final isMissed = discardReason == 'CallDiscardReasonMissed' ||
        discardReason == 'CallDiscardReasonDeclined';

    final chat = ChatStore.instance.chat(message['chatId'] as int);
    final title = chat?['title'] as String? ?? 'Unknown';
    final userId = chat?['type']?['userId'] as int?;

    return ListTile(
      leading: chat == null
          ? CircleAvatar(
              radius: 22,
              backgroundColor: scheme.surfaceContainerHighest,
              child: const Icon(Icons.person),
            )
          : ChatAvatar(chat: chat, radius: 22),
      title: Text(title),
      subtitle: Row(
        children: [
          Icon(
            isOutgoing ? Icons.call_made : Icons.call_received,
            size: 15,
            color: isMissed ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(_subtitle(isMissed, duration)),
        ],
      ),
      trailing: userId == null
          ? null
          : IconButton(
              icon: Icon(isVideo ? Icons.videocam_outlined : Icons.call),
              tooltip: context.l10n.callBack,
              onPressed: () =>
                  callService.startCall(userId: userId, isVideo: isVideo),
            ),
    );
  }

  String _subtitle(bool isMissed, int duration) {
    final when = MessageFormatter.formatDateSeparator(message['date']);
    if (isMissed) return '$when · missed';
    if (duration <= 0) return when;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$when · ${minutes}m ${seconds}s';
  }
}
