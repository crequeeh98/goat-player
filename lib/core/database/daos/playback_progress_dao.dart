import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'playback_progress_dao.g.dart';

@DriftAccessor(tables: [PlaybackProgress])
class PlaybackProgressDao extends DatabaseAccessor<AppDatabase> with _$PlaybackProgressDaoMixin {
  PlaybackProgressDao(super.db);

  Future<void> upsertProgress(PlaybackProgressItem item) async {
    final isCompleted = item.isCompleted || (item.duration > 0 && (item.position / item.duration) >= 0.95);
    final updatedItem = item.copyWith(
      isCompleted: isCompleted,
      position: isCompleted ? item.duration : item.position,
    );
    await into(playbackProgress).insertOnConflictUpdate(updatedItem);
  }

  Future<void> markCompleted(String streamId) async {
    final existing = await getProgress(streamId);
    if (existing != null) {
      await into(playbackProgress).insertOnConflictUpdate(
        existing.copyWith(
          isCompleted: true,
          position: existing.duration,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> deleteProgress(String streamId) =>
      (delete(playbackProgress)..where((t) => t.streamId.equals(streamId))).go();

  Future<void> deleteSeriesProgress(String seriesId) =>
      (delete(playbackProgress)..where((t) => t.seriesId.equals(seriesId))).go();

  Future<PlaybackProgressItem?> getProgress(String streamId) =>
      (select(playbackProgress)..where((t) => t.streamId.equals(streamId))).getSingleOrNull();

  Stream<List<PlaybackProgressItem>> watchInProgress(String type) =>
      (select(playbackProgress)
            ..where((t) => t.streamType.equals(type))
            ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
          .watch();
          
  Future<List<PlaybackProgressItem>> getEpisodesProgressForSeries(String seriesId) =>
      (select(playbackProgress)..where((t) => t.seriesId.equals(seriesId))).get();

  Future<PlaybackProgressItem?> getLastWatchedForSeries(String seriesId) =>
      (select(playbackProgress)
            ..where((t) => t.seriesId.equals(seriesId))
            ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();
}
