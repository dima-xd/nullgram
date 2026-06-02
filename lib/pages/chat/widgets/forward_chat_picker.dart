import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Presents a bottom sheet listing the user's chats and resolves to the chat
/// id chosen as a forward destination, or null if dismissed.
Future<int?> showForwardChatPicker(BuildContext context) {
  final theme = Theme.of(context);
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ForwardChatPicker(),
  );
}

class _ForwardChatPicker extends StatefulWidget {
  const _ForwardChatPicker();

  @override
  State<_ForwardChatPicker> createState() => _ForwardChatPickerState();
}

class _ForwardChatPickerState extends State<_ForwardChatPicker> {
  final ValueNotifier<List<Map<String, dynamic>>> _chats = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  // ChatListItem needs these caches; an empty pair just disables avatar
  // caching for the picker, which is fine for a short-lived sheet.
  final Map<String, bool> _fileExistsCache = {};
  final Map<String, Uint8List?> _miniThumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final chatIds = await TDLibClient.getChats();
    final loaded = <Map<String, dynamic>>[];
    for (final chatId in chatIds) {
      final chat = await TDLibClient.getChat(chatId: chatId);
      if (chat != null) loaded.add(chat);
    }
    if (!mounted) return;
    _chats.value = loaded;
    _isLoading.value = false;
  }

  @override
  void dispose() {
    _chats.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Forward to…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoading,
                builder: (context, isLoading, child) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _chats,
                    builder: (context, chats, child) {
                      if (chats.isEmpty) {
                        return const Center(child: Text('No chats'));
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: chats.length,
                        itemBuilder: (context, index) => ChatListItem(
                          chat: chats[index],
                          currentFolderId: null,
                          fileExistsCache: _fileExistsCache,
                          miniThumbnailCache: _miniThumbnailCache,
                          onTap: (chatId) => Navigator.of(context).pop(chatId),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
