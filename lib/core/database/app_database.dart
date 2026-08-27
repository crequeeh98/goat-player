import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'tables.dart';
import 'daos/account_dao.dart';
import 'daos/category_dao.dart';
import 'daos/stream_dao.dart';
import 'daos/epg_dao.dart';
import 'daos/playback_progress_dao.dart';

import 'daos/favorite_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Accounts, Categories, Streams, EpgPrograms, Favorites, PlaybackProgress],
  daos: [AccountDao, CategoryDao, StreamDao, EpgDao, PlaybackProgressDao, FavoriteDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(streams, streams.epgChannelId);
          }
          if (from < 3) {
            await m.addColumn(accounts, accounts.playlistName);
          }
          if (from < 4) {
            await m.createTable(playbackProgress);
          }
          if (from < 5) {
            await customStatement('DROP TABLE IF EXISTS favorites;');
            await m.createTable(favorites);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'goat_player_db',
      native: const DriftNativeOptions(
        databaseDirectory: _getDatabaseDirectory,
      ),
    );
  }

  static Future<Directory> _getDatabaseDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/goat_player');
  }
}
