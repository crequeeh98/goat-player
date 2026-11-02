import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/core/security/security_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecurityVault.resetCacheForTesting();
    await SecurityVault.getMasterKey();
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountDao Security & Encryption at Rest (SEC-04)', () {
    test('inserting account stores encrypted password in SQLite while returning plaintext in DAO', () async {
      const originalPassword = 'MySecretStreamingPassword123!';

      final id = await db.accountDao.insertAccount(
        AccountsCompanion.insert(
          serverUrl: 'http://iptv.provider.com:8080',
          username: 'streamuser',
          password: originalPassword,
        ),
      );

      // 1. Verify that raw row in database table is encrypted at rest (SEC-04)
      final rawRow = await (db.select(db.accounts)..where((t) => t.id.equals(id))).getSingle();
      expect(rawRow.password, startsWith('enc:v1:'));
      expect(rawRow.password, isNot(contains(originalPassword)));

      // 2. Verify that DAO read methods decrypt transparently in memory (Zero Breakage)
      final daoAccount = await db.accountDao.getAccountById(id);
      expect(daoAccount, isNotNull);
      expect(daoAccount!.password, equals(originalPassword));

      final allAccounts = await db.accountDao.getAllAccounts();
      expect(allAccounts.first.password, equals(originalPassword));
    });

    test('seamlessly reads legacy plaintext passwords without breaking existing accounts', () async {
      const legacyPassword = 'unencrypted_legacy_password';

      // Insert directly into table bypassing DAO to simulate preexisting legacy accounts
      final id = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          serverUrl: 'http://legacy-server.tv',
          username: 'legacyuser',
          password: legacyPassword,
        ),
      );

      // Verify that DAO read methods return the legacy plaintext password directly
      final account = await db.accountDao.getAccountById(id);
      expect(account, isNotNull);
      expect(account!.password, equals(legacyPassword));

      final all = await db.accountDao.getAllAccounts();
      expect(all.any((a) => a.id == id && a.password == legacyPassword), isTrue);
    });

    test('migrateLegacyPlaintextPasswords encrypts legacy plaintext accounts in place', () async {
      const legacyPassword = 'plain_to_be_migrated';

      // Insert raw plaintext account
      final id = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          serverUrl: 'http://migration.tv',
          username: 'migrateuser',
          password: legacyPassword,
        ),
      );

      // Run migration
      await db.accountDao.migrateLegacyPlaintextPasswords();

      // Check SQLite table directly: must now be encrypted
      final rawRow = await (db.select(db.accounts)..where((t) => t.id.equals(id))).getSingle();
      expect(rawRow.password, startsWith('enc:v1:'));
      expect(rawRow.password, isNot(contains(legacyPassword)));

      // Check DAO: still decrypts to original password
      final daoAcc = await db.accountDao.getAccountById(id);
      expect(daoAcc!.password, equals(legacyPassword));
    });
  });
}
