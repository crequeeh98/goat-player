import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goat_player/core/security/security_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecurityVault.resetCacheForTesting();
  });

  group('SecurityVault At-Rest Encryption (SEC-04)', () {
    test('encrypts and decrypts secret string roundtrip', () async {
      await SecurityVault.getMasterKey();
      const plain = 'super_secret_password_1234!';
      final encrypted = SecurityVault.encrypt(plain);

      expect(encrypted, startsWith('enc:v1:'));
      expect(encrypted, isNot(contains(plain)));

      final decrypted = SecurityVault.decrypt(encrypted);
      expect(decrypted, equals(plain));
    });

    test('preserves legacy plaintext passwords seamlessly (zero breakage)', () {
      const legacyPlain = 'legacy_plaintext_iptv_pass';
      final result = SecurityVault.decrypt(legacyPlain);

      expect(result, equals(legacyPlain));
    });

    test('does not re-encrypt already encrypted strings', () {
      const plain = 'my_password';
      final enc1 = SecurityVault.encrypt(plain);
      final enc2 = SecurityVault.encrypt(enc1);

      expect(enc2, equals(enc1));
    });

    test('handles empty or blank string gracefully', () {
      expect(SecurityVault.encrypt(''), equals(''));
      expect(SecurityVault.decrypt(''), equals(''));
    });
  });
}
