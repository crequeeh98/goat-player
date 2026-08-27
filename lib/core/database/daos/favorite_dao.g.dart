// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_dao.dart';

// ignore_for_file: type=lint
mixin _$FavoriteDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $FavoritesTable get favorites => attachedDatabase.favorites;
  FavoriteDaoManager get managers => FavoriteDaoManager(this);
}

class FavoriteDaoManager {
  final _$FavoriteDaoMixin _db;
  FavoriteDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db.attachedDatabase, _db.favorites);
}
