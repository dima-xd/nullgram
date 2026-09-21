import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_route.dart';
import 'package:nullgram/pages/contacts/contacts_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// What [CreateChatPage] is creating.
enum NewChatKind {
  group,
  channel;

  /// The page title for this kind.
  String title(BuildContext context) => this == NewChatKind.group
      ? context.l10n.newGroup
      : context.l10n.newChannel;

  /// The label of the name field.
  String nameHint(BuildContext context) => this == NewChatKind.group
      ? context.l10n.groupName
      : context.l10n.channelName;

  /// The label of the confirm button.
  String action(BuildContext context) => this == NewChatKind.group
      ? context.l10n.createGroup
      : context.l10n.createChannel;

  /// What to say when creation failed.
  String failure(BuildContext context) => this == NewChatKind.group
      ? context.l10n.groupCreateFailed
      : context.l10n.channelCreateFailed;
}

/// Creates a group or a channel.
///
/// A group needs at least one other member, so its flow collects members from
/// [ContactsPage] first; a channel starts empty and only needs a name.
class CreateChatPage extends StatefulWidget {
  const CreateChatPage({super.key, required this.kind});

  final NewChatKind kind;

  @override
  State<CreateChatPage> createState() => _CreateChatPageState();
}

class _CreateChatPageState extends State<CreateChatPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ValueNotifier<List<int>> _memberIds = ValueNotifier(const []);
  final ValueNotifier<bool> _isCreating = ValueNotifier(false);
  final ValueNotifier<String?> _error = ValueNotifier(null);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberIds.dispose();
    _isCreating.dispose();
    _error.dispose();
    super.dispose();
  }

  Future<void> _pickMembers() async {
    final picked = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactsPage(
          selectable: true,
          title: context.l10n.addMembers,
        ),
      ),
    );
    if (picked != null) _memberIds.value = picked;
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _error.value = 'Enter a name';
      return;
    }
    if (widget.kind == NewChatKind.group && _memberIds.value.isEmpty) {
      _error.value = 'Add at least one member';
      return;
    }

    _error.value = null;
    _isCreating.value = true;

    final chat = widget.kind == NewChatKind.group
        ? await TDLibClient.createNewBasicGroupChat(
            title: name,
            userIds: _memberIds.value,
          )
        : await TDLibClient.createNewSupergroupChat(
            title: name,
            isChannel: true,
            description: _descriptionController.text.trim(),
          );

    if (!mounted) return;
    _isCreating.value = false;

    if (chat == null || chat['id'] == null) {
      _error.value = widget.kind.failure(context);
      return;
    }

    // Replace this screen so backing out of the new chat lands on the chat
    // list rather than on a stale creation form.
    Navigator.pushReplacement(
      context,
      chatRoute(chat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.kind == NewChatKind.group;

    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.title(context))),
      body: ListView(
        padding: withBottomSafeArea(context, const EdgeInsets.all(16)),
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: widget.kind.nameHint(context),
              border: const OutlineInputBorder(),
            ),
          ),
          if (!isGroup) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.descriptionOptional,
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (isGroup) ...[
            const SizedBox(height: 16),
            ValueListenableBuilder<List<int>>(
              valueListenable: _memberIds,
              builder: (context, members, child) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person_add_outlined),
                  title: Text(context.l10n.members),
                  subtitle: Text(
                    members.isEmpty
                        ? 'Nobody added yet'
                        : '${members.length} selected',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickMembers,
                ),
              ),
            ),
          ],
          ValueListenableBuilder<String?>(
            valueListenable: _error,
            builder: (context, error, child) {
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<bool>(
            valueListenable: _isCreating,
            builder: (context, isCreating, child) => FilledButton(
              onPressed: isCreating ? null : _create,
              child: isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.kind.action(context)),
            ),
          ),
        ],
      ),
    );
  }
}
