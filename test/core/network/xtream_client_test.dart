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
  });
}
