import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/remote_sync/zero_knowledge_crypto.dart';

void main() {
  group('ZeroKnowledgePairingCrypto (SEC-01)', () {
    const pin = '582910';
    const deviceId = 'GP-4921-X93K';

    test('encrypts and decrypts sync_action roundtrip', () {
      final plainAction = {
        'action_id': 'add_1730000000_abc',
        'action': 'add',
        'type': 'xtream',
        'playlist_name': 'My Super IPTV',
        'server_url': 'http://secure-iptv.com:8080',
        'username': 'my_user_name',
        'password': 'SuperSecretPassword_999!',
        'timestamp': 1730000000,
      };

      final encrypted = ZeroKnowledgePairingCrypto.encryptSyncAction(plainAction, pin, deviceId);

      expect(encrypted['encrypted'], isTrue);
      expect(encrypted['iv'], isNotNull);
      expect(encrypted['data'], isNotNull);
      // Credentials must NOT appear in encrypted payload
      expect(encrypted.toString(), isNot(contains('SuperSecretPassword_999!')));
      expect(encrypted.toString(), isNot(contains('http://secure-iptv.com:8080')));

      // Decrypt
      final decrypted = ZeroKnowledgePairingCrypto.decryptSyncAction(encrypted, pin, deviceId);
      expect(decrypted['action'], equals('add'));
      expect(decrypted['playlist_name'], equals('My Super IPTV'));
      expect(decrypted['server_url'], equals('http://secure-iptv.com:8080'));
      expect(decrypted['username'], equals('my_user_name'));
      expect(decrypted['password'], equals('SuperSecretPassword_999!'));
    });

    test('seamlessly returns legacy unencrypted actions without breaking', () {
      final legacyAction = {
        'action_id': 'add_legacy_1',
        'action': 'add',
        'type': 'm3u',
        'server_url': 'http://example.com/playlist.m3u',
      };

      final result = ZeroKnowledgePairingCrypto.decryptSyncAction(legacyAction, pin, deviceId);
      expect(result['action'], equals('add'));
      expect(result['server_url'], equals('http://example.com/playlist.m3u'));
    });

    test('wrong PIN fails authentication cleanly and gracefully', () {
      final plainAction = {
        'action_id': 'action_1',
        'action': 'add',
        'password': 'SecretPassword',
      };

      final encrypted = ZeroKnowledgePairingCrypto.encryptSyncAction(plainAction, pin, deviceId);
      final decryptedWithWrongPin = ZeroKnowledgePairingCrypto.decryptSyncAction(encrypted, '000000', deviceId);

      // Decryption with wrong PIN cannot decrypt authentic GCM tag
      expect(decryptedWithWrongPin['password'], isNull);
    });
  });
}
