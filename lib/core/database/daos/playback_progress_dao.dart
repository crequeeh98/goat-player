import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'playback_progress_dao.g.dart';

@DriftAccessor(tables: [PlaybackProgress, Streams])
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

  Future<void> markCompleted(String streamId, {int? accountId}) async {
    final existing = await getProgress(streamId, accountId: accountId);
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

  Future<void> deleteProgress(String streamId, {int? accountId}) {
    final query = delete(playbackProgress)..where((t) => t.streamId.equals(streamId));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId) | t.accountId.isNull());
    }
    return query.go();
  }

  Future<void> deleteSeriesProgress(String seriesId, {int? accountId}) {
    final query = delete(playbackProgress)..where((t) => t.seriesId.equals(seriesId));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId) | t.accountId.isNull());
    }
    return query.go();
  }

  Future<PlaybackProgressItem?> getProgress(String streamId, {int? accountId}) {
    final query = select(playbackProgress)..where((t) => t.streamId.equals(streamId));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId) | t.accountId.isNull());
    }
    return query.getSingleOrNull();
  }

  Stream<List<PlaybackProgressItem>> watchInProgress(String type, int accountId) {
    final query = customSelect(
      '''
      SELECT p.* FROM playback_progress p
      WHERE p.stream_type = ?
        AND (
          p.account_id = ?
          OR (
            p.account_id IS NULL AND (
              EXISTS (SELECT 1 FROM streams s WHERE s.account_id = ? AND s.stream_id = p.stream_id)
              OR (p.series_id IS NOT NULL AND EXISTS (SELECT 1 FROM streams s WHERE s.account_id = ? AND s.stream_id = p.series_id))
            )
          )
        )
      ORDER BY p.updated_at DESC
      ''',
      variables: [
        Variable.withString(type),
        Variable.withInt(accountId),
        Variable.withInt(accountId),
        Variable.withInt(accountId),
      ],
      readsFrom: {playbackProgress, streams},
    );

    return query.watch().map((rows) => rows.map((r) => playbackProgress.map(r.data)).toList());
  }

  Future<List<PlaybackProgressItem>> getEpisodesProgressForSeries(String seriesId, {int? accountId}) {
    final query = select(playbackProgress)..where((t) => t.seriesId.equals(seriesId));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId) | t.accountId.isNull());
    }
    return query.get();
  }

  Future<PlaybackProgressItem?> getLastWatchedForSeries(String seriesId, {int? accountId}) {
    final query = select(playbackProgress)..where((t) => t.seriesId.equals(seriesId));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId) | t.accountId.isNull());
    }
    query
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
      ..limit(1);
    return query.getSingleOrNull();
  }
}
