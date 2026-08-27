import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(AppDatabase db) : super(db);

  Future<List<Account>> getAllAccounts() => select(accounts).get();

  Stream<List<Account>> watchAllAccounts() => select(accounts).watch();

  Future<int> insertAccount(AccountsCompanion account) => into(accounts).insert(account);

  Future<bool> updateAccount(Account account) => update(accounts).replace(account);

  Future<int> deleteAccount(Account account) => delete(accounts).delete(account);
  
  Future<Account?> getAccountById(int id) {
    return (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }
}
