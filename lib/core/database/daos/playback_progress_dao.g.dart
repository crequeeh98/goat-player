// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_progress_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaybackProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaybackProgressTable get playbackProgress =>
      attachedDatabase.playbackProgress;
  PlaybackProgressDaoManager get managers => PlaybackProgressDaoManager(this);
}

class PlaybackProgressDaoManager {
  final _$PlaybackProgressDaoMixin _db;
  PlaybackProgressDaoManager(this._db);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(
        _db.attachedDatabase,
        _db.playbackProgress,
      );
}
