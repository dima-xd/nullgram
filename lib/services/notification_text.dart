import 'package:nullgram/l10n/app_localizations.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';

/// One line of preview for a `notificationType*` object: a synced message's
/// `message`, or a push's smaller `PushMessageContent`.
String notificationPreview(
  Map<String, dynamic> type,
  AppLocalizations l10n,
) {
  switch (type['@type']) {
    case 'NotificationTypeNewMessage':
      final message = (type['message'] as Map?)?.cast<String, dynamic>();
      final preview = messagePreviewText(message);
      return preview.isEmpty ? l10n.notificationMessage : preview;
    case 'NotificationTypeNewPushMessage':
      final content = (type['content'] as Map?)?.cast<String, dynamic>();
      return content == null
          ? l10n.notificationMessage
          : _pushPreview(content, l10n);
    case 'NotificationTypeNewSecretChat':
      return l10n.notificationSecretChat;
    case 'NotificationTypeNewCall':
      return l10n.notificationIncomingCall;
    default:
      return l10n.notificationMessage;
  }
}

/// The display name of whoever sent the notification, when it names one.
String? notificationSender(Map<String, dynamic> type) {
  if (type['@type'] != 'NotificationTypeNewPushMessage') return null;
  final name = type['senderName'] as String?;
  return name == null || name.isEmpty ? null : name;
}

String _pushPreview(Map<String, dynamic> content, AppLocalizations l10n) {
  // A caption says more than the media type does, so it wins wherever
  // TDLib provides one.
  final caption = content['caption'] as String?;
  if (caption != null && caption.isNotEmpty) return caption;

  return switch (content['@type']) {
    'PushMessageContentText' => _textOrFallback(
        content['text'] as String?,
        l10n,
      ),
    'PushMessageContentPhoto' => l10n.notificationPhoto,
    'PushMessageContentVideo' => l10n.notificationVideo,
    'PushMessageContentAnimation' => l10n.notificationAnimation,
    'PushMessageContentAudio' => l10n.notificationAudio,
    'PushMessageContentDocument' => l10n.notificationDocument,
    'PushMessageContentVoiceNote' => l10n.notificationVoiceNote,
    'PushMessageContentVideoNote' => l10n.notificationVideoNote,
    'PushMessageContentSticker' =>
      l10n.notificationSticker(content['emoji'] as String? ?? ''),
    'PushMessageContentContact' => l10n.notificationContact,
    'PushMessageContentLocation' => l10n.notificationLocation,
    'PushMessageContentPoll' =>
      l10n.notificationPoll(content['question'] as String? ?? ''),
    'PushMessageContentMediaAlbum' => l10n.notificationAlbum,
    _ => l10n.notificationMessage,
  };
}

String _textOrFallback(String? text, AppLocalizations l10n) =>
    text == null || text.isEmpty ? l10n.notificationMessage : text;
