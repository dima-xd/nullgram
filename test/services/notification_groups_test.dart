import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/notification_groups.dart';

Map<String, dynamic> _notification(int id, {int date = 100}) => {
  'id': id,
  'date': date,
  'isSilent': false,
  'type': {
    '@type': 'NotificationTypeNewPushMessage',
    'senderName': 'Ann',
    'content': {'@type': 'PushMessageContentText', 'text': 'hi'},
  },
};

void main() {
  group('NotificationGroups', () {
    test('an active notifications update seeds the groups of one account', () {
      final groups = NotificationGroups();

      final change = groups.apply({
        '@type': 'UpdateActiveNotifications',
        '@accountId': 1,
        'groups': [
          {
            'id': 7,
            'chatId': -100,
            'totalCount': 1,
            'notifications': [_notification(1)],
          },
        ],
      }, 1);

      expect(change.updated.single.groupId, 7);
      expect(change.updated.single.chatId, -100);
      expect(change.updated.single.notifications.single.id, 1);
      expect(change.removed, isEmpty);
    });

    test('a second active notifications update removes what it dropped', () {
      final groups = NotificationGroups();
      groups.apply({
        '@type': 'UpdateActiveNotifications',
        'groups': [
          {
            'id': 7,
            'chatId': -100,
            'totalCount': 1,
            'notifications': [_notification(1)],
          },
          {
            'id': 8,
            'chatId': -200,
            'totalCount': 1,
            'notifications': [_notification(2)],
          },
        ],
      }, 1);

      final change = groups.apply({
        '@type': 'UpdateActiveNotifications',
        'groups': [
          {
            'id': 8,
            'chatId': -200,
            'totalCount': 1,
            'notifications': [_notification(2)],
          },
        ],
      }, 1);

      expect(change.updated.single.groupId, 8);
      expect(change.removed.single.groupId, 7);
    });

    test('an active group with no notifications is stored as absent', () {
      final groups = NotificationGroups();

      final change = groups.apply({
        '@type': 'UpdateActiveNotifications',
        'groups': [
          {
            'id': 7,
            'chatId': -100,
            'totalCount': 0,
            'notifications': <Map<String, dynamic>>[],
          },
        ],
      }, 1);

      expect(change.updated, isEmpty);
      expect(change.removed, isEmpty);
      expect(groups.group(1, 7), isNull);
    });

    test('an active group emptied since the last snapshot is removed', () {
      final groups = NotificationGroups();
      groups.apply({
        '@type': 'UpdateActiveNotifications',
        'groups': [
          {
            'id': 7,
            'chatId': -100,
            'totalCount': 1,
            'notifications': [_notification(1)],
          },
        ],
      }, 1);

      final change = groups.apply({
        '@type': 'UpdateActiveNotifications',
        'groups': [
          {
            'id': 7,
            'chatId': -100,
            'totalCount': 0,
            'notifications': <Map<String, dynamic>>[],
          },
        ],
      }, 1);

      expect(change.updated, isEmpty);
      expect(change.removed.single, (accountId: 1, groupId: 7));
      expect(groups.group(1, 7), isNull);
    });

    test('a group update adds a notification and keeps date order', () {
      final groups = NotificationGroups();
      groups.apply({
        '@type': 'UpdateNotificationGroup',
        'notificationGroupId': 7,
        'chatId': -100,
        'totalCount': 1,
        'addedNotifications': [_notification(2, date: 200)],
        'removedNotificationIds': <int>[],
      }, 1);

      final change = groups.apply({
        '@type': 'UpdateNotificationGroup',
        'notificationGroupId': 7,
        'chatId': -100,
        'totalCount': 2,
        'addedNotifications': [_notification(1, date: 100)],
        'removedNotificationIds': <int>[],
      }, 1);

      expect(change.updated.single.notifications.map((n) => n.id).toList(), [
        1,
        2,
      ]);
    });

    test('removing the last notification removes the group', () {
      final groups = NotificationGroups();
      groups.apply({
        '@type': 'UpdateNotificationGroup',
        'notificationGroupId': 7,
        'chatId': -100,
        'totalCount': 1,
        'addedNotifications': [_notification(1)],
        'removedNotificationIds': <int>[],
      }, 1);

      final change = groups.apply({
        '@type': 'UpdateNotificationGroup',
        'notificationGroupId': 7,
        'chatId': -100,
        'totalCount': 0,
        'addedNotifications': <Map<String, dynamic>>[],
        'removedNotificationIds': [1],
      }, 1);

      expect(change.updated, isEmpty);
      expect(change.removed.single.groupId, 7);
      expect(groups.group(1, 7), isNull);
    });

    test('two accounts with the same group id stay apart', () {
      final groups = NotificationGroups();
      final update = {
        '@type': 'UpdateNotificationGroup',
        'notificationGroupId': 7,
        'chatId': -100,
        'totalCount': 1,
        'addedNotifications': [_notification(1)],
        'removedNotificationIds': <int>[],
      };

      groups.apply(update, 1);
      groups.apply(update, 2);

      expect(groups.group(1, 7), isNotNull);
      expect(groups.group(2, 7), isNotNull);
      expect(groups.groups.length, 2);
    });

    test('an unrelated update changes nothing', () {
      final groups = NotificationGroups();

      final change = groups.apply({'@type': 'UpdateNewMessage'}, 1);

      expect(change.updated, isEmpty);
      expect(change.removed, isEmpty);
    });

    test('clearAccount drops only that account and returns its groups', () {
      final groups = NotificationGroups();
      groups.apply(
        {
          '@type': 'UpdateActiveNotifications',
          'groups': [
            {
              'id': 7,
              'chatId': -100,
              'totalCount': 1,
              'notifications': [_notification(1)],
            },
            {
              'id': 8,
              'chatId': -200,
              'totalCount': 1,
              'notifications': [_notification(2)],
            },
          ],
        },
        1,
      );
      groups.apply(
        {
          '@type': 'UpdateActiveNotifications',
          'groups': [
            {
              'id': 9,
              'chatId': -300,
              'totalCount': 1,
              'notifications': [_notification(3)],
            },
          ],
        },
        2,
      );

      final removed = groups.clearAccount(1);

      expect(
        removed.map((r) => r.groupId).toSet(),
        {7, 8},
      );
      expect(groups.group(1, 7), isNull);
      expect(groups.group(1, 8), isNull);
      expect(groups.group(2, 9), isNotNull);
      expect(groups.groups.single.groupId, 9);
    });
  });
}
