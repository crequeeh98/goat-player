import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/updater/app_updater_service.dart';

void main() {
  group('AppUpdaterService Version & Asset Matching', () {
    test('AppUpdateInfo holds correct properties', () {
      const info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.0.0',
        latestVersion: '1.2.0',
        releaseNotes: 'Bugfixes and features',
        downloadUrl: 'https://example.com/download.apk',
        fileName: 'GOATPlayer-universal.apk',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.currentVersion, '1.0.0');
      expect(info.latestVersion, '1.2.0');
      expect(info.fileName, 'GOATPlayer-universal.apk');
    });
  });
}
