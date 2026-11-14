import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../database/daos/account_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/stream_dao.dart';
import '../database/daos/epg_dao.dart';
import '../network/xtream_client.dart';
import 'zero_knowledge_crypto.dart';

enum RemoteSyncEventType { accountAdded, accountUpdated, accountDeleted, error }

class RemoteSyncEvent {
  final RemoteSyncEventType type;
  final Account? account;
  final int? accountId;
  final String message;

  const RemoteSyncEvent({
    required this.type,
    this.account,
    this.accountId,
    required this.message,
  });
}

class PairingSession {
  final String deviceId;
  final String pin;
  final DateTime expiresAt;
  final String qrUrl;

  const PairingSession({
    required this.deviceId,
    required this.pin,
    required this.expiresAt,
    required this.qrUrl,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class RemoteSyncService {
  static const String supabaseUrl = 'https://ejxepyztbcxcuxbgjwsh.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqeGVweXp0YmN4Y3V4Ymdqd3NoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MzcwNTcsImV4cCI6MjEwNDExMzA1N30.DGTV-_uwmmo4CN7CBZuqR1rqkh121GF2BqgNEvGj2LA';

  static const String defaultPortalUrl = 'https://goat-player.vercel.app';
  static const String _deviceIdPrefKey = 'remote_device_id';

  final AccountDao _accountDao;
  final CategoryDao _categoryDao;
  final StreamDao _streamDao;
  final EpgDao _epgDao;
  final SharedPreferences _prefs;
  String? _activeSessionPin;

  RemoteSyncService(
    this._accountDao,
    this._categoryDao,
    this._streamDao,
    this._epgDao,
    this._prefs,
  );

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint('Supabase initialized successfully for Remote Sync.');
    } catch (e) {
      debugPrint('Supabase initialization warning (app will run offline): $e');
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Retrieves or generates a persistent, friendly Device ID (e.g. 'GP-8429-B712')
  String getDeviceId() {
    var deviceId = _prefs.getString(_deviceIdPrefKey);
    if (deviceId == null || deviceId.isEmpty) {
      final random = Random();
      final part1 = (1000 + random.nextInt(9000)).toString();
      final part2 = List.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[random.nextInt(32)]).join();
      deviceId = 'GP-$part1-$part2';
      _prefs.setString(_deviceIdPrefKey, deviceId);
    }
    return deviceId;
  }

  String _normalizeUrl(String url) {
    var u = url.trim().toLowerCase();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  bool get _isGermanLocale =>
      (_prefs.getString('app_locale') ?? 'de') == 'de';

  /// Validates connectivity and auth/M3U format without downloading categories or streams.
  Future<({String serverUrl, String username, String password, int? expDate, int? maxConnections, bool isTrial})>
      _validateAccountConnection({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    var effectiveServer = serverUrl.trim();
    var effectiveUser = username.trim();
    var effectivePass = password.trim();

    if (effectiveUser.isEmpty || effectivePass.isEmpty) {
      final parsedXtream = XtreamClient.tryParseXtreamFromM3uUrl(effectiveServer);
      if (parsedXtream != null) {
        effectiveServer = parsedXtream.serverUrl;
        effectiveUser = parsedXtream.username;
        effectivePass = parsedXtream.password;
      }
    }

    final isM3u = effectiveUser.isEmpty && effectivePass.isEmpty;
    if (isM3u) {
      final uri = Uri.tryParse(effectiveServer);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw const FormatException('Invalid URL');
      }
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ));
      final resp = await dio.get<String>(effectiveServer);
      final body = resp.data ?? '';
      if (!body.contains('#EXTM3U') && !body.contains('#EXTINF')) {
        throw Exception('Invalid M3U playlist format');
      }
      return (
        serverUrl: effectiveServer,
        username: '',
        password: '',
        expDate: null,
        maxConnections: null,
        isTrial: false,
      );
    }

    final client = XtreamClient(
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
      )),
      baseUrl: effectiveServer,
      username: effectiveUser,
      password: effectivePass,
    );
    final authData = await client.authenticate();
    final userInfo = authData['user_info'];
    final isAuthOk = userInfo is Map && (userInfo['auth'] == 1 || userInfo['auth'] == '1');
    if (!isAuthOk) {
      throw Exception('Authentication failed: invalid credentials or inactive account');
    }
    final meta = AccountDao.parseXtreamUserInfo(userInfo);
    return (
      serverUrl: effectiveServer,
      username: effectiveUser,
      password: effectivePass,
      expDate: meta.expDate,
      maxConnections: meta.maxConnections,
      isTrial: meta.isTrial,
    );
  }

  Future<void> _clearSyncActionAndEmitError(
    String deviceId,
    String actionId,
    StreamController<RemoteSyncEvent> controller,
    Object error, {
    required bool isM3u,
  }) async {
    final friendlyMessage = XtreamClient.formatUserFriendlyError(
      error,
      isDe: _isGermanLocale,
      isM3u: isM3u,
    );
    try {
      await _client.from('remote_devices').update({
        'sync_action': {
          'action': 'error',
          'action_id': actionId,
          'error_message': friendlyMessage,
          'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        'status': 'connected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('device_id', deviceId);
    } catch (_) {}

    if (!controller.isClosed) {
      controller.add(RemoteSyncEvent(
        type: RemoteSyncEventType.error,
        message: friendlyMessage,
      ));
    }
  }

  /// Removes any existing duplicate accounts that have identical serverUrl and username
  Future<void> deduplicateLocalAccounts() async {
    try {
      final accounts = await _accountDao.getAllAccounts();
      final seenKeys = <String>{};
      for (final acc in accounts) {
        final key = '${_normalizeUrl(acc.serverUrl)}::${acc.username.trim().toLowerCase()}';
        if (seenKeys.contains(key)) {
          debugPrint('Deduplicating local account duplicate: ${acc.id} (${acc.serverUrl})');
          await _accountDao.deleteAccount(acc);
          await _categoryDao.clearCategories(acc.id, 'live');
          await _categoryDao.clearCategories(acc.id, 'movie');
          await _streamDao.clearAllStreams(acc.id);
          await _epgDao.clearPrograms(acc.id);
        } else {
          seenKeys.add(key);
        }
      }
    } catch (e) {
      debugPrint('Error deduplicating accounts: $e');
    }
  }

  /// Formats all local accounts into JSON to sync with Supabase (zero-knowledge: no passwords or URLs uploaded)
  Future<List<Map<String, dynamic>>> getLocalPlaylistsJson() async {
    final localAccounts = await _accountDao.getAllAccounts();
    return localAccounts.map((a) => {
      'id': a.id,
      'playlist_name': (a.playlistName != null && a.playlistName!.trim().isNotEmpty) ? a.playlistName!.trim() : 'IPTV Playlist',
      'type': (a.serverUrl.toLowerCase().contains('.m3u') || (a.username.trim().isEmpty && a.password.trim().isEmpty)) ? 'm3u' : 'xtream',
    }).toList();
  }

  /// Pushes current local playlists to Supabase so the web portal stays up to date
  Future<void> pushLocalPlaylists(String deviceId) async {
    try {
      final playlistsJson = await getLocalPlaylistsJson();
      await _client.from('remote_devices').update({
        'playlists': playlistsJson,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('device_id', deviceId);
    } catch (e) {
      debugPrint('Note: could not update playlists in remote_devices: $e');
    }
  }

  /// Closes the pairing session in Supabase so the web portal immediately detects disconnection
  Future<void> closePairingSession(String deviceId) async {
    _activeSessionPin = null;
    try {
      await _client.from('remote_devices').update({
        'status': 'disconnected',
        'pin_expires_at': DateTime.now().toUtc().toIso8601String(),
        'sync_action': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('device_id', deviceId);
      debugPrint('Pairing session closed for device $deviceId');
    } catch (e) {
      debugPrint('Error closing pairing session in Supabase: $e');
    }
  }

  /// Creates a new pairing session with a random 6-digit PIN valid for 20 minutes
  /// and syncs current device playlists to Supabase.
  Future<PairingSession> startPairingSession() async {
    // Automatically purge any previous local duplicate accounts
    await deduplicateLocalAccounts();

    final deviceId = getDeviceId();
    final random = Random();
    final pin = (100000 + random.nextInt(900000)).toString();
    _activeSessionPin = pin;
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 20));

    final qrUrl = '$defaultPortalUrl?device=$deviceId&pin=$pin';

    try {
      final playlistsJson = await getLocalPlaylistsJson();
      await _client.from('remote_devices').upsert({
        'device_id': deviceId,
        'pin': pin,
        'pin_expires_at': expiresAt.toIso8601String(),
        'status': 'pending',
        'playlists': playlistsJson,
        'sync_action': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('Pairing session created for $deviceId with PIN $pin and ${playlistsJson.length} playlists');
    } catch (e) {
      debugPrint('Fallback pairing upsert (without playlists/sync_action columns): $e');
      try {
        await _client.from('remote_devices').upsert({
          'device_id': deviceId,
          'pin': pin,
          'pin_expires_at': expiresAt.toIso8601String(),
          'status': 'pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (err) {
        debugPrint('Error creating pairing session in Supabase: $err');
        rethrow;
      }
    }

    return PairingSession(
      deviceId: deviceId,
      pin: pin,
      expiresAt: expiresAt.toLocal(),
      qrUrl: qrUrl,
    );
  }

  /// Subscribes to Realtime updates and manages Add, Edit, Delete actions.
  Stream<RemoteSyncEvent> listenForRemoteEvents(String deviceId) {
    late final StreamController<RemoteSyncEvent> controller;
    StreamSubscription<List<Map<String, dynamic>>>? sub;
    Timer? fallbackPollTimer;
    bool isProcessing = false;
    final Set<String> processedActionKeys = {};
    String? lastProcessedLegacyKey;

    void processRecord(Map<String, dynamic> record) async {
      if (isProcessing) return;
      isProcessing = true;

      try {
        final rawSyncAction = record['sync_action'];
        if (rawSyncAction != null && rawSyncAction is Map) {
          final Map<String, dynamic> syncAction;
          if (rawSyncAction['encrypted'] == true && _activeSessionPin != null) {
            syncAction = ZeroKnowledgePairingCrypto.decryptSyncAction(
              Map<String, dynamic>.from(rawSyncAction),
              _activeSessionPin!,
              deviceId,
            );
          } else {
            syncAction = Map<String, dynamic>.from(rawSyncAction);
          }

          final action = syncAction['action']?.toString();
          if (action == 'error') {
            return;
          }
          final actionTimestamp = syncAction['timestamp']?.toString() ?? '';
          final actionId = syncAction['action_id']?.toString() ?? '${action}_$actionTimestamp';

          if (actionId.isNotEmpty && processedActionKeys.contains(actionId)) {
            debugPrint('Sync action already processed, skipping: $actionId');
            return;
          }
          if (actionId.isNotEmpty) {
            processedActionKeys.add(actionId);
          }

          if (action == 'add') {
            var serverUrl = syncAction['server_url']?.toString().trim() ?? '';
            var username = syncAction['username']?.toString().trim() ?? '';
            var password = syncAction['password']?.toString().trim() ?? '';
            final playlistName = syncAction['playlist_name']?.toString();
            final actionIsM3u = syncAction['type']?.toString() == 'm3u' ||
                (username.isEmpty && password.isEmpty);

            if (serverUrl.isNotEmpty) {
              late final ({String serverUrl, String username, String password, int? expDate, int? maxConnections, bool isTrial}) validated;
              try {
                validated = await _validateAccountConnection(
                  serverUrl: serverUrl,
                  username: username,
                  password: password,
                );
                serverUrl = validated.serverUrl;
                username = validated.username;
                password = validated.password;
              } catch (e) {
                await _clearSyncActionAndEmitError(
                  deviceId,
                  actionId,
                  controller,
                  e,
                  isM3u: actionIsM3u && XtreamClient.tryParseXtreamFromM3uUrl(serverUrl) == null,
                );
                return;
              }

              // Deduplication: check if account with same server and username already exists
              final existingAccounts = await _accountDao.getAllAccounts();
              final existing = existingAccounts.where((a) =>
                _normalizeUrl(a.serverUrl) == _normalizeUrl(serverUrl) &&
                a.username.trim().toLowerCase() == username.toLowerCase()
              ).firstOrNull;

              Account? accountResult;
              int accountId;

              if (existing != null) {
                // Update existing account instead of duplicating
                accountId = existing.id;
                final credentialsChanged = serverUrl != existing.serverUrl ||
                    username != existing.username ||
                    password != existing.password;
                final updated = existing.copyWith(
                  playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : existing.playlistName),
                  serverUrl: serverUrl,
                  username: username,
                  password: password,
                  expDate: drift.Value(validated.expDate ?? existing.expDate),
                  maxConnections: drift.Value(validated.maxConnections ?? existing.maxConnections),
                  isTrial: validated.isTrial,
                );
                await _accountDao.updateAccount(updated);
                if (credentialsChanged) {
                  await _categoryDao.clearCategories(accountId, 'live');
                  await _categoryDao.clearCategories(accountId, 'movie');
                  await _categoryDao.clearCategories(accountId, 'series');
                  await _streamDao.clearAllStreams(accountId);
                  await _epgDao.clearPrograms(accountId);
                  await _prefs.remove('last_sync_categories_live_$accountId');
                  await _prefs.remove('last_sync_all_live_$accountId');
                  await _prefs.remove('last_sync_categories_vod_$accountId');
                  await _prefs.remove('last_sync_all_vod_$accountId');
                  await _prefs.remove('last_sync_categories_series_$accountId');
                  await _prefs.remove('last_sync_all_series_$accountId');
                  await _prefs.remove('last_sync_epg_$accountId');
                }
                accountResult = updated;
              } else {
                accountId = await _accountDao.insertAccount(
                  AccountsCompanion.insert(
                    playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null),
                    serverUrl: serverUrl,
                    username: username,
                    password: password,
                    expDate: drift.Value(validated.expDate),
                    maxConnections: drift.Value(validated.maxConnections),
                    isTrial: drift.Value(validated.isTrial),
                  ),
                );
                accountResult = await _accountDao.getAccountById(accountId);
              }

              // ATOMIC UPDATE: sync playlists, clear action, and keep status connected
              final playlistsJson = await getLocalPlaylistsJson();
              try {
                await _client.from('remote_devices').update({
                  'playlists': playlistsJson,
                  'sync_action': null,
                  'status': 'connected',
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                }).eq('device_id', deviceId);
              } catch (_) {}

              if (!controller.isClosed) {
                controller.add(RemoteSyncEvent(
                  type: existing != null ? RemoteSyncEventType.accountUpdated : RemoteSyncEventType.accountAdded,
                  account: accountResult,
                  accountId: accountId,
                  message: existing != null
                      ? 'Playlist updated: ${accountResult?.playlistName ?? username}'
                      : 'Playlist added: ${accountResult?.playlistName ?? username}',
                ));
              }
            }
          } else if (action == 'edit') {
            final rawId = syncAction['id'];
            final accountId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

            if (accountId != null) {
              final existing = await _accountDao.getAccountById(accountId);
              if (existing != null) {
                final playlistNameRaw = syncAction['playlist_name']?.toString().trim();
                final serverUrlRaw = syncAction['server_url']?.toString().trim();
                final usernameRaw = syncAction['username']?.toString().trim();
                final passwordRaw = syncAction['password']?.toString().trim();

                final playlistName = (playlistNameRaw != null && playlistNameRaw.isNotEmpty)
                    ? playlistNameRaw
                    : existing.playlistName;
                var serverUrl = (serverUrlRaw != null && serverUrlRaw.isNotEmpty)
                    ? serverUrlRaw
                    : existing.serverUrl;
                var username = (usernameRaw != null && usernameRaw.isNotEmpty)
                    ? usernameRaw
                    : existing.username;
                var password = (passwordRaw != null && passwordRaw.isNotEmpty)
                    ? passwordRaw
                    : existing.password;

                final credentialsChanged = serverUrl != existing.serverUrl ||
                    username != existing.username ||
                    password != existing.password;

                ({String serverUrl, String username, String password, int? expDate, int? maxConnections, bool isTrial})? validated;
                if (credentialsChanged) {
                  final editIsM3u = syncAction['type']?.toString() == 'm3u' ||
                      (username.isEmpty && password.isEmpty);
                  try {
                    validated = await _validateAccountConnection(
                      serverUrl: serverUrl,
                      username: username,
                      password: password,
                    );
                    serverUrl = validated.serverUrl;
                    username = validated.username;
                    password = validated.password;
                  } catch (e) {
                    await _clearSyncActionAndEmitError(
                      deviceId,
                      actionId,
                      controller,
                      e,
                      isM3u: editIsM3u && XtreamClient.tryParseXtreamFromM3uUrl(serverUrl) == null,
                    );
                    return;
                  }
                }

                final updated = existing.copyWith(
                  playlistName: drift.Value(playlistName),
                  serverUrl: serverUrl,
                  username: username,
                  password: password,
                  expDate: drift.Value(validated != null ? validated.expDate : existing.expDate),
                  maxConnections: drift.Value(validated != null ? validated.maxConnections : existing.maxConnections),
                  isTrial: validated != null ? validated.isTrial : existing.isTrial,
                );

                await _accountDao.updateAccount(updated);

                if (credentialsChanged) {
                  // Purge old cached data when serverUrl or credentials change
                  await _categoryDao.clearCategories(accountId, 'live');
                  await _categoryDao.clearCategories(accountId, 'movie');
                  await _categoryDao.clearCategories(accountId, 'series');
                  await _streamDao.clearAllStreams(accountId);
                  await _epgDao.clearPrograms(accountId);
                  await _prefs.remove('last_sync_categories_live_$accountId');
                  await _prefs.remove('last_sync_all_live_$accountId');
                  await _prefs.remove('last_sync_categories_vod_$accountId');
                  await _prefs.remove('last_sync_all_vod_$accountId');
                  await _prefs.remove('last_sync_categories_series_$accountId');
                  await _prefs.remove('last_sync_all_series_$accountId');
                  await _prefs.remove('last_sync_epg_$accountId');
                }

                final playlistsJson = await getLocalPlaylistsJson();
                try {
                  await _client.from('remote_devices').update({
                    'playlists': playlistsJson,
                    'sync_action': null,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  }).eq('device_id', deviceId);
                } catch (_) {}

                if (!controller.isClosed) {
                  controller.add(RemoteSyncEvent(
                    type: RemoteSyncEventType.accountUpdated,
                    account: updated,
                    accountId: accountId,
                    message: 'Playlist updated: ${updated.playlistName ?? updated.username}',
                  ));
                }
              }
            }
          } else if (action == 'delete') {
            final rawId = syncAction['id'];
            final accountId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

            if (accountId != null) {
              final existing = await _accountDao.getAccountById(accountId);
              if (existing != null) {
                await _accountDao.deleteAccount(existing);
                await _categoryDao.clearCategories(accountId, 'live');
                await _categoryDao.clearCategories(accountId, 'movie');
                await _streamDao.clearAllStreams(accountId);
                await _epgDao.clearPrograms(accountId);

                final playlistsJson = await getLocalPlaylistsJson();
                try {
                  await _client.from('remote_devices').update({
                    'playlists': playlistsJson,
                    'sync_action': null,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  }).eq('device_id', deviceId);
                } catch (_) {}

                if (!controller.isClosed) {
                  controller.add(RemoteSyncEvent(
                    type: RemoteSyncEventType.accountDeleted,
                    accountId: accountId,
                    message: 'Playlist deleted: ${existing.playlistName ?? existing.username}',
                  ));
                }
              }
            }
          }
        } else if (record['status']?.toString() == 'linked' && record['sync_action'] == null) {
          // Legacy single-playlist fallback
          final serverUrl = record['server_url']?.toString().trim();
          final username = record['username']?.toString().trim();
          final password = record['password']?.toString().trim();
          final playlistName = record['playlist_name']?.toString();

          if (serverUrl != null && serverUrl.isNotEmpty) {
            final legacyKey = '${_normalizeUrl(serverUrl)}::$username';
            if (lastProcessedLegacyKey == legacyKey) {
              return;
            }
            lastProcessedLegacyKey = legacyKey;

            final existingAccounts = await _accountDao.getAllAccounts();
            final existing = existingAccounts.where((a) =>
              _normalizeUrl(a.serverUrl) == _normalizeUrl(serverUrl) &&
              a.username.trim().toLowerCase() == (username?.toLowerCase() ?? '')
            ).firstOrNull;

            int accountId;
            Account? accountResult;

            if (existing != null) {
              accountId = existing.id;
              accountResult = existing;
            } else {
              accountId = await _accountDao.insertAccount(
                AccountsCompanion.insert(
                  playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null),
                  serverUrl: serverUrl,
                  username: username ?? '',
                  password: password ?? '',
                ),
              );
              accountResult = await _accountDao.getAccountById(accountId);
            }

            final playlistsJson = await getLocalPlaylistsJson();
            try {
              await _client.from('remote_devices').update({
                'playlists': playlistsJson,
                'status': 'connected',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('device_id', deviceId);
            } catch (_) {}

            if (!controller.isClosed) {
              controller.add(RemoteSyncEvent(
                type: RemoteSyncEventType.accountAdded,
                account: accountResult,
                accountId: accountId,
                message: 'Playlist received: ${accountResult?.playlistName ?? username}',
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing remote sync event: $e');
      } finally {
        isProcessing = false;
      }
    }

    controller = StreamController<RemoteSyncEvent>(
      onListen: () {
        try {
          // 1. Supabase Realtime stream
          sub = _client
              .from('remote_devices')
              .stream(primaryKey: ['device_id'])
              .eq('device_id', deviceId)
              .listen((rows) {
                if (rows.isNotEmpty) {
                  processRecord(rows.first);
                }
              }, onError: (e) {
                debugPrint('Realtime stream error: $e');
              });

          // 2. Secondary light polling fallback (every 3.5s)
          fallbackPollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
            try {
              final response = await _client
                  .from('remote_devices')
                  .select()
                  .eq('device_id', deviceId)
                  .maybeSingle();

              if (response != null) {
                processRecord(response);
              }
            } catch (_) {}
          });
        } catch (e) {
          debugPrint('Error starting Supabase listener: $e');
        }
      },
      onCancel: () {
        sub?.cancel();
        fallbackPollTimer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Backward-compatible stream that emits when an Account is added
  Stream<Account> listenForLinkedPlaylist(String deviceId) {
    return listenForRemoteEvents(deviceId)
        .where((e) => e.type == RemoteSyncEventType.accountAdded && e.account != null)
        .map((e) => e.account!);
  }
}
