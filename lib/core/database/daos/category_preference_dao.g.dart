// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_preference_dao.dart';

// ignore_for_file: type=lint
mixin _$CategoryPreferenceDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoryPreferencesTable get categoryPreferences =>
      attachedDatabase.categoryPreferences;
  CategoryPreferenceDaoManager get managers =>
      CategoryPreferenceDaoManager(this);
}

class CategoryPreferenceDaoManager {
  final _$CategoryPreferenceDaoMixin _db;
  CategoryPreferenceDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoryPreferencesTableTableManager get categoryPreferences =>
      $$CategoryPreferencesTableTableManager(
        _db.attachedDatabase,
        _db.categoryPreferences,
      );
}
