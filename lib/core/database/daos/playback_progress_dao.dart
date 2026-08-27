import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'playback_progress_dao.g.dart';

@DriftAccessor(tables: [PlaybackProgress])
class PlaybackProgressDao extends DatabaseAccessor<AppDatabase> with _$PlaybackProgressDaoMixin {
  PlaybackProgressDao(super.db);

  Future<void> upsertProgress(PlaybackProgressItem item) async {
    // If progress is >= 90%, remove it instead of saving
    if (item.duration > 0 && (item.position / item.duration) >= 0.90) {
      await deleteProgress(item.streamId);
    } else {
      await into(playbackProgress).insertOnConflictUpdate(item);
    }
  }

  Future<void> deleteProgress(String streamId) =>
      (delete(playbackProgress)..where((t) => t.streamId.equals(streamId))).go();

  Future<PlaybackProgressItem?> getProgress(String streamId) =>
      (select(playbackProgress)..where((t) => t.streamId.equals(streamId))).getSingleOrNull();

  Stream<List<PlaybackProgressItem>> watchInProgress(String type) =>
      (select(playbackProgress)
            ..where((t) => t.streamType.equals(type))
            ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
          .watch();
          
  Future<List<PlaybackProgressItem>> getEpisodesProgressForSeries(String seriesId) =>
      (select(playbackProgress)..where((t) => t.seriesId.equals(seriesId))).get();
}
