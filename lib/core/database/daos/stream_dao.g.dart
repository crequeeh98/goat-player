// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stream_dao.dart';

// ignore_for_file: type=lint
mixin _$StreamDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $StreamsTable get streams => attachedDatabase.streams;
  $FavoritesTable get favorites => attachedDatabase.favorites;
  StreamDaoManager get managers => StreamDaoManager(this);
}

class StreamDaoManager {
  final _$StreamDaoMixin _db;
  StreamDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$StreamsTableTableManager get streams =>
      $$StreamsTableTableManager(_db.attachedDatabase, _db.streams);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db.attachedDatabase, _db.favorites);
}
