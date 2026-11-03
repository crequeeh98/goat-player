import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';
import '../../security/security_vault.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(AppDatabase db) : super(db);

  Account _decryptAccount(Account acc) {
    if (acc.password.isEmpty || !acc.password.startsWith('enc:v1:')) {
      return acc;
    }
    return acc.copyWith(password: SecurityVault.decrypt(acc.password));
  }

  AccountsCompanion _encryptCompanion(AccountsCompanion comp) {
    if (!comp.password.present) return comp;
    final plain = comp.password.value;
    if (plain.isEmpty || plain.startsWith('enc:v1:')) return comp;
    return comp.copyWith(password: Value(SecurityVault.encrypt(plain)));
  }

  Account _encryptAccount(Account acc) {
    if (acc.password.isEmpty || acc.password.startsWith('enc:v1:')) {
      return acc;
    }
    return acc.copyWith(password: SecurityVault.encrypt(acc.password));
  }

  Future<List<Account>> getAllAccounts() async {
    final list = await select(accounts).get();
    return list.map(_decryptAccount).toList();
  }

  Stream<List<Account>> watchAllAccounts() {
    return select(accounts).watch().map((list) => list.map(_decryptAccount).toList());
  }

  Future<int> insertAccount(AccountsCompanion account) {
    return into(accounts).insert(_encryptCompanion(account));
  }

  Future<bool> updateAccount(Account account) {
    return update(accounts).replace(_encryptAccount(account));
  }

  Future<void> updateSyncScopes(int accountId, {required bool syncLiveTv, required bool syncMovies, required bool syncSeries}) {
    return (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        syncLiveTv: Value(syncLiveTv),
        syncMovies: Value(syncMovies),
        syncSeries: Value(syncSeries),
      ),
    );
  }

  Future<int> deleteAccount(Account account) => delete(accounts).delete(account);
  
  Future<Account?> getAccountById(int id) async {
    final acc = await (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();
    return acc != null ? _decryptAccount(acc) : null;
  }

  /// Silently migrates any legacy plaintext passwords in SQLite to encrypted storage at rest
  Future<void> migrateLegacyPlaintextPasswords() async {
    try {
      final rawAccounts = await select(accounts).get();
      for (final acc in rawAccounts) {
        if (acc.password.isNotEmpty && !acc.password.startsWith('enc:v1:')) {
          final encrypted = SecurityVault.encrypt(acc.password);
          await (update(accounts)..where((t) => t.id.equals(acc.id)))
              .write(AccountsCompanion(password: Value(encrypted)));
        }
      }
    } catch (_) {}
  }
}
