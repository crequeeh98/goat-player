import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String fileName;
  final String? expectedSha256;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
    this.expectedSha256,
  });
}

const String kBundledReleaseNotes = '''
### 🇩🇪 Änderungen & Neuerungen (v2.1.4)
- **Performance & Storage**:
  - *Smart TV*: Batch-Rendering & schnelleres Sortieren für große Listen, IndexedDB-SWR-Cache, manuelles Sync-Modal und schlanke Listen-Snapshots.
  - *Flutter*: SQLite-FTS5-Suche, seitenweise Kategorie-Abfragen, inkrementelle Delta-Syncs und 10-Minuten-Kategorie-Cooldown.
- **EPG, Playlists & Auth**:
  - Live-EPG mit Minuten-Ticker (`noch XX min`), Android-TV-Viewport-EPG, sofortiges Ablaufdatum (`expDate`) und direkte Auth-/Verbindungsprüfung bei Add/Edit & Portal-Upload.
- **Smart TV OTA v2**:
  - Volle In-App-Updates für HTML, CSS, neue JS-Module & Assets via `IndexedDB` mit Delta-Skip, Dual-Slot-Rollback und `v2.1.4`-Badge unten links.

### 🇬🇧 Changes & Improvements (v2.1.4)
- **Performance & Storage**:
  - *Smart TV*: Batched rendering & faster sorting for large lists, IndexedDB SWR cache, manual sync modal, and slim list snapshots.
  - *Flutter*: SQLite FTS5 search, paged category queries, incremental delta syncs, and 10-minute category cooldown.
- **EPG, Playlists & Auth**:
  - Live EPG minute ticker (`XX min left`), Android TV viewport short-EPG, instant `expDate` badge, and device-side auth validation on account add/edit & portal sync.
- **Smart TV OTA v2**:
  - Full in-app updates for HTML, CSS, new JS modules & assets via `IndexedDB` with delta skipping, dual-slot rollback, and bottom-left `v2.1.4` badge.
''';

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
      String currentVersion = packageInfo.version;

      if (Platform.isWindows) {
        // Read version from app manifest or package_version.txt if packaged
        try {
          final exeDir = File(Platform.resolvedExecutable).parent;
          final versionFile = File('${exeDir.path}${Platform.pathSeparator}version.txt');
          if (versionFile.existsSync()) {
            final fileVer = versionFile.readAsStringSync().trim();
            if (fileVer.isNotEmpty && (currentVersion.isEmpty || currentVersion == '0.0.0' || isNewer(currentVersion, fileVer))) {
              currentVersion = fileVer;
            }
          } else if (packageInfo.version.isNotEmpty && packageInfo.version != '0.0.0') {
            currentVersion = packageInfo.version;
          }
        } catch (_) {}
      }

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

      if (!isNewer(currentVersion, latestVersion)) {
        return null;
      }

      final targetAsset = await _selectAsset(assets);
      if (targetAsset == null) {
        return null;
      }

      final downloadUrl = targetAsset['browser_download_url'] as String? ?? '';
      final rawFileName = targetAsset['name'] as String? ?? '';
      final safeFileName = sanitizeAssetFileName(rawFileName);
      if (safeFileName == null || !isAllowedUpdateUrl(downloadUrl)) {
        debugPrint('[AppUpdaterService] Rejected unsafe asset URL or filename.');
        return null;
      }

      String? expectedSha256 = extractSha256Digest(
        targetAsset,
        fileName: safeFileName,
        releaseBody: releaseNotes,
      );

      expectedSha256 ??= await _fetchManifestSha256(assets, safeFileName);

      return AppUpdateInfo(
        hasUpdate: true,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        fileName: safeFileName,
        expectedSha256: expectedSha256,
      );
    } catch (e) {
      debugPrint('[AppUpdaterService] Check failed: $e');
      return null;
    }
  }

  /// Fetches release notes for the active [currentVer] from GitHub tags,
  /// with automatic fallback to [kBundledReleaseNotes] if offline or unreleased.
  Future<String> getCurrentVersionChangelog(String currentVer) async {
    final cleanVer = currentVer.split('+').first;
    if (cleanVer == '2.1.1' || cleanVer == '2.1.2' || cleanVer == '2.1.3' || cleanVer == '2.1.4') {
      return kBundledReleaseNotes;
    }
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/tags/v$cleanVer',
      );
      if (response.statusCode == 200 && response.data != null) {
        final body = response.data['body'] as String? ?? '';
        if (body.trim().isNotEmpty) return body;
      }
    } catch (_) {}
    return kBundledReleaseNotes;
  }

  Future<String?> _fetchManifestSha256(List<dynamic> assets, String targetFileName) async {
    const manifestNames = <String>{'sha256sums', 'sha256sums.txt', 'checksums.txt'};
    Map<String, dynamic>? manifestAsset;
    final perFileAssetName = '$targetFileName.sha256'.toLowerCase();

    for (final a in assets) {
      if (a is! Map<String, dynamic>) continue;
      final name = (a['name'] as String? ?? '').trim().toLowerCase();
      if (name == perFileAssetName || manifestNames.contains(name)) {
        manifestAsset = a;
        if (name == perFileAssetName) break;
      }
    }

    if (manifestAsset == null) return null;
    final url = manifestAsset['browser_download_url'] as String? ?? '';
    final size = manifestAsset['size'] as int? ?? 0;
    if (!isAllowedUpdateUrl(url) || size > 65536) return null;

    try {
      final res = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (res.statusCode == 200 && res.data != null) {
        return parseSha256FromText(res.data!, targetFileName, allowStandaloneHex: (manifestAsset['name'] as String? ?? '').toLowerCase() == perFileAssetName);
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the update package with progress reporting and SHA-256 verification.
  Future<String> downloadUpdate({
    required String downloadUrl,
    required String fileName,
    required void Function(double progress) onProgress,
    String? expectedSha256,
  }) async {
    if (!isAllowedUpdateUrl(downloadUrl)) {
      throw ArgumentError('Untrusted update download URL rejected.');
    }
    final safeFileName = sanitizeAssetFileName(fileName);
    if (safeFileName == null) {
      throw ArgumentError('Invalid update asset filename rejected.');
    }

    final tempDir = await getTemporaryDirectory();
    final savePath = p.join(tempDir.path, safeFileName);
    final targetFile = File(savePath);

    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }

    await _dio.download(
      downloadUrl,
      savePath,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

    if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
      final actualSha256 = await computeFileSha256(targetFile);
      if (actualSha256.toLowerCase() != expectedSha256.trim().toLowerCase()) {
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
        throw StateError('Update integrity check failed (SHA-256 mismatch).');
      }
    }

    return savePath;
  }

  /// Installs the downloaded update file.
  Future<void> installUpdate(String filePath, [String? newVersion]) async {
    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod('installApk', {'filePath': filePath});
    } else if (Platform.isWindows) {
      await _installWindowsUpdate(filePath, newVersion);
    }
  }

  Future<void> _installWindowsUpdate(String zipPath, [String? newVersion]) async {
    final zipFile = File(zipPath);
    if (!zipFile.existsSync() || !zipPath.toLowerCase().endsWith('.zip')) {
      throw ArgumentError('Invalid Windows update archive path.');
    }

    final currentExe = Platform.resolvedExecutable;
    final targetDir = File(currentExe).parent.path;
    final tempDir = await getTemporaryDirectory();
    final scriptPath = p.join(tempDir.path, 'update_runner.ps1');

    final rawVer = (newVersion ?? '').trim();
    final versionArg = RegExp(r'^[0-9A-Za-z.+_-]{0,40}$').hasMatch(rawVer) ? rawVer : '';

    final scriptContent = '''
param(\$AppPid, \$TargetDir, \$ZipPath, \$NewVersion)

\$LogFile = Join-Path \$env:TEMP "goat_updater.log"
"[" + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + "] Updater started. PID=\$AppPid, TargetDir=\$TargetDir, NewVersion=\$NewVersion" | Out-File \$LogFile -Encoding utf8

if (\$AppPid) {
    Wait-Process -Id \$AppPid -Timeout 15 -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 2

\$StageDir = Join-Path \$env:TEMP ("goat_stage_" + [guid]::NewGuid().ToString("N"))
\$deployed = \$false

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    New-Item -ItemType Directory -Path \$StageDir -Force | Out-Null
    \$StageFull = [System.IO.Path]::GetFullPath(\$StageDir)
    if (-not \$StageFull.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        \$StageFull += [System.IO.Path]::DirectorySeparatorChar
    }

    \$ExistingExe = Join-Path \$TargetDir "goat_player.exe"
    \$RequireValidSig = \$false
    \$ExpectedThumb = ""
    if (Test-Path \$ExistingExe) {
        try {
            \$CurSig = Get-AuthenticodeSignature -FilePath \$ExistingExe
            if (\$CurSig -and \$CurSig.Status -eq "Valid" -and \$CurSig.SignerCertificate) {
                \$RequireValidSig = \$true
                \$ExpectedThumb = \$CurSig.SignerCertificate.Thumbprint
            }
        } catch {}
    }

    \$Zip = [System.IO.Compression.ZipFile]::OpenRead(\$ZipPath)
    try {
        foreach (\$Entry in \$Zip.Entries) {
            \$DestPath = [System.IO.Path]::GetFullPath((Join-Path \$StageFull \$Entry.FullName))
            if (-not \$DestPath.StartsWith(\$StageFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Zip Slip path traversal blocked: \$(\$Entry.FullName)"
            }
            if ([string]::IsNullOrEmpty(\$Entry.Name)) {
                New-Item -ItemType Directory -Path \$DestPath -Force | Out-Null
            } else {
                \$ParentDir = [System.IO.Path]::GetDirectoryName(\$DestPath)
                if (\$ParentDir -and -not (Test-Path \$ParentDir)) {
                    New-Item -ItemType Directory -Path \$ParentDir -Force | Out-Null
                }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile(\$Entry, \$DestPath, \$true)
            }
        }
    } finally {
        \$Zip.Dispose()
    }

    \$StagedExe = Join-Path \$StageFull "goat_player.exe"
    if (-not (Test-Path \$StagedExe)) {
        throw "Update archive missing goat_player.exe"
    }

    if (\$RequireValidSig) {
        \$NewSig = Get-AuthenticodeSignature -FilePath \$StagedExe
        if (-not \$NewSig -or \$NewSig.Status -ne "Valid" -or \$NewSig.SignerCertificate.Thumbprint -ne \$ExpectedThumb) {
            throw "Authenticode signature verification failed on staged executable."
        }
    }

    for (\$i = 1; \$i -le 6; \$i++) {
        try {
            "Attempt \$i : Copying staged files to \$TargetDir" | Out-File \$LogFile -Append -Encoding utf8
            Copy-Item -Path (Join-Path \$StageFull "*") -Destination \$TargetDir -Recurse -Force -ErrorAction Stop
            \$deployed = \$true
            "Deployment successful!" | Out-File \$LogFile -Append -Encoding utf8
            break
        } catch {
            "Attempt \$i failed: \$_" | Out-File \$LogFile -Append -Encoding utf8
            Start-Sleep -Seconds 1
        }
    }
} catch {
    "FATAL: Staging/verification failed: \$_" | Out-File \$LogFile -Append -Encoding utf8
} finally {
    if (Test-Path \$StageDir) {
        Remove-Item -Path \$StageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (\$deployed) {
    Remove-Item -Path \$ZipPath -Force -ErrorAction SilentlyContinue
    if (\$NewVersion) {
        try {
            Set-Content -Path (Join-Path \$TargetDir "version.txt") -Value \$NewVersion -Encoding utf8
            "Updated version.txt to \$NewVersion" | Out-File \$LogFile -Append -Encoding utf8
        } catch {
            "Failed to write version.txt: \$_" | Out-File \$LogFile -Append -Encoding utf8
        }
    }
    \$exe = Join-Path \$TargetDir "goat_player.exe"
    "Relaunching \$exe..." | Out-File \$LogFile -Append -Encoding utf8
    try {
        Start-Process -FilePath \$exe -WorkingDirectory \$TargetDir
        "Start-Process succeeded." | Out-File \$LogFile -Append -Encoding utf8
    } catch {
        "Start-Process error: \$_ - launching via explorer..." | Out-File \$LogFile -Append -Encoding utf8
        & explorer.exe "\$exe"
    }
} else {
    "FATAL: Update aborted without modifying application." | Out-File \$LogFile -Append -Encoding utf8
}
''';

    await File(scriptPath).writeAsString(scriptContent);

    await Process.start(
      'cmd.exe',
      [
        '/c',
        'start',
        '/b',
        'powershell.exe',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        pid.toString(),
        targetDir,
        zipPath,
        versionArg,
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

  static bool isAllowedUpdateUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'github.com' ||
        host == 'api.github.com' ||
        host.endsWith('.githubusercontent.com');
  }

  static String? sanitizeAssetFileName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty || trimmed.contains('/') || trimmed.contains('\\')) {
      return null;
    }
    final base = p.basename(trimmed);
    if (base != trimmed || base.startsWith('.')) return null;
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(base)) return null;
    final lower = base.toLowerCase();
    if (!lower.endsWith('.apk') && !lower.endsWith('.zip')) return null;
    return base;
  }

  static String? extractSha256Digest(
    Map<String, dynamic> targetAsset, {
    required String fileName,
    String? releaseBody,
  }) {
    final rawDigest = (targetAsset['digest'] as String? ?? '').trim();
    final digestMatch = RegExp(r'^sha256:([a-fA-F0-9]{64})$').firstMatch(rawDigest);
    if (digestMatch != null) {
      return digestMatch.group(1)!.toLowerCase();
    }
    if (releaseBody != null && releaseBody.isNotEmpty) {
      return parseSha256FromText(releaseBody, fileName);
    }
    return null;
  }

  static String? parseSha256FromText(
    String text,
    String targetFileName, {
    bool allowStandaloneHex = false,
  }) {
    final escapedName = RegExp.escape(targetFileName);
    final linePattern = RegExp(
      '([a-fA-F0-9]{64})\\s+\\*?$escapedName(?![A-Za-z0-9._-])',
      caseSensitive: false,
    );
    final m1 = linePattern.firstMatch(text);
    if (m1 != null) return m1.group(1)!.toLowerCase();

    final reversePattern = RegExp(
      '$escapedName[`"\\s:=]+([a-fA-F0-9]{64})(?![a-fA-F0-9])',
      caseSensitive: false,
    );
    final m2 = reversePattern.firstMatch(text);
    if (m2 != null) return m2.group(1)!.toLowerCase();

    if (allowStandaloneHex) {
      final onlyHex = RegExp(r'^\s*([a-fA-F0-9]{64})\s*$').firstMatch(text);
      if (onlyHex != null) return onlyHex.group(1)!.toLowerCase();
    }
    return null;
  }

  static String computeBytesSha256(List<int> bytes) {
    final sink = _Sha256Sink()..add(bytes);
    return sink.closeHex();
  }

  static Future<String> computeFileSha256(File file) async {
    final sink = _Sha256Sink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    return sink.closeHex();
  }

  static bool isNewer(String current, String latest) {
    try {
      final cleanCurrent = current.trim().startsWith('v') ? current.trim().substring(1) : current.trim();
      final cleanLatest = latest.trim().startsWith('v') ? latest.trim().substring(1) : latest.trim();
      final cParts = cleanCurrent.split('+').first.split('.').map(int.parse).toList();
      final lParts = cleanLatest.split('+').first.split('.').map(int.parse).toList();

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

class _Sha256Sink {
  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  int _h0 = 0x6a09e667;
  int _h1 = 0xbb67ae85;
  int _h2 = 0x3c6ef372;
  int _h3 = 0xa54ff53a;
  int _h4 = 0x510e527f;
  int _h5 = 0x9b05688c;
  int _h6 = 0x1f83d9ab;
  int _h7 = 0x5be0cd19;

  final Uint8List _buf = Uint8List(64);
  final Uint32List _w = Uint32List(64);
  int _bufLen = 0;
  int _totalBytes = 0;

  static int _rotr(int x, int n) => ((x >>> n) | ((x << (32 - n)) & 0xffffffff)) & 0xffffffff;

  void add(List<int> data) {
    int offset = 0;
    final int len = data.length;
    _totalBytes += len;

    if (_bufLen > 0 && _bufLen + len >= 64) {
      final int take = 64 - _bufLen;
      for (int i = 0; i < take; i++) {
        _buf[_bufLen + i] = data[i] & 0xff;
      }
      _processBlock(_buf, 0);
      _bufLen = 0;
      offset = take;
    }

    while (offset + 64 <= len) {
      _processBlock(data, offset);
      offset += 64;
    }

    while (offset < len) {
      _buf[_bufLen++] = data[offset++] & 0xff;
    }
  }

  void _processBlock(List<int> block, int offset) {
    for (int i = 0; i < 16; i++) {
      final int j = offset + (i * 4);
      _w[i] = ((block[j] & 0xff) << 24) |
          ((block[j + 1] & 0xff) << 16) |
          ((block[j + 2] & 0xff) << 8) |
          (block[j + 3] & 0xff);
    }
    for (int i = 16; i < 64; i++) {
      final int w15 = _w[i - 15];
      final int s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >>> 3);
      final int w2 = _w[i - 2];
      final int s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >>> 10);
      _w[i] = (_w[i - 16] + s0 + _w[i - 7] + s1) & 0xffffffff;
    }

    int a = _h0, b = _h1, c = _h2, d = _h3, e = _h4, f = _h5, g = _h6, h = _h7;

    for (int i = 0; i < 64; i++) {
      final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final int ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final int temp1 = (h + s1 + ch + _k[i] + _w[i]) & 0xffffffff;
      final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final int maj = (a & b) ^ (a & c) ^ (b & c);
      final int temp2 = (s0 + maj) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    _h0 = (_h0 + a) & 0xffffffff;
    _h1 = (_h1 + b) & 0xffffffff;
    _h2 = (_h2 + c) & 0xffffffff;
    _h3 = (_h3 + d) & 0xffffffff;
    _h4 = (_h4 + e) & 0xffffffff;
    _h5 = (_h5 + f) & 0xffffffff;
    _h6 = (_h6 + g) & 0xffffffff;
    _h7 = (_h7 + h) & 0xffffffff;
  }

  String closeHex() {
    final int bitLenHi = (_totalBytes >>> 29) & 0xffffffff;
    final int bitLenLo = (_totalBytes << 3) & 0xffffffff;

    _buf[_bufLen++] = 0x80;
    if (_bufLen > 56) {
      while (_bufLen < 64) {
        _buf[_bufLen++] = 0;
      }
      _processBlock(_buf, 0);
      _bufLen = 0;
    }
    while (_bufLen < 56) {
      _buf[_bufLen++] = 0;
    }
    _buf[56] = (bitLenHi >>> 24) & 0xff;
    _buf[57] = (bitLenHi >>> 16) & 0xff;
    _buf[58] = (bitLenHi >>> 8) & 0xff;
    _buf[59] = bitLenHi & 0xff;
    _buf[60] = (bitLenLo >>> 24) & 0xff;
    _buf[61] = (bitLenLo >>> 16) & 0xff;
    _buf[62] = (bitLenLo >>> 8) & 0xff;
    _buf[63] = bitLenLo & 0xff;
    _processBlock(_buf, 0);

    final words = <int>[_h0, _h1, _h2, _h3, _h4, _h5, _h6, _h7];
    final sb = StringBuffer();
    for (final w in words) {
      sb.write(w.toRadixString(16).padLeft(8, '0'));
    }
    return sb.toString();
  }
}
