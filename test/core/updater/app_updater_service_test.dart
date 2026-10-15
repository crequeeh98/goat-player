import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/updater/app_updater_service.dart';

void main() {
  group('AppUpdaterService Version & Asset Matching', () {
    test('AppUpdateInfo holds correct properties', () {
      const info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.2.0',
        latestVersion: '1.2.1',
        releaseNotes: 'Bugfixes and features',
        downloadUrl: 'https://example.com/download.zip',
        fileName: 'GOATPlayer-Windows-x64.zip',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.currentVersion, '1.2.0');
      expect(info.latestVersion, '1.2.1');
      expect(info.fileName, 'GOATPlayer-Windows-x64.zip');
    });

    test('isNewer returns true when remote version is higher', () {
      expect(AppUpdaterService.isNewer('1.2.0', '1.2.1'), isTrue);
      expect(AppUpdaterService.isNewer('1.2.0', '1.3.0'), isTrue);
      expect(AppUpdaterService.isNewer('1.2.0', '2.0.0'), isTrue);
      expect(AppUpdaterService.isNewer('1.0.0', '1.2.0'), isTrue);
    });

    test('isNewer returns false when remote version is equal or lower', () {
      expect(AppUpdaterService.isNewer('1.2.0', '1.2.0'), isFalse);
      expect(AppUpdaterService.isNewer('1.2.1', '1.2.0'), isFalse);
      expect(AppUpdaterService.isNewer('2.0.0', '1.9.9'), isFalse);
    });

    test('isNewer handles build numbers gracefully', () {
      expect(AppUpdaterService.isNewer('1.2.0+1', '1.2.1'), isTrue);
      expect(AppUpdaterService.isNewer('1.2.0+5', '1.2.0+6'), isFalse);
    });
  });
}
