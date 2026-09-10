import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/auto_download.dart';

void main() {
  group('AutoDownloadRules', () {
    test('reports the ceiling for each kind', () {
      const rules = AutoDownloadRules(
        maxPhotoBytes: 100,
        maxVideoBytes: 200,
        maxOtherBytes: 300,
      );

      expect(rules.limitFor(AutoDownloadKind.photo), 100);
      expect(rules.limitFor(AutoDownloadKind.video), 200);
      expect(rules.limitFor(AutoDownloadKind.other), 300);
    });

    test('copyWith leaves the untouched fields alone', () {
      const rules = AutoDownloadRules(maxPhotoBytes: 100);
      final updated = rules.copyWith(maxVideoBytes: 999);

      expect(updated.maxPhotoBytes, 100);
      expect(updated.maxVideoBytes, 999);
      expect(updated.isEnabled, isTrue);
    });

    test('maps onto the TDLib object field for field', () {
      const rules = AutoDownloadRules(
        isEnabled: false,
        maxPhotoBytes: 1,
        maxVideoBytes: 2,
        maxOtherBytes: 3,
      );

      expect(rules.toTdlib(), {
        '@type': 'autoDownloadSettings',
        'isAutoDownloadEnabled': false,
        'maxPhotoFileSize': 1,
        'maxVideoFileSize': 2,
        'maxOtherFileSize': 3,
        'videoUploadBitrate': 0,
        'preloadLargeVideos': false,
        'preloadNextAudio': false,
        'preloadStories': false,
        'useLessDataForCalls': false,
      });
    });

    test('the off preset disables everything', () {
      expect(AutoDownloadRules.off.isEnabled, isFalse);
    });
  });

  group('AutoDownloadNetwork', () {
    test('names the TDLib network types exactly', () {
      // A typo here would be silently ignored by the bridge, so the strings
      // are asserted rather than trusted.
      expect(AutoDownloadNetwork.mobile.tdlibType, 'networkTypeMobile');
      expect(AutoDownloadNetwork.wifi.tdlibType, 'networkTypeWiFi');
    });
  });

  group('shouldDownload', () {
    test('refuses a file of unknown size', () {
      // TDLib reports zero until it knows the size; treating that as "small"
      // would start surprise downloads on mobile data.
      expect(
        AutoDownloadService.instance.shouldDownload(
          AutoDownloadKind.photo,
          0,
        ),
        isFalse,
      );
    });
  });
}
