import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/tdlib/send_options.dart';

void main() {
  group('SendOptions.toJson', () {
    test('is null for a plain send, so TDLib keeps its defaults', () {
      expect(SendOptions.normal.toJson(), isNull);
    });

    test('disables the notification for a silent send', () {
      final json = SendOptions.silentNow.toJson();

      expect(json?['@type'], 'messageSendOptions');
      expect(json?['disableNotification'], isTrue);
      expect(json?.containsKey('schedulingState'), isFalse);
    });

    test('schedules for an absolute time in whole seconds', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1750000000500);

      final json = SendOptions(sendAtDate: at).toJson();

      expect(json?['schedulingState'], {
        '@type': 'messageSchedulingStateSendAtDate',
        'sendDate': 1750000000,
      });
    });

    test('schedules for the recipient coming online', () {
      final json = SendOptions.whenOnline.toJson();

      expect(
        json?['schedulingState'],
        {'@type': 'messageSchedulingStateSendWhenOnline'},
      );
    });

    test('prefers an explicit date over waiting for them to come online', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1750000000000);

      final json = SendOptions(sendAtDate: at, sendWhenOnline: true).toJson();

      expect(
        json?['schedulingState']?['@type'],
        'messageSchedulingStateSendAtDate',
      );
    });

    test('reports whether the message goes to the scheduled list', () {
      expect(SendOptions.normal.isScheduled, isFalse);
      expect(SendOptions.silentNow.isScheduled, isFalse);
      expect(SendOptions.whenOnline.isScheduled, isTrue);
      expect(SendOptions(sendAtDate: DateTime.now()).isScheduled, isTrue);
    });
  });
}
