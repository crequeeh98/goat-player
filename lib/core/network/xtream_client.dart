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
      return response.data;
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
