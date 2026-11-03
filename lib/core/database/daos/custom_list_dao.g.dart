// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_list_dao.dart';

// ignore_for_file: type=lint
mixin _$CustomListDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CustomListsTable get customLists => attachedDatabase.customLists;
  $CustomListItemsTable get customListItems => attachedDatabase.customListItems;
  $StreamsTable get streams => attachedDatabase.streams;
  CustomListDaoManager get managers => CustomListDaoManager(this);
}

class CustomListDaoManager {
  final _$CustomListDaoMixin _db;
  CustomListDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CustomListsTableTableManager get customLists =>
      $$CustomListsTableTableManager(_db.attachedDatabase, _db.customLists);
  $$CustomListItemsTableTableManager get customListItems =>
      $$CustomListItemsTableTableManager(
        _db.attachedDatabase,
        _db.customListItems,
      );
  $$StreamsTableTableManager get streams =>
      $$StreamsTableTableManager(_db.attachedDatabase, _db.streams);
}
