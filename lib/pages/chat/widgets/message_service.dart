import 'package:flutter/material.dart';

/// Returns the system-event text for a service message, or `null` if [content]
/// is a normal message that should be rendered as a bubble.
///
/// Service messages (group created, title changed, member joined, call, …) are
/// shown by Telegram as a centered grey line rather than a chat bubble.
String? serviceMessageText(Map<String, dynamic> content) {
  final type = content['@type'] as String?;
  switch (type) {
    case 'MessageBasicGroupChatCreate':
    case 'MessageSupergroupChatCreate':
      final title = content['title'] as String?;
      return title == null || title.isEmpty
          ? 'Chat created'
          : 'Chat «$title» created';
    case 'MessageChatChangeTitle':
      final title = content['title'] as String? ?? '';
      return 'Chat name changed to «$title»';
    case 'MessageChatChangePhoto':
      return 'Chat photo changed';
    case 'MessageChatDeletePhoto':
      return 'Chat photo removed';
    case 'MessageChatAddMembers':
      final count = (content['memberUserIds'] as List?)?.length ?? 0;
      return count > 1 ? '$count members joined' : 'A member joined';
    case 'MessageChatJoinByLink':
      return 'Joined the chat via invite link';
    case 'MessageChatJoinByRequest':
      return 'Joined the chat';
    case 'MessageChatDeleteMember':
      return 'A member left the chat';
    case 'MessageChatUpgradeTo':
    case 'MessageChatUpgradeFrom':
      return 'Chat was upgraded to a supergroup';
    case 'MessagePinMessage':
      return 'Pinned a message';
    case 'MessageScreenshotTaken':
      return 'A screenshot was taken';
    case 'MessageChatSetTheme':
      return 'Chat theme changed';
    case 'MessageChatSetBackground':
      return 'Chat background changed';
    case 'MessageChatSetMessageAutoDeleteTime':
      final seconds = (content['messageAutoDeleteTime'] as num?)?.toInt() ?? 0;
      return seconds == 0
          ? 'Auto-delete timer disabled'
          : 'Auto-delete timer set to ${_formatDuration(seconds)}';
    case 'MessageContactRegistered':
      return 'Joined Telegram';
    case 'MessageChatBoost':
      return 'Boosted the chat';
    case 'MessageCall':
      final isVideo = content['isVideo'] == true;
      final duration = (content['duration'] as num?)?.toInt() ?? 0;
      final kind = isVideo ? 'Video call' : 'Call';
      return duration > 0 ? '$kind · ${_formatDuration(duration)}' : kind;
    case 'MessageGroupCall':
    case 'MessageVideoChatStarted':
      return 'Voice chat started';
    case 'MessageVideoChatEnded':
      return 'Voice chat ended';
    case 'MessageVideoChatScheduled':
      return 'Voice chat scheduled';
    case 'MessageInviteVideoChatParticipants':
      return 'Invited participants to the voice chat';
    case 'MessageForumTopicCreated':
      return 'Topic created';
    case 'MessageForumTopicEdited':
      return 'Topic edited';
    case 'MessageForumTopicIsClosedToggled':
      return 'Topic open/closed state changed';
    case 'MessageForumTopicIsHiddenToggled':
      return 'Topic hidden state changed';
    case 'MessageGiftedPremium':
      return 'Gifted Telegram Premium';
    case 'MessagePremiumGiftCode':
      return 'Sent a Premium gift code';
    case 'MessageGiftedStars':
      return 'Gifted Telegram Stars';
    case 'MessageGiftedTon':
      return 'Gifted TON';
    case 'MessageGift':
    case 'MessageUpgradedGift':
      return 'Sent a gift';
    case 'MessageGiveawayCreated':
    case 'MessageGiveaway':
    case 'MessageGiveawayWinners':
    case 'MessageGiveawayCompleted':
      return 'Giveaway';
    case 'MessagePaymentSuccessful':
    case 'MessagePaymentSuccessfulBot':
      return 'Payment completed';
    case 'MessagePaymentRefunded':
      return 'Payment refunded';
    case 'MessageBotWriteAccessAllowed':
      return 'Allowed the bot to message you';
    case 'MessageProximityAlertTriggered':
      return 'Proximity alert';
    case 'MessageCustomServiceAction':
      return content['text'] as String? ?? 'Service action';
    case 'MessageExpiredPhoto':
      return 'Photo has expired';
    case 'MessageExpiredVideo':
      return 'Video has expired';
    case 'MessageExpiredVideoNote':
      return 'Video message has expired';
    case 'MessageExpiredVoiceNote':
      return 'Voice message has expired';
    default:
      return null;
  }
}

/// A human-readable label for a content type that has no dedicated renderer,
/// so the bubble shows something descriptive instead of a blank space.
String unsupportedLabel(Map<String, dynamic> content) {
  switch (content['@type']) {
    case 'MessageVideoNote':
      return '📹 Video message';
    case 'MessageGame':
      return '🎮 Game';
    case 'MessageStory':
      return '📖 Story';
    case 'MessageInvoice':
      return '🧾 Invoice';
    case 'MessagePaidMedia':
      return '🔒 Paid media';
    case 'MessageChecklist':
      return '☑️ Checklist';
    default:
      return 'Unsupported message';
  }
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${(seconds / 60).round()}m';
  if (seconds < 86400) return '${(seconds / 3600).round()}h';
  return '${(seconds / 86400).round()}d';
}

/// A centered, muted system line for a service message.
class ServiceMessage extends StatelessWidget {
  final String text;

  const ServiceMessage({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
