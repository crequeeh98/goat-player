// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_dao.dart';

// ignore_for_file: type=lint
mixin _$EpgDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $EpgProgramsTable get epgPrograms => attachedDatabase.epgPrograms;
  EpgDaoManager get managers => EpgDaoManager(this);
}

class EpgDaoManager {
  final _$EpgDaoMixin _db;
  EpgDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$EpgProgramsTableTableManager get epgPrograms =>
      $$EpgProgramsTableTableManager(_db.attachedDatabase, _db.epgPrograms);
}
