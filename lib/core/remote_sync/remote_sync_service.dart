import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../database/daos/account_dao.dart';

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
  final SharedPreferences _prefs;

  RemoteSyncService(this._accountDao, this._prefs);

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

  /// Creates a new pairing session with a random 6-digit PIN valid for 20 minutes
  Future<PairingSession> startPairingSession() async {
    final deviceId = getDeviceId();
    final random = Random();
    final pin = (100000 + random.nextInt(900000)).toString();
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 20));

    final qrUrl = '$defaultPortalUrl?device=$deviceId&pin=$pin';

    try {
      await _client.from('remote_devices').upsert({
        'device_id': deviceId,
        'pin': pin,
        'pin_expires_at': expiresAt.toIso8601String(),
        'status': 'pending',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('Pairing session created for $deviceId with PIN $pin');
    } catch (e) {
      debugPrint('Error creating pairing session in Supabase: $e');
      rethrow;
    }

    return PairingSession(
      deviceId: deviceId,
      pin: pin,
      expiresAt: expiresAt.toLocal(),
      qrUrl: qrUrl,
    );
  }

  /// Subscribes to Realtime updates for this device.
  /// When status changes to 'linked', saves account locally and marks 'synced'.
  Stream<Account> listenForLinkedPlaylist(String deviceId) {
    late final StreamController<Account> controller;
    StreamSubscription<List<Map<String, dynamic>>>? sub;
    Timer? fallbackPollTimer;

    void processRecord(Map<String, dynamic> record) async {
      final status = record['status']?.toString();
      if (status == 'linked') {
        final serverUrl = record['server_url']?.toString();
        final username = record['username']?.toString();
        final password = record['password']?.toString();
        final playlistName = record['playlist_name']?.toString();

        if (serverUrl != null && serverUrl.isNotEmpty) {
          try {
            debugPrint('Remote playlist received: $serverUrl');
            final id = await _accountDao.insertAccount(
              AccountsCompanion.insert(
                playlistName: drift.Value(playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null),
                serverUrl: serverUrl.trim(),
                username: username?.trim() ?? '',
                password: password?.trim() ?? '',
              ),
            );

            // Acknowledge sync in Supabase
            await _client.from('remote_devices').update({
              'status': 'synced',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('device_id', deviceId);

            final newAccount = Account(
              id: id,
              playlistName: playlistName != null && playlistName.trim().isNotEmpty ? playlistName.trim() : null,
              serverUrl: serverUrl.trim(),
              username: username?.trim() ?? '',
              password: password?.trim() ?? '',
              isTrial: false,
              maxConnections: null,
              expDate: null,
              createdAt: DateTime.now(),
            );

            if (!controller.isClosed) {
              controller.add(newAccount);
            }
          } catch (e) {
            debugPrint('Failed to save remote account to database: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          }
        }
      }
    }

    controller = StreamController<Account>(
      onListen: () {
        try {
          // 1. Primary: Supabase Realtime Stream
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

          // 2. Secondary: Light fallback poll every 4s in case WebSockets are blocked by strict firewalls
          fallbackPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
            try {
              final response = await _client
                  .from('remote_devices')
                  .select()
                  .eq('device_id', deviceId)
                  .maybeSingle();

              if (response != null) {
                processRecord(response);
              }
            } catch (e) {
              // Ignore polling errors
            }
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
}
