import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/l10n/app_localizations.dart';
import 'package:nullgram/services/notification_text.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Map<String, dynamic> push(Map<String, dynamic> content) => {
        '@type': 'NotificationTypeNewPushMessage',
        'senderName': 'Ann',
        'content': content,
      };

  group('notificationPreview', () {
    test('reads the text of a plain message', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentText', 'text': 'hello'}),
        l10n,
      );

      expect(text, 'hello');
    });

    test('names a photo with no caption', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentPhoto'}),
        l10n,
      );

      expect(text, l10n.notificationPhoto);
    });

    test('prefers the caption of a photo that has one', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentPhoto', 'caption': 'at the sea'}),
        l10n,
      );

      expect(text, 'at the sea');
    });

    test('puts the emoji in front of a sticker', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentSticker', 'emoji': 'X'}),
        l10n,
      );

      expect(text, l10n.notificationSticker('X'));
    });

    test('names the poll question', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentPoll', 'question': 'Tea?'}),
        l10n,
      );

      expect(text, l10n.notificationPoll('Tea?'));
    });

    test('falls back for a content type it does not know', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentInvoice'}),
        l10n,
      );

      expect(text, l10n.notificationMessage);
    });

    test('falls back when a push text is empty', () {
      final text = notificationPreview(
        push({'@type': 'PushMessageContentText', 'text': ''}),
        l10n,
      );

      expect(text, l10n.notificationMessage);
    });

    test('reads the text of a synced message', () {
      final text = notificationPreview(
        {
          '@type': 'NotificationTypeNewMessage',
          'message': {
            'content': {
              '@type': 'MessageText',
              'text': {'text': 'hi there'},
            },
          },
        },
        l10n,
      );

      expect(text, 'hi there');
    });

    test('falls back when a synced message summarises to empty', () {
      final text = notificationPreview(
        {
          '@type': 'NotificationTypeNewMessage',
          'message': {
            'content': {
              '@type': 'MessageText',
              'text': {'text': ''},
            },
          },
        },
        l10n,
      );

      expect(text, l10n.notificationMessage);
    });

    test('names a secret chat', () {
      final text = notificationPreview(
        {'@type': 'NotificationTypeNewSecretChat'},
        l10n,
      );

      expect(text, l10n.notificationSecretChat);
    });

    test('names an incoming call', () {
      final text = notificationPreview(
        {'@type': 'NotificationTypeNewCall'},
        l10n,
      );

      expect(text, l10n.notificationIncomingCall);
    });
  });

  group('notificationSender', () {
    test('reads the sender name a push carries', () {
      expect(
        notificationSender(push({'@type': 'PushMessageContentText'})),
        'Ann',
      );
    });

    test('has no sender for a secret chat notification', () {
      expect(
        notificationSender({'@type': 'NotificationTypeNewSecretChat'}),
        isNull,
      );
    });
  });
}
