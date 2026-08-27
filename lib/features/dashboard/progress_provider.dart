import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/main.dart';

final inProgressMoviesProvider = StreamProvider<List<PlaybackProgressItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.playbackProgressDao.watchInProgress('movie');
});

final inProgressSeriesProvider = StreamProvider<List<PlaybackProgressItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.playbackProgressDao.watchInProgress('series');
});

