import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/services/account_manager.dart';

/// The accounts that are signed in but not on screen, plus "Add account".
///
/// Shown inside the drawer header once it is expanded. The account on screen is
/// deliberately absent: it is the header itself, and repeating it would invite
/// a switch to the account already being used.
class AccountSwitcherList extends StatelessWidget {
  /// Creates the switcher list.
  const AccountSwitcherList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountManager.instance,
      builder: (context, _) {
        final manager = AccountManager.instance;
        return Column(
          children: [
            for (final account in manager.accounts)
              if (account.id != manager.activeId)
                _AccountTile(account: account),
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: Text(context.l10n.addAccount),
              onTap: () => _addAccount(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    // The drawer is closed first: adding an account lands on the login screen,
    // and leaving the drawer open over it would cover the phone field.
    Navigator.pop(context);
    await AccountManager.instance.addAccount();
  }
}

/// One switchable account: tap to bring it on screen, long-press to sign out.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final unread = AccountManager.instance.unreadOf(account.id);

    return ListTile(
      leading: ChatAvatar(chat: _avatarChat(), radius: 20),
      title: Text(
        account.name.isEmpty ? account.phoneNumber : account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: account.phoneNumber.isEmpty || account.name.isEmpty
          ? null
          : Text('+${account.phoneNumber}'),
      trailing: unread == 0
          ? null
          : Semantics(
              label: context.l10n.accountUnreadMessages(unread),
              child: Badge(label: Text('$unread')),
            ),
      onTap: () {
        Navigator.pop(context);
        AccountManager.instance.switchTo(account.id);
      },
      onLongPress: () => _confirmLogOut(context),
    );
  }

  /// The chat-shaped map [ChatAvatar] reads.
  ///
  /// The photo comes from the account's own client and its file is looked up on
  /// disk, never downloaded: TDLib file ids belong to the client that issued
  /// them, so an account that has never been on screen falls back to an initial.
  Map<String, dynamic> _avatarChat() {
    final profile = AccountManager.instance.profileOf(account.id);
    return {
      'id': account.userId,
      'title': account.name.isEmpty ? account.phoneNumber : account.name,
      'photo': profile?['profilePhoto'],
    };
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    final name = account.name.isEmpty ? account.phoneNumber : account.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.logOutAccountQuestion(name)),
        content: Text(dialogContext.l10n.logOutWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.logOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AccountManager.instance.removeAccount(account.id);
  }
}
