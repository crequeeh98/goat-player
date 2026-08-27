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
      throw Exception('Failed to authenticate: $e');
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
      debugPrint('Failed to fetch vod info: $e');
      throw Exception('Failed to fetch vod info: $e');
    }
  }

  Future<List<dynamic>> getSeriesCategories() async {
    return _fetchData('get_series_categories');
  }

  Future<List<dynamic>> getSeries({String? categoryId}) async {
    return _fetchData('get_series', categoryId: categoryId);
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
      debugPrint('Failed to fetch series info: $e');
      throw Exception('Failed to fetch series info: $e');
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
        return responseData as List<dynamic>;
      } else {
        debugPrint('Warning: responseData is neither List nor valid Map: $responseData');
        return [];
      }
    } catch (e) {
      debugPrint('API Error ($action): $e');
      throw Exception('Failed to fetch $action: $e');
    }
  }
}
