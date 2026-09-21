import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/notification_groups.dart';
import 'package:nullgram/services/notification_service.dart';

NotificationGroup _group(Map<String, dynamic> type) => NotificationGroup(
      accountId: 2,
      groupId: 7,
      chatId: -100,
      totalCount: 1,
      notifications: [
        NotificationEntry(id: 42, date: 1, isSilent: false, type: type),
      ],
    );

void main() {
  group('notification payloads', () {
    test('a new message group survives a round trip', () {
      final payload = encodePayload(_group({
        '@type': 'NotificationTypeNewMessage',
        'message': {'id': 555},
      }));

      expect(decodePayload(payload), (
        accountId: 2,
        chatId: -100,
        groupId: 7,
        maxNotificationId: 42,
        messageId: 555,
      ));
    });

    test('a push message carries its own message id', () {
      final payload = encodePayload(_group({
        '@type': 'NotificationTypeNewPushMessage',
        'messageId': 777,
      }));

      expect(decodePayload(payload)?.messageId, 777);
    });

    test('a type with no message id encodes zero', () {
      final payload =
          encodePayload(_group({'@type': 'NotificationTypeNewCall'}));

      expect(decodePayload(payload)?.messageId, 0);
    });

    test('the last notification of the group is the one encoded', () {
      final payload = encodePayload(NotificationGroup(
        accountId: 1,
        groupId: 3,
        chatId: 9,
        totalCount: 2,
        notifications: [
          NotificationEntry(
            id: 10,
            date: 1,
            isSilent: false,
            type: const {'message': {'id': 100}},
          ),
          NotificationEntry(
            id: 11,
            date: 2,
            isSilent: false,
            type: const {'message': {'id': 101}},
          ),
        ],
      ));

      expect(decodePayload(payload)?.maxNotificationId, 11);
      expect(decodePayload(payload)?.messageId, 101);
    });

    test('a missing payload decodes to nothing', () {
      expect(decodePayload(null), isNull);
      expect(decodePayload(''), isNull);
    });

    test('a payload of the wrong length decodes to nothing', () {
      expect(decodePayload('1:2:3:4'), isNull);
      expect(decodePayload('1:2:3:4:5:6'), isNull);
    });

    test('a payload with a part that is not a number decodes to nothing', () {
      expect(decodePayload('1:2:three:4:5'), isNull);
      expect(decodePayload('1:2:3:4:'), isNull);
    });
  });

  group('notification ids', () {
    test('one group of one account always answers the same id', () {
      expect(notificationId(2, 7), notificationId(2, 7));
    });

    test('another account or group answers another id', () {
      expect(notificationId(2, 7), isNot(notificationId(3, 7)));
      expect(notificationId(2, 7), isNot(notificationId(2, 8)));
    });

    test('the id is never negative, as Android requires', () {
      for (var account = 1; account < 20; account++) {
        for (var group = -5; group < 20; group++) {
          expect(notificationId(account, group), greaterThanOrEqualTo(0));
        }
      }
    });
  });
}
