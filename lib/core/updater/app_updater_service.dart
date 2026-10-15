import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String fileName;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
  });
}

class AppUpdaterService {
  static const String _repoOwner = 'crequeeh98';
  static const String _repoName = 'goat-player';
  static const MethodChannel _androidChannel = MethodChannel('com.goatplayer/updater');

  final Dio _dio;

  AppUpdaterService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 15),
                headers: {'Accept': 'application/vnd.github.v3+json'},
              ),
            );

  /// Checks if a newer version is available on GitHub Releases.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').trim();
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = data['body'] as String? ?? '';
      final assets = (data['assets'] as List<dynamic>? ?? []);

      if (!_isNewer(currentVersion, latestVersion)) {
        return null;
      }

      final targetAsset = await _selectAsset(assets);
      if (targetAsset == null) {
        return null;
      }

      final downloadUrl = targetAsset['browser_download_url'] as String? ?? '';
      final fileName = targetAsset['name'] as String? ?? '';

      return AppUpdateInfo(
        hasUpdate: true,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('[AppUpdaterService] Check failed: $e');
      return null;
    }
  }

  /// Downloads the update package with progress reporting.
  Future<String> downloadUpdate({
    required String downloadUrl,
    required String fileName,
    required void Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
    final targetFile = File(savePath);

    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

    return savePath;
  }

  /// Installs the downloaded update file.
  Future<void> installUpdate(String filePath) async {
    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod('installApk', {'filePath': filePath});
    } else if (Platform.isWindows) {
      await _installWindowsUpdate(filePath);
    }
  }

  Future<void> _installWindowsUpdate(String zipPath) async {
    final currentExe = Platform.resolvedExecutable;
    final targetDir = File(currentExe).parent.path;
    final tempDir = await getTemporaryDirectory();
    final scriptPath = '${tempDir.path}${Platform.pathSeparator}update_runner.ps1';

    final scriptContent = '''
param(\$AppPid, \$TargetDir, \$ZipPath)
Wait-Process -Id \$AppPid -Timeout 15 -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
Expand-Archive -Path \$ZipPath -DestinationPath \$TargetDir -Force
Remove-Item -Path \$ZipPath -Force -ErrorAction SilentlyContinue
Start-Process -FilePath "\$TargetDir\\goat_player.exe"
''';

    await File(scriptPath).writeAsString(scriptContent);

    await Process.start(
      'powershell.exe',
      [
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        pid.toString(),
        targetDir,
        zipPath,
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  Future<Map<String, dynamic>?> _selectAsset(List<dynamic> assets) async {
    if (Platform.isAndroid) {
      List<String> abis = [];
      try {
        final res = await _androidChannel.invokeMethod<List<dynamic>>('getSupportedAbis');
        abis = res?.map((e) => e.toString()).toList() ?? [];
      } catch (_) {}

      if (abis.contains('arm64-v8a')) {
        final arm64 = _findAsset(assets, 'GOATPlayer-arm64-v8a.apk');
        if (arm64 != null) return arm64;
      }

      if (abis.contains('armeabi-v7a')) {
        final armeabi = _findAsset(assets, 'GOATPlayer-armeabi-v7a.apk');
        if (armeabi != null) return armeabi;
      }

      final universal = _findAsset(assets, 'GOATPlayer-universal.apk');
      if (universal != null) return universal;

      // Fallback: any .apk asset
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) return a as Map<String, dynamic>;
      }
    } else if (Platform.isWindows) {
      final winZip = _findAsset(assets, 'GOATPlayer-Windows-x64.zip');
      if (winZip != null) return winZip;

      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.zip') && name.contains('win')) return a as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findAsset(List<dynamic> assets, String exactName) {
    for (final a in assets) {
      if (a is Map<String, dynamic> && a['name'] == exactName) {
        return a;
      }
    }
    return null;
  }

  bool _isNewer(String current, String latest) {
    try {
      final cParts = current.split('+').first.split('.').map(int.parse).toList();
      final lParts = latest.split('+').first.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }
}
