// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_progress_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaybackProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $PlaybackProgressTable get playbackProgress =>
      attachedDatabase.playbackProgress;
  $StreamsTable get streams => attachedDatabase.streams;
  PlaybackProgressDaoManager get managers => PlaybackProgressDaoManager(this);
}

class PlaybackProgressDaoManager {
  final _$PlaybackProgressDaoMixin _db;
  PlaybackProgressDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(
        _db.attachedDatabase,
        _db.playbackProgress,
      );
  $$StreamsTableTableManager get streams =>
      $$StreamsTableTableManager(_db.attachedDatabase, _db.streams);
}
