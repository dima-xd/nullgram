import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/profile/edit_chat_page.dart';
import 'package:nullgram/pages/profile/group_members_page.dart';
import 'package:nullgram/pages/profile/shared_media_page.dart';
import 'package:nullgram/pages/profile/widgets/profile_header_sliver.dart';
import 'package:nullgram/pages/profile/widgets/profile_info_tile.dart';
import 'package:nullgram/services/call_service.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/utils/member_count.dart';

/// A profile screen for a chat: large avatar, title, quick actions and details
/// such as a user's bio and phone or a group's description and invite link.
class ChatProfilePage extends StatefulWidget {
  final Map<String, dynamic> chat;

  const ChatProfilePage({super.key, required this.chat});

  @override
  State<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends State<ChatProfilePage> {
  /// The resolved user object for private/secret chats, or null otherwise.
  final ValueNotifier<Map<String, dynamic>?> _user = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _userFullInfo =
      ValueNotifier(null);

  /// Extended info for a group or channel: description and invite link.
  final ValueNotifier<Map<String, dynamic>?> _groupFullInfo =
      ValueNotifier(null);

  final ValueNotifier<bool> _isMuted = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _isMuted.value = isChatMuted(widget.chat);

    final userId = _chatUserId();
    if (userId != null) {
      // A chat has no embedded user; resolve it (and its full info) from TDLib.
      TDLibClient.getUser(userId: userId).then((user) {
        if (mounted) _user.value = user;
      }).catchError((_) {});
      TDLibClient.getUserFullInfo(userId: userId).then((info) {
        if (mounted) _userFullInfo.value = info;
      }).catchError((_) {});
      return;
    }
    _loadGroupInfo();
  }

  @override
  void dispose() {
    _user.dispose();
    _userFullInfo.dispose();
    _groupFullInfo.dispose();
    _isMuted.dispose();
    super.dispose();
  }

  /// The user id behind a private/secret chat, read from the chat's type.
  int? _chatUserId() {
    final type = widget.chat['type'];
    final typeName = type?['@type'];
    if (typeName == 'ChatTypePrivate' || typeName == 'ChatTypeSecret') {
      return type['userId'] as int?;
    }
    return null;
  }

  Future<void> _loadGroupInfo() async {
    final type = widget.chat['type'];
    final info = switch (type?['@type']) {
      'ChatTypeBasicGroup' => await TDLibClient.getBasicGroupFullInfo(
          basicGroupId: type['basicGroupId'] as int,
        ),
      'ChatTypeSupergroup' => await TDLibClient.getSupergroupFullInfo(
          supergroupId: type['supergroupId'] as int,
        ),
      _ => null,
    };
    if (mounted) _groupFullInfo.value = info;
  }

  Future<void> _toggleMute() async {
    final muted = _isMuted.value;
    _isMuted.value = !muted;
    await TDLibClient.setChatNotificationSettings(
      chatId: widget.chat['id'] as int,
      muteFor: muted ? 0 : TDLibClient.muteForever,
    );
  }

