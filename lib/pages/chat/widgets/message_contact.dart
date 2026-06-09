import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat_page.dart';

/// Renders a `MessageContact` as a tappable card with initials, name and phone.
///
/// Tapping opens a private chat with the contact when their user id is known,
/// otherwise it launches the dialer with the contact's phone number.
class MessageContact extends StatelessWidget {
  final Map<String, dynamic> content;

  const MessageContact({super.key, required this.content});

  Map<String, dynamic>? get _contact =>
      content['contact'] as Map<String, dynamic>?;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contact = _contact;
    if (contact == null) return const SizedBox.shrink();

    final firstName = contact['firstName'] as String? ?? '';
    final lastName = contact['lastName'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final phone = contact['phoneNumber'] as String? ?? '';
    final displayName = name.isEmpty ? phone : name;

    return InkWell(
      onTap: () => _open(context, contact),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.primary,
              child: Text(
                _initials(firstName, lastName, phone),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (name.isNotEmpty && phone.isNotEmpty)
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String firstName, String lastName, String phone) {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final initials = '$first$last'.toUpperCase();
    if (initials.isNotEmpty) return initials;
    return phone.isNotEmpty ? '#' : '?';
  }

  Future<void> _open(
    BuildContext context,
    Map<String, dynamic> contact,
  ) async {
    final userId = (contact['userId'] as num?)?.toInt() ?? 0;
    if (userId != 0) {
      final chat = await TDLibClient.createPrivateChat(userId: userId);
      if (!context.mounted || chat == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
      );
      return;
    }
    final phone = contact['phoneNumber'] as String? ?? '';
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
