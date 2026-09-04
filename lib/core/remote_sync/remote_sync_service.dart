import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../database/daos/account_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/stream_dao.dart';
import '../database/daos/epg_dao.dart';

enum RemoteSyncEventType { accountAdded, accountUpdated, accountDeleted }

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

  /// Formats all local accounts into JSON to sync with Supabase
  Future<List<Map<String, dynamic>>> getLocalPlaylistsJson() async {
    final localAccounts = await _accountDao.getAllAccounts();
    return localAccounts.map((a) => {
      'id': a.id,
      'playlist_name': a.playlistName ?? a.username,
      'server_url': a.serverUrl,
      'username': a.username,
      'password': a.password,
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
      debugPrint('Note: could not update playlists in remote_devices (column may not exist yet): $e');
    }
  }

  /// Creates a new pairing session with a random 6-digit PIN valid for 20 minutes
  /// and syncs current device playlists to Supabase.
  Future<PairingSession> startPairingSession() async {
    final deviceId = getDeviceId();
    final random = Random();
    final pin = (100000 + random.nextInt(900000)).toString();
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

    void processRecord(Map<String, dynamic> record) async {
      if (isProcessing) return;
      isProcessing = true;

      try {
        final syncAction = record['sync_action'];
        if (syncAction != null && syncAction is Map) {
          final action = syncAction['action']?.toString();

          if (action == 'add') {
            final serverUrl = syncAction['server_url']?.toString() ?? '';
            final username = syncAction['username']?.toString() ?? '';
            final password = syncAction['password']?.toString() ?? '';
            final playlistName = syncAction['playlist_name']?.toString();

            if (serverUrl.isNotEmpty) {
              final id = await _accountDao.insertAccount(
                AccountsCompanion.insert(
                  playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null),
                  serverUrl: serverUrl.trim(),
                  username: username.trim(),
                  password: password.trim(),
                ),
              );

              final newAccount = await _accountDao.getAccountById(id);
              await pushLocalPlaylists(deviceId);

              try {
                await _client.from('remote_devices').update({
                  'sync_action': null,
                  'status': 'synced',
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                }).eq('device_id', deviceId);
              } catch (_) {}

              if (!controller.isClosed) {
                controller.add(RemoteSyncEvent(
                  type: RemoteSyncEventType.accountAdded,
                  account: newAccount,
                  accountId: id,
                  message: 'Playlist added: ${newAccount?.playlistName ?? username}',
                ));
              }
            }
          } else if (action == 'edit') {
            final rawId = syncAction['id'];
            final accountId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

            if (accountId != null) {
              final existing = await _accountDao.getAccountById(accountId);
              if (existing != null) {
                final playlistName = syncAction['playlist_name']?.toString();
                final serverUrl = syncAction['server_url']?.toString().trim() ?? existing.serverUrl;
                final username = syncAction['username']?.toString().trim() ?? existing.username;
                final password = syncAction['password']?.toString().trim() ?? existing.password;

                final updated = existing.copyWith(
                  playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null),
                  serverUrl: serverUrl,
                  username: username,
                  password: password,
                );

                await _accountDao.updateAccount(updated);
                await pushLocalPlaylists(deviceId);

                try {
                  await _client.from('remote_devices').update({
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

                await pushLocalPlaylists(deviceId);

                try {
                  await _client.from('remote_devices').update({
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
        } else if (record['status']?.toString() == 'linked') {
          // Legacy single-playlist fallback
          final serverUrl = record['server_url']?.toString();
          final username = record['username']?.toString();
          final password = record['password']?.toString();
          final playlistName = record['playlist_name']?.toString();

          if (serverUrl != null && serverUrl.isNotEmpty) {
            final id = await _accountDao.insertAccount(
              AccountsCompanion.insert(
                playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null),
                serverUrl: serverUrl.trim(),
                username: username?.trim() ?? '',
                password: password?.trim() ?? '',
              ),
            );

            await pushLocalPlaylists(deviceId);

            try {
              await _client.from('remote_devices').update({
                'status': 'synced',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('device_id', deviceId);
            } catch (_) {}

            final newAccount = await _accountDao.getAccountById(id);
            if (!controller.isClosed) {
              controller.add(RemoteSyncEvent(
                type: RemoteSyncEventType.accountAdded,
                account: newAccount,
                accountId: id,
                message: 'Playlist received: ${newAccount?.playlistName ?? username}',
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
