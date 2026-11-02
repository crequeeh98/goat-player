import 'dart:convert';
import 'dart:io';
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
        downloadUrl: 'https://github.com/crequeeh98/goat-player/releases/download/v1.2.1/GOATPlayer-Windows-x64.zip',
        fileName: 'GOATPlayer-Windows-x64.zip',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.currentVersion, '1.2.0');
      expect(info.latestVersion, '1.2.1');
      expect(info.fileName, 'GOATPlayer-Windows-x64.zip');
      expect(info.expectedSha256, isNull);
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

    test('isNewer handles build numbers and v prefixes gracefully', () {
      expect(AppUpdaterService.isNewer('1.2.0+1', '1.2.1'), isTrue);
      expect(AppUpdaterService.isNewer('v1.2.1', 'v1.2.2'), isTrue);
      expect(AppUpdaterService.isNewer('1.2.2', 'v1.2.2'), isFalse);
      expect(AppUpdaterService.isNewer('1.2.0+5', '1.2.0+6'), isFalse);
    });
  });

  group('AppUpdaterService Security & Integrity Verification', () {
    test('SHA-256 matches official NIST FIPS 180-4 test vectors', () async {
      expect(
        AppUpdaterService.computeBytesSha256(const <int>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        AppUpdaterService.computeBytesSha256(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        AppUpdaterService.computeBytesSha256(
          utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );

      final tmpDir = await Directory.systemTemp.createTemp('goat_sha_test_');
      try {
        final file = File('${tmpDir.path}/million_a.bin');
        await file.writeAsBytes(List<int>.filled(1000000, 0x61));
        expect(
          await AppUpdaterService.computeFileSha256(file),
          'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
        );
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('isAllowedUpdateUrl enforces HTTPS and GitHub domains only', () {
      expect(
        AppUpdaterService.isAllowedUpdateUrl(
          'https://github.com/crequeeh98/goat-player/releases/download/v2.0.2/GOATPlayer-Windows-x64.zip',
        ),
        isTrue,
      );
      expect(
        AppUpdaterService.isAllowedUpdateUrl(
          'https://objects.githubusercontent.com/github-production-release-asset/asset.apk',
        ),
        isTrue,
      );
      expect(
        AppUpdaterService.isAllowedUpdateUrl('http://github.com/crequeeh98/goat-player/asset.zip'),
        isFalse,
      );
      expect(
        AppUpdaterService.isAllowedUpdateUrl('https://evil-github.com/asset.zip'),
        isFalse,
      );
      expect(
        AppUpdaterService.isAllowedUpdateUrl('https://attacker.example/GOATPlayer.apk'),
        isFalse,
      );
    });

    test('sanitizeAssetFileName blocks path traversal and non-package extensions', () {
      expect(AppUpdaterService.sanitizeAssetFileName('GOATPlayer-Windows-x64.zip'), 'GOATPlayer-Windows-x64.zip');
      expect(AppUpdaterService.sanitizeAssetFileName('GOATPlayer-arm64-v8a.apk'), 'GOATPlayer-arm64-v8a.apk');
      expect(AppUpdaterService.sanitizeAssetFileName('../GOATPlayer.zip'), isNull);
      expect(AppUpdaterService.sanitizeAssetFileName('..\\GOATPlayer.zip'), isNull);
      expect(AppUpdaterService.sanitizeAssetFileName('payload.exe'), isNull);
      expect(AppUpdaterService.sanitizeAssetFileName('.hidden.apk'), isNull);
    });

    test('extractSha256Digest parses GitHub asset digest and SHA256SUMS formats with graceful legacy fallback', () {
      const hex = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
      expect(
        AppUpdaterService.extractSha256Digest(
          <String, dynamic>{'digest': 'sha256:${hex.toUpperCase()}'},
          fileName: 'GOATPlayer-Windows-x64.zip',
        ),
        hex,
      );
      expect(
        AppUpdaterService.extractSha256Digest(
          const <String, dynamic>{},
          fileName: 'GOATPlayer-Windows-x64.zip',
          releaseBody: 'Checksums:\n$hex  GOATPlayer-Windows-x64.zip\n',
        ),
        hex,
      );
      expect(
        AppUpdaterService.extractSha256Digest(
          const <String, dynamic>{},
          fileName: 'GOATPlayer-Windows-x64.zip',
          releaseBody: 'Legacy release without hash',
        ),
        isNull,
      );
    });
  });
}
