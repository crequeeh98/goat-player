import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/settings/locale_controller.dart';
import '../../core/utils/epg_isolate_parser.dart';

final currentProgramsMapProvider = StreamProvider.autoDispose<Map<String, EpgProgram>>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  return ref.watch(epgDaoProvider).watchCurrentPrograms(account.id);
});

final epgControllerProvider = Provider<EpgController>((ref) {
  return EpgController(ref);
});

class EpgController {
  final Ref _ref;
  bool _isSyncing = false;
  final Map<String, DateTime> _shortEpgFetchedAt = {};
  final Set<String> _shortEpgInFlight = {};

  EpgController(this._ref);

  void clearShortEpgCache() {
    _shortEpgFetchedAt.clear();
  }

  /// Punkt 7: Entfernt abgelaufene EPG-Sendungen (älter als 24 Stunden) beim App-Start.
  Future<void> pruneOldEpg() async {
    try {
      final dao = _ref.read(epgDaoProvider);
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final deleted = await dao.pruneExpiredEpg(cutoff);
      if (deleted > 0) {
        debugPrint('Pruned $deleted expired EPG programs older than 24h.');
      }
    } catch (e) {
      debugPrint('Failed to prune old EPG: $e');
    }
  }

  /// Punkt 1: Lädt für Flutter TV (Fire TV / Android TV) on-demand die nächsten ~10 Sendungen
  /// eines Kanals über get_short_epg (TTL: 15 Minuten pro Kanal).
  Future<void> ensureShortEpg({
    required String streamId,
    String? epgChannelId,
    bool force = false,
  }) async {
    final account = _ref.read(activeAccountProvider);
    final client = _ref.read(xtreamClientProvider);
    if (account == null || client == null) return;
    if (account.username.isEmpty || account.serverUrl.contains('.m3u')) return;

    final cacheKey = '${account.id}_$streamId';
    if (_shortEpgInFlight.contains(cacheKey)) return;

    final now = DateTime.now();
    final lastFetched = _shortEpgFetchedAt[cacheKey];
    if (!force && lastFetched != null && now.difference(lastFetched) < const Duration(minutes: 15)) {
      return;
    }

    _shortEpgInFlight.add(cacheKey);
    try {
      final listings = await client.getShortEpg(streamId, limit: 10);
      _shortEpgFetchedAt[cacheKey] = DateTime.now();
      if (listings.isEmpty) return;

      final targetChannelId = (epgChannelId != null && epgChannelId.trim().isNotEmpty)
          ? epgChannelId.trim()
          : streamId;

      final companions = <EpgProgramsCompanion>[];
      for (final item in listings) {
        if (item is! Map) continue;
        final start = _parseShortEpgTime(item['start_timestamp'], item['start']);
        final stop = _parseShortEpgTime(item['stop_timestamp'], item['end'] ?? item['stop']);
        if (start == null || stop == null) continue;

        final title = _decodeBase64OrPlain(item['title']?.toString());
        if (title.isEmpty) continue;
        final desc = _decodeBase64OrPlain(item['description']?.toString());

        companions.add(
          EpgProgramsCompanion.insert(
            accountId: account.id,
            channelId: targetChannelId,
            title: title,
            description: desc.isNotEmpty ? Value(desc) : const Value.absent(),
            startTime: start,
            stopTime: stop,
          ),
        );
      }

      if (companions.isNotEmpty) {
        final dao = _ref.read(epgDaoProvider);
        await dao.replaceProgramsForChannel(account.id, targetChannelId, companions);
      }
    } catch (e) {
      debugPrint('Short EPG error for stream $streamId: $e');
    } finally {
      _shortEpgInFlight.remove(cacheKey);
    }
  }

  static String _decodeBase64OrPlain(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final isBase64 = trimmed.length % 4 == 0 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(trimmed);
    if (!isBase64) return trimmed;
    try {
      final bytes = base64.decode(trimmed);
      return utf8.decode(bytes, allowMalformed: true).trim();
    } catch (_) {
      return trimmed;
    }
  }

  static DateTime? _parseShortEpgTime(dynamic timestampVal, dynamic strVal) {
    if (strVal != null) {
      final s = strVal.toString().trim();
      if (s.isNotEmpty) {
        final parsed = DateTime.tryParse(s) ?? DateTime.tryParse(s.replaceFirst(' ', 'T'));
        if (parsed != null) return parsed;
      }
    }
    if (timestampVal != null) {
      final sec = int.tryParse(timestampVal.toString().trim());
      if (sec != null && sec > 0) {
        return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
      }
    }
    return null;
  }

  /// Punkt 4: Streamt große XMLTV-Dateien direkt in eine temporäre Datei und parst sie
  /// Chunk-für-Chunk im Hintergrund-Isolate (verhindert 150+ MB String-Spikes im Haupt-Heap).
  Future<void> syncEpgData({bool force = false, bool rethrowOnError = false}) async {
    if (_isSyncing) return;

    final account = _ref.read(activeAccountProvider);
    final client = _ref.read(xtreamClientProvider);
    if (account == null || client == null) return;
    if (account.username.isEmpty || account.serverUrl.contains('.m3u')) return;

    final prefs = _ref.read(sharedPreferencesProvider);
    final dao = _ref.read(epgDaoProvider);

    final lastSyncKey = 'last_sync_epg_${account.id}';
    final lastSyncMs = prefs.getInt(lastSyncKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hasFreshCache = (nowMs - lastSyncMs) < const Duration(hours: 6).inMilliseconds;

    if (!force && hasFreshCache) {
      final existingCount = await dao.countProgramsForAccount(account.id);
      if (existingCount > 0) {
        debugPrint('EPG cache is fresh ($existingCount programs). Skipping XMLTV download.');
        return;
      }
    }

    _isSyncing = true;
    final tempFile = File('${Directory.systemTemp.path}/goat_epg_${account.id}.xml');
    try {
      final xmltvUrl = client.getXmltvUrl();
      debugPrint('Streaming XMLTV EPG to temp file from: $xmltvUrl');

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 5),
      ));

      await dio.download(xmltvUrl, tempFile.path);

      if (await tempFile.exists()) {
        final filePath = tempFile.path;
        final accId = account.id;
        final programs = await Isolate.run(() => EpgIsolateParser.parseXmlTvFile(filePath, accId));
        debugPrint('Parsed ${programs.length} active/upcoming EPG programs. Saving to DB...');

        await dao.clearOldEpg(account.id);
        await dao.insertEpgPrograms(programs);
        await prefs.setInt(lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('EPG Sync Complete!');
      }
    } catch (e) {
      debugPrint('Failed to sync EPG data: $e');
      if (rethrowOnError) rethrow;
    } finally {
      _isSyncing = false;
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }
}
