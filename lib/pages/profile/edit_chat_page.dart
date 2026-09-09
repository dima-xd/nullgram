import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// Edits a group's or channel's name, description and photo.
///
/// Only reachable when TDLib reports `canChangeInfo` for the signed-in user, so
/// this screen doesn't itself re-check permissions — it just reports whatever
/// TDLib rejects.
class EditChatPage extends StatefulWidget {
  const EditChatPage({
    super.key,
    required this.chat,
    required this.description,
  });

  final Map<String, dynamic> chat;

  /// The chat's current description, from its full info.
  final String description;

  @override
  State<EditChatPage> createState() => _EditChatPageState();
}

class _EditChatPageState extends State<EditChatPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.chat['title'] as String? ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.description);

  final ValueNotifier<bool> _isSaving = ValueNotifier(false);

  /// A locally picked photo, shown before it is uploaded.
  final ValueNotifier<String?> _pickedPhotoPath = ValueNotifier(null);

  int get _chatId => widget.chat['id'] as int;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _isSaving.dispose();
    _pickedPhotoPath.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) _pickedPhotoPath.value = file.path;
  }

  Future<void> _save() async {
    _isSaving.value = true;

    // Each field is a separate TDLib call, so only the changed ones are sent.
    final title = _title.text.trim();
    if (title.isNotEmpty && title != widget.chat['title']) {
      await TDLibClient.setChatTitle(chatId: _chatId, title: title);
    }

    final description = _description.text.trim();
    if (description != widget.description) {
      await TDLibClient.setChatDescription(
        chatId: _chatId,
        description: description,
      );
    }

    final photoPath = _pickedPhotoPath.value;
    if (photoPath != null) {
      await TDLibClient.setChatPhoto(chatId: _chatId, path: photoPath);
    }

    if (!mounted) return;
    _isSaving.value = false;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isChannel = widget.chat['type']?['isChannel'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isChannel ? 'Edit channel' : 'Edit group'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _isSaving,
            builder: (context, isSaving, child) => IconButton(
              icon: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: isSaving ? null : _save,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: withBottomSafeArea(context, const EdgeInsets.all(16)),
        children: [
          Center(
            child: ValueListenableBuilder<String?>(
              valueListenable: _pickedPhotoPath,
              builder: (context, path, child) => Stack(
                children: [
                  ChatAvatar(
                    // A locally picked file is fed in through the same `photo`
                    // shape TDLib uses, so the avatar renders it unchanged.
                    chat: path == null
                        ? widget.chat
                        : {
                            ...widget.chat,
                            'photo': {
                              'small': {
                                'id': 0,
                                'local': {
                                  'path': path,
                                  'isDownloadingCompleted': true,
                                },
                              },
                            },
                          },
                    radius: 48,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      tooltip: 'Change photo',
                      onPressed: _pickPhoto,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: isChannel ? 'Channel name' : 'Group name',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 4,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
