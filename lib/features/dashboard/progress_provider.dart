import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/main.dart';

final inProgressMoviesProvider = StreamProvider.autoDispose<List<PlaybackProgressItem>>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return Stream.value(<PlaybackProgressItem>[]);
  final db = ref.watch(databaseProvider);
  return db.playbackProgressDao.watchInProgress('movie', account.id);
});

final inProgressSeriesProvider = StreamProvider.autoDispose<List<PlaybackProgressItem>>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return Stream.value(<PlaybackProgressItem>[]);
  final db = ref.watch(databaseProvider);
  return db.playbackProgressDao.watchInProgress('series', account.id);
});