  /// Whether TDLib says the signed-in user may rename this chat, which is
  /// the same right that gates the description and photo.
  bool _canEditChat() =>
      _chatUserId() == null &&
      widget.chat['permissions']?['canChangeInfo'] == true;

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditChatPage(
          chat: widget.chat,
          description:
              _groupFullInfo.value?['description'] as String? ?? '',
        ),
      ),
    );
    // The edit screen writes through TDLib, so re-read what came back.
    await _loadGroupInfo();
  }

  String? _subtitle(BuildContext context, Map<String, dynamic>? user) {
    if (user != null) return MessageFormatter.getUserStatus(user);

    final supergroup = widget.chat['supergroup'];
    if (supergroup != null) {
      final count = supergroup['memberCount'] as int? ?? 0;
      return memberCountLabel(
        context,
        count,
        isChannel: supergroup['isChannel'] == true,
      );
    }

    final members = _groupFullInfo.value?['members'] as List?;
    if (members == null) return null;
    return memberCountLabel(context, members.length, isChannel: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _user,
        builder: (context, user, child) {
          final phone = user?['phoneNumber'] as String?;
          final activeUsernames =
              user?['usernames']?['activeUsernames'] as List?;
          final username =
              (activeUsernames != null && activeUsernames.isNotEmpty)
                  ? activeUsernames.first as String?
                  : null;
          final title = widget.chat['title'] as String? ?? 'Chat';

          final chatWithUser =
              user == null ? widget.chat : {...widget.chat, 'user': user};

          final phoneValue = (phone != null && phone.isNotEmpty)
              ? (phone.startsWith('+') ? phone : '+$phone')
              : null;

          return CustomScrollView(
            slivers: [
              ProfileHeaderSliver(
                chat: chatWithUser,
                title: title,
                subtitle: _subtitle(context, user),
                actions: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isMuted,
                    builder: (context, muted, child) => IconButton(
                      icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                      tooltip: muted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMute,
                    ),
                  ),
                  if (_canEditChat())
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: context.l10n.edit,
                      onPressed: _openEdit,
                    ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null)
                    _QuickActions(userId: user['id'] as int),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.perm_media_outlined),
                            title: Text(context.l10n.sharedMedia),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SharedMediaPage(chat: widget.chat),
                              ),
                            ),
                          ),
                          if (user == null)
                            ListTile(
                              leading: const Icon(Icons.group_outlined),
                              title: Text(context.l10n.members),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GroupMembersPage(chat: widget.chat),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (phoneValue != null || username != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Card(
                        child: Column(
                          children: [
                            if (phoneValue != null)
                              ProfileInfoTile(
                                icon: Icons.phone_outlined,
                                label: context.l10n.phone,
                                value: phoneValue,
                                copyable: true,
                              ),
                            if (username != null && username.isNotEmpty)
                              ProfileInfoTile(
                                icon: Icons.alternate_email,
                                label: context.l10n.username,
                                value: '@$username',
                                copyable: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: _userFullInfo,
                    builder: (context, fullInfo, child) {
                      final bio = fullInfo?['bio']?['text'] as String?;
                      if (bio == null || bio.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Card(
                          child: ProfileInfoTile(
                            icon: Icons.info_outline,
                            label: context.l10n.bio,
                            value: bio,
                          ),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: _groupFullInfo,
                    builder: (context, info, child) => _GroupDetails(
                      info: info,
                      chatId: widget.chat['id'] as int,
                    ),
                  ),
                  SizedBox(
                    height: 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Call and secret-chat actions for a private chat.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.userId});

  final int userId;

  /// Opens an end-to-end encrypted chat with the same person.
  ///
  /// A secret chat is a separate chat from the ordinary one, so this pushes
  /// the new chat rather than changing the current screen.
  Future<void> _startSecretChat(BuildContext context) async {
    final chat = await TDLibClient.createNewSecretChat(userId: userId);
    if (!context.mounted) return;
    if (chat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.secretChatFailed)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final started = await callService.startCall(
                      userId: userId,
                      isVideo: false,
                    );
                    if (!context.mounted || started) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(context.l10n.microphonePermissionRequired),
                      ),
                    );
                  },
                  icon: const Icon(Icons.call),
                  label: Text(context.l10n.call),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final started = await callService.startCall(
                      userId: userId,
                      isVideo: true,
                    );
                    if (!context.mounted || started) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.cameraAccessDenied)),
                    );
                  },
                  icon: const Icon(Icons.videocam),
                  label: Text(context.l10n.video),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _startSecretChat(context),
              icon: const Icon(Icons.lock_outline),
              label: Text(context.l10n.startSecretChat),
            ),
          ),
        ],
      ),
    );
  }
}

/// A group's or channel's description and invite link.
class _GroupDetails extends StatelessWidget {
  const _GroupDetails({required this.info, required this.chatId});

  final Map<String, dynamic>? info;
  final int chatId;

  @override
  Widget build(BuildContext context) {
    final description = info?['description'] as String?;
    final inviteLink = info?['inviteLink']?['inviteLink'] as String?;

    if ((description == null || description.isEmpty) &&
        (inviteLink == null || inviteLink.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Column(
          children: [
            if (description != null && description.isNotEmpty)
              ProfileInfoTile(
                icon: Icons.info_outline,
                label: context.l10n.about,
                value: description,
              ),
            if (inviteLink != null && inviteLink.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(inviteLink),
                subtitle: Text(context.l10n.inviteLink),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: context.l10n.copyLink,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: inviteLink),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.inviteLinkCopied)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
