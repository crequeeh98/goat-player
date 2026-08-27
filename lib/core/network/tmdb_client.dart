import 'package:dio/dio.dart';

class TMDBClient {
  final Dio _dio;
  final String apiKey;
  
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  TMDBClient(this._dio, {required this.apiKey}) {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.queryParameters = {'api_key': apiKey};
  }

  Future<Map<String, dynamic>?> searchMovie(String query) async {
    try {
      final response = await _dio.get('/search/movie', queryParameters: {'query': query});
      final results = response.data['results'] as List;
      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to search TMDB for movie: $e');
    }
  }

  Future<Map<String, dynamic>?> searchSeries(String query) async {
    try {
      final response = await _dio.get('/search/tv', queryParameters: {'query': query});
      final results = response.data['results'] as List;
      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to search TMDB for series: $e');
    }
  }

  Future<Map<String, dynamic>> getMovieDetails(int id) async {
    try {
      final response = await _dio.get('/movie/$id', queryParameters: {
        'append_to_response': 'videos,credits'
      });
      return response.data;
    } catch (e) {
      throw Exception('Failed to get movie details: $e');
    }
  }

  Future<Map<String, dynamic>> getSeriesDetails(int id) async {
    try {
      final response = await _dio.get('/tv/$id', queryParameters: {
        'append_to_response': 'videos,credits'
      });
      return response.data;
    } catch (e) {
      throw Exception('Failed to get series details: $e');
    }
  }
}
