import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:goat_player/core/network/xtream_client.dart';

void main() {
  group('XtreamClient Security & Credential Masking (SEC-06)', () {
    test('sanitizeErrorMessage masks password parameter in URLs and messages', () {
      const rawUrl = 'http://example.com/player_api.php?username=testuser&password=SuperSecretPassword123&action=get_live_streams';
      final sanitized = XtreamClient.sanitizeErrorMessage(rawUrl);

      expect(sanitized, contains('password=***'));
      expect(sanitized, isNot(contains('SuperSecretPassword123')));
      expect(sanitized, contains('username=testuser'));
    });

    test('sanitizeErrorMessage handles multiple password patterns and case insensitivity', () {
      const msg = 'DioException [bad response]: 401 Unauthorized for URL http://stream.tv/api.php?PASSWORD=MySecretPass&other=1';
      final sanitized = XtreamClient.sanitizeErrorMessage(msg);

      expect(sanitized, contains('PASSWORD=***'));
      expect(sanitized, isNot(contains('MySecretPass')));
    });

    test('authenticate masks password when network/server throws error', () async {
      final dio = Dio();
      // Configure adapter to reject request immediately
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Connection refused to ${options.uri}',
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      final client = XtreamClient(
        dio,
        baseUrl: 'http://test-server.org',
        username: 'user42',
        password: 'TopSecretPassword999',
      );

      try {
        await client.authenticate();
        fail('Should have thrown an Exception');
      } catch (e) {
        final errString = e.toString();
        expect(errString, contains('Failed to authenticate:'));
        expect(errString, isNot(contains('TopSecretPassword999')));
        expect(errString, contains('password=***'));
      }
    });

    test('getVodInfo masks password in exception when request fails', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Failed request to ${options.uri}',
                type: DioExceptionType.unknown,
              ),
            );
          },
        ),
      );

      final client = XtreamClient(
        dio,
        baseUrl: 'http://test-server.org',
        username: 'user42',
        password: 'VodSecretPass777',
      );

      try {
        await client.getVodInfo('123');
        fail('Should have thrown an Exception');
      } catch (e) {
        final errString = e.toString();
        expect(errString, isNot(contains('VodSecretPass777')));
        expect(errString, contains('password=***'));
      }
    });

    test('tryParseXtreamFromM3uUrl extracts Xtream credentials from M3U URLs', () {
      final fromQuery = XtreamClient.tryParseXtreamFromM3uUrl(
        'http://demo.tv:8080/get.php?username=alice&password=secret123&type=m3u_plus',
      );
      expect(fromQuery, isNotNull);
      expect(fromQuery!.serverUrl, equals('http://demo.tv:8080'));
      expect(fromQuery.username, equals('alice'));
      expect(fromQuery.password, equals('secret123'));

      final fromPath = XtreamClient.tryParseXtreamFromM3uUrl(
        'https://iptv.example.com/live/bob/pw99/42.ts',
      );
      expect(fromPath, isNotNull);
      expect(fromPath!.serverUrl, equals('https://iptv.example.com'));
      expect(fromPath.username, equals('bob'));
      expect(fromPath.password, equals('pw99'));

      final plainM3u = XtreamClient.tryParseXtreamFromM3uUrl(
        'https://example.org/playlists/channels.m3u8',
      );
      expect(plainM3u, isNull);
    });

    test('formatUserFriendlyError hides raw DioException dumps and reports concise status', () {
      final req = RequestOptions(path: 'http://panel.test:8080/player_api.php');
      final err401 = DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      final msgDe = XtreamClient.formatUserFriendlyError(err401, isDe: true);
      expect(msgDe, contains('Zugriff verweigert'));
      expect(msgDe, isNot(contains('DioException [')));
      expect(msgDe, isNot(contains('RequestOptions')));

      final err404 = DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: 404),
        type: DioExceptionType.badResponse,
      );
      final msg404 = XtreamClient.formatUserFriendlyError(err404, isDe: false, isM3u: true);
      expect(msg404, contains('404'));
      expect(msg404, isNot(contains('DioException [')));

      final m3uErr = XtreamClient.formatUserFriendlyError(
        Exception('Failed to authenticate: Invalid M3U playlist format'),
        isDe: false,
        isM3u: true,
      );
      expect(m3uErr, contains('Invalid M3U playlist'));
      expect(m3uErr, isNot(contains('Exception:')));
    });
  });
}
