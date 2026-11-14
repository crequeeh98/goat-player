import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class XtreamClient {
  final Dio _dio;
  final String baseUrl;
  final String username;
  final String password;

  XtreamClient(this._dio, {required this.baseUrl, required this.username, required this.password}) {
    _dio.options.headers = {
      'User-Agent': 'GOATPlayer/1.0.0 (Windows/Android)',
    };
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, handler) {
          final qp = Map<String, dynamic>.from(err.requestOptions.queryParameters);
          if (qp.containsKey('password')) {
            qp['password'] = '***';
          }
          final sanitizedOptions = err.requestOptions.copyWith(
            queryParameters: qp,
          );
          final sanitizedError = err.copyWith(
            requestOptions: sanitizedOptions,
            message: sanitizeErrorMessage(err.message ?? ''),
          );
          handler.next(sanitizedError);
        },
      ),
    );
  }

  /// Sanitizes sensitive parameters (e.g. password=...) from error strings or URLs
  static String sanitizeErrorMessage(Object error) {
    final str = error.toString();
    return str.replaceAllMapped(
      RegExp(r'(password=)([^&\s\)]+)', caseSensitive: false),
      (match) => '${match.group(1)}***',
    );
  }

  /// Extracts Xtream server/username/password from M3U playlist links that embed credentials
  /// (either in query params `?username=...&password=...` or `/live|movie|series/user/pass/...` path).
  /// Returns `null` for plain M3U links without embedded credentials.
  static ({String serverUrl, String username, String password})? tryParseXtreamFromM3uUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final serverUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final qpLower = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      qpLower[entry.key.toLowerCase()] = entry.value.trim();
    }

    var username = qpLower['username'] ?? qpLower['user'] ?? qpLower['u'] ?? '';
    var password = qpLower['password'] ?? qpLower['pass'] ?? qpLower['p'] ?? '';

    if (username.isEmpty || password.isEmpty) {
      final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (parts.length >= 4 && ['live', 'movie', 'series'].contains(parts[0].toLowerCase())) {
        final candidatePass = parts[2];
        if (!RegExp(r'\.(m3u8?|ts|mp4|mkv)$', caseSensitive: false).hasMatch(candidatePass)) {
          username = parts[1];
          password = candidatePass;
        }
      }
    }

    if (username.isEmpty || password.isEmpty) return null;
    return (serverUrl: serverUrl, username: username, password: password);
  }

  /// Formats connection, HTTP, auth, or M3U errors into a concise, single-line user message.
  static String formatUserFriendlyError(Object error, {bool isDe = true, bool isM3u = false}) {
    if (error is DioException) {
      return _formatDioError(error, isDe: isDe, isM3u: isM3u);
    }

    final raw = sanitizeErrorMessage(error);
    final lower = raw.toLowerCase();

    if (lower.contains('invalid m3u playlist format')) {
      return isDe
          ? 'Ungültige M3U-Playlist (kein gültiges #EXTM3U/#EXTINF-Format).'
          : 'Invalid M3U playlist (missing #EXTM3U/#EXTINF header).';
    }
    if (lower.contains('no playable channels found in m3u')) {
      return isDe
          ? 'Keine abspielbaren Sender in dieser M3U-Playlist gefunden.'
          : 'No playable channels found in this M3U playlist.';
    }
    if (lower.contains('invalid credentials') ||
        lower.contains('authentication failed') ||
        lower.contains('anmeldung fehlgeschlagen') ||
        lower.contains('konto inaktiv')) {
      return isDe
          ? 'Anmeldung fehlgeschlagen: Zugangsdaten ungültig oder Konto inaktiv.'
          : 'Authentication failed: Invalid credentials or inactive account.';
    }
    if (lower.contains('connectiontimeout') ||
        lower.contains('sendtimeout') ||
        lower.contains('receivetimeout') ||
        lower.contains('timed out')) {
      return isDe
          ? 'Zeitüberschreitung: Server antwortet nicht.'
          : 'Connection timed out: Server did not respond.';
    }
    if (lower.contains('handshakeexception') || lower.contains('certificate')) {
      return isDe
          ? 'SSL-/Zertifikatsfehler bei der Serververbindung.'
          : 'SSL/certificate error connecting to the server.';
    }
    if (lower.contains('status code of 401') || lower.contains('status code of 403')) {
      return isDe
          ? 'Zugriff verweigert: Benutzername oder Passwort ungültig.'
          : 'Access denied: Invalid username or password.';
    }
    if (lower.contains('status code of 404')) {
      return isM3u
          ? (isDe ? 'M3U-Playlist unter dieser URL nicht gefunden (404).' : 'M3U playlist not found at this URL (404).')
          : (isDe ? 'Xtream-Server nicht gefunden (404). URL prüfen.' : 'Xtream endpoint not found (404). Check URL.');
    }
    final statusMatch = RegExp(r'status code of (\d{3})').firstMatch(lower);
    if (statusMatch != null) {
      final code = statusMatch.group(1);
      return isDe ? 'Serverfehler (HTTP $code).' : 'Server returned HTTP $code.';
    }
    if (lower.contains('connection error') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('no address associated')) {
      return isDe
          ? 'Verbindung fehlgeschlagen: Server-URL nicht erreichbar.'
          : 'Connection failed: Server URL is unreachable.';
    }
    if (lower.contains('formatexception') ||
        lower.contains('expected xtream json') ||
        lower.contains('unexpected character') ||
        lower.contains('is not a subtype') ||
        lower.contains('invalid argument') ||
        lower.contains('no host specified')) {
      return isM3u
          ? (isDe ? 'Ungültige M3U-URL oder fehlerhafte Antwort.' : 'Invalid M3U URL or malformed response.')
          : (isDe ? 'Ungültige Server-Antwort (kein Xtream-Server).' : 'Invalid server response (expected Xtream API).');
    }

    final firstLine = raw
        .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^Failed to authenticate:\s*', caseSensitive: false), '')
        .split('\n')
        .first
        .trim();
    if (firstLine.isEmpty || firstLine.length > 140 || firstLine.startsWith('DioException')) {
      return isDe
          ? 'Verbindung fehlgeschlagen. URL und Zugangsdaten prüfen.'
          : 'Connection failed. Please verify URL and credentials.';
    }
    return firstLine;
  }

  static String _formatDioError(DioException err, {required bool isDe, required bool isM3u}) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return isDe
            ? 'Zeitüberschreitung: Server antwortet nicht.'
            : 'Connection timed out: Server did not respond.';
      case DioExceptionType.badCertificate:
        return isDe
            ? 'SSL-/Zertifikatsfehler bei der Serververbindung.'
            : 'SSL/certificate error connecting to the server.';
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode;
        if (code == 401 || code == 403) {
          return isDe
              ? 'Zugriff verweigert: Benutzername oder Passwort ungültig.'
              : 'Access denied: Invalid username or password.';
        }
        if (code == 404) {
          return isM3u
              ? (isDe ? 'M3U-Playlist unter dieser URL nicht gefunden (404).' : 'M3U playlist not found at this URL (404).')
              : (isDe ? 'Xtream-Server nicht gefunden (404). URL prüfen.' : 'Xtream endpoint not found (404). Check URL.');
        }
        return isDe
            ? 'Serverfehler${code != null ? ' (HTTP $code)' : ''}.'
            : 'Server error${code != null ? ' (HTTP $code)' : ''}.';
      case DioExceptionType.connectionError:
        return isDe
            ? 'Verbindung fehlgeschlagen: Server-URL nicht erreichbar.'
            : 'Connection failed: Server URL is unreachable.';
      case DioExceptionType.cancel:
        return isDe ? 'Anfrage abgebrochen.' : 'Request cancelled.';
      case DioExceptionType.unknown:
        final inner = err.error?.toString().toLowerCase() ?? '';
        if (inner.contains('handshake') || inner.contains('certificate')) {
          return isDe
              ? 'SSL-/Zertifikatsfehler bei der Serververbindung.'
              : 'SSL/certificate error connecting to the server.';
        }
        return isDe
            ? 'Verbindung fehlgeschlagen: Server nicht erreichbar oder URL ungültig.'
            : 'Connection failed: Server unreachable or invalid URL.';
    }
  }

  String getXmltvUrl() {
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$normalizedBaseUrl/xmltv.php?username=$username&password=$password';
  }

  Future<Map<String, dynamic>> authenticate() async {
    try {
      final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get('$normalizedBaseUrl/player_api.php', queryParameters: {
        'username': username,
        'password': password,
      });
      var data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw const FormatException('Expected Xtream JSON object');
    } catch (e) {
      final safe = sanitizeErrorMessage(e);
      throw Exception('Failed to authenticate: $safe');
    }
  }

  Future<List<dynamic>> getLiveCategories() async {
    return _fetchData('get_live_categories');
  }

  Future<List<dynamic>> getLiveStreams({String? categoryId}) async {
    return _fetchData('get_live_streams', categoryId: categoryId);
  }

  Future<List<dynamic>> getVodCategories() async {
    return _fetchData('get_vod_categories');
  }

  Future<List<dynamic>> getVodStreams({String? categoryId}) async {
    return _fetchData('get_vod_streams', categoryId: categoryId);
  }

  Future<dynamic> getVodInfo(String vodId) async {
    try {
      final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get('$normalizedBaseUrl/player_api.php', queryParameters: {
        'username': username,
        'password': password,
        'action': 'get_vod_info',
        'vod_id': vodId,
      });
      
      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          debugPrint('JSON Decode failed for vod info: $e');
        }
      }
      return responseData;
    } catch (e) {
      final safe = sanitizeErrorMessage(e);
      debugPrint('Failed to fetch vod info: $safe');
      throw Exception('Failed to fetch vod info: $safe');
    }
  }

  Future<List<dynamic>> getSeriesCategories() async {
    return _fetchData('get_series_categories');
  }

  Future<List<dynamic>> getSeries({String? categoryId}) async {
    return _fetchData('get_series', categoryId: categoryId);
  }

  Future<List<dynamic>> getShortEpg(String streamId, {int limit = 10}) async {
    try {
      final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get(
        '$normalizedBaseUrl/player_api.php',
        queryParameters: {
          'username': username,
          'password': password,
          'action': 'get_short_epg',
          'stream_id': streamId,
          'limit': limit.toString(),
        },
      );
      if (response.data is Map && response.data['epg_listings'] is List) {
        return response.data['epg_listings'] as List<dynamic>;
      }
      return const [];
    } catch (e) {
      return const [];
    }
  }

  Future<dynamic> getSeriesInfo(String seriesId) async {
    try {
      final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get('$normalizedBaseUrl/player_api.php', queryParameters: {
        'username': username,
        'password': password,
        'action': 'get_series_info',
        'series_id': seriesId,
      });
      return response.data;
    } catch (e) {
      final safe = sanitizeErrorMessage(e);
      debugPrint('Failed to fetch series info: $safe');
      throw Exception('Failed to fetch series info: $safe');
    }
  }

  Future<List<dynamic>> _fetchData(String action, {String? categoryId}) async {
    try {
      final queryParams = {
        'username': username,
        'password': password,
        'action': action,
      };
      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      
      final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get('$normalizedBaseUrl/player_api.php', queryParameters: queryParams);
      
      dynamic responseData = response.data;
      debugPrint('API RAW ($action) Type: ${responseData.runtimeType}');
      
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (e) {
          debugPrint('JSON Decode failed: $e');
        }
      }
      
      if (responseData is Map) {
        if (responseData.containsKey('user_info')) {
          debugPrint('Warning: Server returned authentication block instead of list for $action');
          return [];
        } else {
          debugPrint('Warning: Server returned a Map but expected a List for $action. Keys: ${responseData.keys}');
        }
      }
      
      if (responseData is List) {
        return responseData;
      } else {
        debugPrint('Warning: responseData is neither List nor valid Map: $responseData');
        return [];
      }
    } catch (e) {
      final safe = sanitizeErrorMessage(e);
      debugPrint('API Error ($action): $safe');
      throw Exception('Failed to fetch $action: $safe');
    }
  }
}
