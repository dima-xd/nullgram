import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/contacts/contacts_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// The member list of a group or channel, with the moderation actions the
/// current user is allowed to perform.
///
/// Basic groups carry their members inside `basicGroupFullInfo`, while
/// supergroups and channels need a paged `getSupergroupMembers` call — the two
/// are normalised into the same `chatMember` shape here.
class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({super.key, required this.chat});

  final Map<String, dynamic> chat;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _members =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  /// Resolved users behind the member ids, so a row can show a name.
  final Map<int, Map<String, dynamic>> _users = {};

  /// Whether the signed-in user may add, remove and promote members.
  bool _canManage = false;

  int get _chatId => widget.chat['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _members.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    final type = widget.chat['type'];

    final members = switch (type?['@type']) {
      'ChatTypeBasicGroup' => await _loadBasicGroupMembers(
          type['basicGroupId'] as int,
        ),
      'ChatTypeSupergroup' => await TDLibClient.getSupergroupMembers(
          supergroupId: type['supergroupId'] as int,
        ),
      _ => const <Map<String, dynamic>>[],
    };

    await _resolveUsers(members);
    if (!mounted) return;

    // Reads the freshly loaded list, not `_members`, which is only
    // published below.
    _canManage = await _resolveCanManage(members);
    if (!mounted) return;

    _members.value = members;
    _isLoading.value = false;
  }

  Future<List<Map<String, dynamic>>> _loadBasicGroupMembers(
    int basicGroupId,
  ) async {
    final info = await TDLibClient.getBasicGroupFullInfo(
      basicGroupId: basicGroupId,
    );
    return [
      for (final member in (info?['members'] as List? ?? const []))
        Map<String, dynamic>.from(member as Map),
    ];
  }

  Future<void> _resolveUsers(List<Map<String, dynamic>> members) async {
    final ids = {
      for (final member in members)
        if (member['memberId']?['@type'] == 'MessageSenderUser')
          member['memberId']['userId'] as int,
    }..removeWhere(_users.containsKey);

    final users = await Future.wait(
      ids.map((id) => TDLibClient.getUser(userId: id)),
    );
    for (final user in users) {
      if (user != null) _users[user['id'] as int] = user;
    }
  }

  /// Whether the signed-in user's own status in this chat allows managing
  /// members. Only a creator or an administrator with the right flag does.
  Future<bool> _resolveCanManage(
    List<Map<String, dynamic>> members,
  ) async {
    final me = await TDLibClient.getMe();
    final myId = me?['id'] as int?;
    if (myId == null) return false;

    final myStatus = _statusOf(myId, members);
    return switch (myStatus?['@type']) {
      'ChatMemberStatusCreator' => true,
      'ChatMemberStatusAdministrator' =>
        myStatus?['rights']?['canRestrictMembers'] == true,
      _ => false,
    };
  }

  Map<String, dynamic>? _statusOf(
    int userId,
    List<Map<String, dynamic>> members,
  ) {
    for (final member in members) {
      if (member['memberId']?['userId'] == userId) {
        return member['status'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  String _displayName(int userId) {
    final user = _users[userId];
    if (user == null) return 'User $userId';
    final name = [user['firstName'], user['lastName']]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
    return name.isEmpty ? 'Deleted account' : name;
  }

  /// A short label for a member's role, or null for an ordinary member.
  String? _roleLabel(Map<String, dynamic>? status) =>
      switch (status?['@type']) {
        'ChatMemberStatusCreator' => 'owner',
        'ChatMemberStatusAdministrator' =>
          (status?['customTitle'] as String?)?.isNotEmpty == true
              ? status!['customTitle'] as String
              : 'admin',
        'ChatMemberStatusRestricted' => 'restricted',
        'ChatMemberStatusBanned' => 'banned',
        _ => null,
      };

  Future<void> _addMembers() async {
    final picked = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ContactsPage(selectable: true, title: 'Add members'),
      ),
    );
    if (picked == null || picked.isEmpty) return;

    await TDLibClient.addChatMembers(chatId: _chatId, userIds: picked);
    await _load();
  }

  Future<void> _openMemberActions(Map<String, dynamic> member) async {
    final userId = member['memberId']?['userId'] as int?;
    if (userId == null) return;
    final status = member['status'] as Map<String, dynamic>?;
    final isAdmin = status?['@type'] == 'ChatMemberStatusAdministrator';
    final isOwner = status?['@type'] == 'ChatMemberStatusCreator';

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: const Text('Send message'),
              onTap: () => Navigator.pop(sheetContext, 'message'),
            ),
            // The owner's status can't be changed by anyone, including an admin.
            if (_canManage && !isOwner) ...[
              ListTile(
                leading: Icon(
                  isAdmin ? Icons.remove_moderator : Icons.add_moderator,
                ),
                title: Text(isAdmin ? 'Dismiss admin' : 'Promote to admin'),
                onTap: () =>
                    Navigator.pop(sheetContext, isAdmin ? 'demote' : 'promote'),
              ),
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Remove from group',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'message':
        final chat = await TDLibClient.createPrivateChat(userId: userId);
        if (!mounted || chat == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
        );
      case 'promote':
        await TDLibClient.setChatMemberStatus(
          chatId: _chatId,
          userId: userId,
          status: TDLibClient.adminStatus(),
        );
        await _load();
      case 'demote':
        await TDLibClient.setChatMemberStatus(
          chatId: _chatId,
          userId: userId,
          status: TDLibClient.memberStatus(),
        );
        await _load();
      case 'remove':
        await TDLibClient.removeChatMember(chatId: _chatId, userId: userId);
        await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _addMembers,
              tooltip: 'Add members',
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _members,
            builder: (context, members, child) {
              if (members.isEmpty) {
                return const EmptyState(
                  icon: Icons.group_outlined,
                  title: 'No members to show',
                  subtitle:
                      'This chat does not expose its member list to you.',
                );
              }
              return ListView.separated(
                padding: withBottomSafeArea(
                  context,
                  // Room for the add-members button.
                  EdgeInsets.only(bottom: _canManage ? 80 : 0),
                ),
                itemCount: members.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 72,
                ),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final userId = member['memberId']?['userId'] as int?;
                  if (userId == null) return const SizedBox.shrink();

                  final name = _displayName(userId);
                  final role = _roleLabel(
                    member['status'] as Map<String, dynamic>?,
                  );
                  final user = _users[userId];

                  return ListTile(
                    leading: ChatAvatar(
                      chat: {
                        'id': userId,
                        'title': name,
                        'photo': user?['profilePhoto'],
                        'user': user,
                      },
                      radius: 22,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      user == null
                          ? ''
                          : MessageFormatter.getUserStatus(user),
                    ),
                    trailing: role == null
                        ? null
                        : Text(
                            role,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                          ),
                    onTap: () => _openMemberActions(member),
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
