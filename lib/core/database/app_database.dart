import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'connection/connection.dart' as connection;

import 'tables.dart';
import '../utils/platform_utils.dart';
import 'daos/account_dao.dart';
import 'daos/category_dao.dart';
import 'daos/stream_dao.dart';
import 'daos/epg_dao.dart';
import 'daos/playback_progress_dao.dart';
import 'daos/favorite_dao.dart';
import 'daos/category_preference_dao.dart';
import 'daos/custom_list_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Streams,
    EpgPrograms,
    Favorites,
    PlaybackProgress,
    CategoryPreferences,
    CustomLists,
    CustomListItems,
  ],
  daos: [
    AccountDao,
    CategoryDao,
    StreamDao,
    EpgDao,
    PlaybackProgressDao,
    FavoriteDao,
    CategoryPreferenceDao,
    CustomListDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? connection.openConnection());

  @override
  int get schemaVersion => 10;

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
          if (from < 6) {
            await m.addColumn(streams, streams.added);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_streams_account_added ON streams(account_id, category_id, added);');
          }
          if (from < 7) {
            await m.addColumn(playbackProgress, playbackProgress.season);
            await m.addColumn(playbackProgress, playbackProgress.episode);
            await m.addColumn(playbackProgress, playbackProgress.episodeTitle);
            await m.addColumn(playbackProgress, playbackProgress.isCompleted);
          }
          if (from < 8) {
            await m.addColumn(playbackProgress, playbackProgress.accountId);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_playback_progress_account ON playback_progress(account_id, stream_type);');
          }
          if (from < 9) {
            await m.addColumn(accounts, accounts.syncLiveTv);
            await m.addColumn(accounts, accounts.syncMovies);
            await m.addColumn(accounts, accounts.syncSeries);
            await m.createTable(categoryPreferences);
            await m.createTable(customLists);
            await m.createTable(customListItems);
            await customStatement('CREATE INDEX IF NOT EXISTS idx_cat_pref_lookup ON category_preferences(account_id, type, is_hidden);');
            await customStatement('CREATE INDEX IF NOT EXISTS idx_custom_lists ON custom_lists(account_id, type);');
            await customStatement('CREATE INDEX IF NOT EXISTS idx_custom_list_items ON custom_list_items(list_id);');
          }
          if (from < 10) {
            await m.addColumn(favorites, favorites.sortOrder);
          }
        },
        beforeOpen: (details) async {
          try {
            await customStatement('PRAGMA journal_mode = WAL;');
            await customStatement('PRAGMA synchronous = NORMAL;');
            await customStatement(GoatPlatform.isTv || GoatPlatform.isMobile
                ? 'PRAGMA cache_size = -16000;' // 16MB RAM cache on constrained mobile/TV devices
                : 'PRAGMA cache_size = -64000;'); // 64MB RAM cache on desktop
            await customStatement('PRAGMA temp_store = MEMORY;');
          } catch (e) {
            debugPrint('Note: WAL / memory cache PRAGMA not supported on this platform: $e');
          }
          await customStatement('CREATE INDEX IF NOT EXISTS idx_categories_account_type ON categories(account_id, type);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_streams_account_cat ON streams(account_id, category_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_streams_account_type ON streams(account_id, stream_type);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_streams_account_added ON streams(account_id, category_id, added);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_epg_channel_time ON epg_programs(account_id, channel_id, start_time, stop_time);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_favorites_lookup ON favorites(account_id, stream_id, stream_type);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_cat_pref_lookup ON category_preferences(account_id, type, is_hidden);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_custom_lists ON custom_lists(account_id, type);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_custom_list_items ON custom_list_items(list_id);');
        },
      );
}
