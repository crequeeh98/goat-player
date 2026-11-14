import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../database/app_database.dart';
import '../settings/locale_controller.dart';
import 'title_sanitizer.dart';

class SyncingVodCategories extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void add(String key) {
    state = {...state, key};
  }

  void remove(String key) {
    state = state.where((k) => k != key).toSet();
  }
}

final syncingVodCategoriesProvider =
    NotifierProvider<SyncingVodCategories, Set<String>>(SyncingVodCategories.new);

class VodSyncHelper {
  static const int _categorySyncCooldownMs = 10 * 60 * 1000;
  static final Map<String, int> _categorySyncedAtMs = {};

  static void clearCategorySyncCooldown([int? accountId]) {
    if (accountId == null) {
      _categorySyncedAtMs.clear();
    } else {
      final prefix = '${accountId}_';
      _categorySyncedAtMs.removeWhere((key, _) => key.startsWith(prefix));
    }
  }

  static int? parseAdded(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is String) {
      final parsedInt = int.tryParse(val);
      if (parsedInt != null) return parsedInt;
      final parsedDate = DateTime.tryParse(val);
      if (parsedDate != null) return parsedDate.millisecondsSinceEpoch ~/ 1000;
    }
    return null;
  }

  static StreamsCompanion mapStreamItem({
    required int accountId,
    required Map<String, dynamic> raw,
    required String streamType,
    String? fallbackCategoryId,
  }) {
    final streamId = streamType == 'series'
        ? (raw['series_id']?.toString() ?? raw['stream_id']?.toString() ?? 'unknown')
        : (raw['stream_id']?.toString() ?? 'unknown');

    final icon = streamType == 'series'
        ? (raw['cover']?.toString() ?? raw['stream_icon']?.toString())
        : raw['stream_icon']?.toString();

    final addedVal = streamType == 'series'
        ? (raw['last_modified'] ?? raw['added'])
        : raw['added'];
    final added = parseAdded(addedVal);

    final categoryId = raw['category_id']?.toString() ?? fallbackCategoryId ?? 'unknown';

    return StreamsCompanion.insert(
      accountId: accountId,
      streamId: streamId,
      name: TitleSanitizer.sanitize(raw['name']?.toString() ?? 'Unknown'),
      streamType: streamType,
      categoryId: categoryId,
      streamIcon: icon != null && icon.isNotEmpty ? Value(icon) : const Value.absent(),
      added: added != null ? Value(added) : const Value.absent(),
    );
  }

  static List<StreamsCompanion> mapStreamsCompute(Map<String, dynamic> data) {
    final int accountId = data['accountId'];
    final String streamType = data['streamType'];
    final String? fallbackCategoryId = data['fallbackCategoryId'] as String?;
    final List<dynamic> rawStreams = data['streams'];
    return rawStreams.map((s) => mapStreamItem(
      accountId: accountId,
      raw: Map<String, dynamic>.from(s as Map),
      streamType: streamType,
      fallbackCategoryId: fallbackCategoryId,
    )).toList();
  }

  static Future<void> syncCategories(
    Ref ref, {
    required String type,
    bool force = false,
    bool rethrowOnError = false,
  }) async {
    final client = ref.read(xtreamClientProvider);
    final account = ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    final isEnabled = type == 'movie' ? account.syncMovies : account.syncSeries;
    if (!isEnabled) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSyncKey = 'last_sync_categories_${type == 'movie' ? 'vod' : 'series'}_${account.id}';
    final lastSync = prefs.getInt(lastSyncKey) ?? 0;
    if (!force && (nowMs - lastSync < 6 * 60 * 60 * 1000)) {
      debugPrint('$type categories synced recently. Skipping.');
      return;
    }

    try {
      debugPrint('Syncing $type categories...');
      final rawCategories = type == 'movie'
          ? await client.getVodCategories()
          : await client.getSeriesCategories();
      debugPrint('$type categories raw response length: ${rawCategories.length}');

      final dao = ref.read(categoryDaoProvider);
      final seenIds = <String>{};
      final companions = <CategoriesCompanion>[];
      for (final c in rawCategories) {
        final catId = c['category_id'].toString();
        if (seenIds.add(catId)) {
          companions.add(CategoriesCompanion.insert(
            accountId: account.id,
            categoryId: catId,
            name: c['category_name'].toString(),
            type: type,
          ));
        }
      }

      await dao.replaceCategories(account.id, type, companions);
      await prefs.setInt(lastSyncKey, nowMs);
    } catch (e) {
      debugPrint('Failed to sync $type categories: $e');
      if (rethrowOnError) rethrow;
    }
  }

  static Future<void> syncCategoryStreams(
    Ref ref, {
    required String type,
    required String categoryId,
    bool force = false,
  }) async {
    final client = ref.read(xtreamClientProvider);
    final account = ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    final isEnabled = type == 'movie' ? account.syncMovies : account.syncSeries;
    if (!isEnabled) return;

    final syncingKey = '${type}_$categoryId';
    final syncingNotifier = ref.read(syncingVodCategoriesProvider.notifier);
    syncingNotifier.add(syncingKey);

    try {
      final dao = ref.read(streamDaoProvider);
      final key = '${account.id}_${type}_$categoryId';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!force) {
        final lastMs = _categorySyncedAtMs[key] ?? 0;
        if (nowMs - lastMs < _categorySyncCooldownMs) {
          final existingCount = await dao.countStreamsByCategory(account.id, categoryId);
          if (existingCount > 0) {
            debugPrint('$type streams for category $categoryId synced recently ($existingCount cached). Skipping.');
            return;
          }
        }
      }

      debugPrint('Syncing $type streams for category: $categoryId...');
      final rawStreams = type == 'movie'
          ? await client.getVodStreams(categoryId: categoryId)
          : await client.getSeries(categoryId: categoryId);
      debugPrint('$type streams raw response length: ${rawStreams.length}');

      final payload = {
        'accountId': account.id,
        'streamType': type,
        'fallbackCategoryId': categoryId,
        'streams': rawStreams,
      };
      final companions = rawStreams.length > 150
          ? await compute(mapStreamsCompute, payload)
          : mapStreamsCompute(payload);

      await dao.replaceStreamsByCategory(account.id, categoryId, companions);
      _categorySyncedAtMs[key] = DateTime.now().millisecondsSinceEpoch;
      if (companions.isNotEmpty) {
        // Wait for Drift's live stream to emit the newly inserted rows before clearing the spinner
        // so the empty-state message never flashes for a split second.
        await dao
            .watchStreamsByCategory(account.id, categoryId)
            .firstWhere((list) => list.isNotEmpty)
            .timeout(const Duration(milliseconds: 600), onTimeout: () => const []);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('Failed to sync $type streams: $e');
    } finally {
      syncingNotifier.remove(syncingKey);
    }
  }

  static Future<void> syncAllStreams(
    Ref ref, {
    required String type,
    bool force = false,
    bool rethrowOnError = false,
  }) async {
    final client = ref.read(xtreamClientProvider);
    final account = ref.read(activeAccountProvider);
    if (client == null || account == null || account.username.isEmpty || account.serverUrl.contains('.m3u')) return;
    final isEnabled = type == 'movie' ? account.syncMovies : account.syncSeries;
    if (!isEnabled) return;

    final syncingAllKey = 'all_$type';
    final syncingNotifier = ref.read(syncingVodCategoriesProvider.notifier);
    syncingNotifier.add(syncingAllKey);

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final dao = ref.read(streamDaoProvider);
      final existingCount = await dao.countStreamsByType(account.id, type);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastSyncKey = 'last_sync_all_${type == 'movie' ? 'vod' : 'series'}_${account.id}';
      final lastSync = prefs.getInt(lastSyncKey) ?? 0;
      if (!force && existingCount > 0 && (nowMs - lastSync < 24 * 60 * 60 * 1000)) {
        debugPrint('$type streams were synced recently ($existingCount streams cached). Skipping full sync.');
        return;
      }
      if (force) {
        final typePrefix = '${account.id}_${type}_';
        _categorySyncedAtMs.removeWhere((k, _) => k.startsWith(typePrefix));
      }

      debugPrint('Syncing ALL $type streams...');
      final rawStreams = type == 'movie'
          ? await client.getVodStreams()
          : await client.getSeries();
      debugPrint('ALL $type streams raw response length: ${rawStreams.length}');

      final companions = await compute(mapStreamsCompute, {
        'accountId': account.id,
        'streamType': type,
        'streams': rawStreams,
      });

      await dao.replaceStreamsByType(account.id, type, companions);
      await prefs.setInt(lastSyncKey, nowMs);
      if (companions.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      debugPrint('Finished syncing ALL $type streams.');
    } catch (e) {
      debugPrint('Failed to sync all $type streams: $e');
      if (rethrowOnError) rethrow;
    } finally {
      syncingNotifier.remove(syncingAllKey);
    }
  }

  static Stream<List<Category>> watchCategories(Ref ref, String type) {
    return ref.watch(managedCategoriesProvider(type)).when(
      data: (items) => Stream.value(
        items.where((item) => !item.isHidden).map((item) => item.category).toList(),
      ),
      loading: () => const Stream.empty(),
      error: (_, __) => const Stream.empty(),
    );
  }

  static Stream<List<StreamItem>> watchStreamsByCategory(Ref ref, String type, String categoryId) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const Stream.empty();

    if (categoryId == 'favorites') {
      final dao = ref.watch(streamDaoProvider);
      return dao.watchFavoriteStreams(account.id, type);
    }
    if (categoryId.startsWith('custom_list:')) {
      final listId = int.tryParse(categoryId.substring('custom_list:'.length)) ?? -1;
      final customDao = ref.watch(customListDaoProvider);
      return customDao.watchStreamsForCustomList(listId, account.id);
    }
    final dao = ref.watch(streamDaoProvider);
    return dao.watchStreamsByCategory(account.id, categoryId);
  }

  static final Set<String> _tvSearchSynced = {};

  static Stream<List<StreamItem>> watchStreamsByQuery(Ref ref, String type, String query) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const Stream.empty();

    // Lazily fetch full library if not yet cached when search is first used
    if (_tvSearchSynced.add('${account.id}_$type')) {
      Future(() => syncAllStreams(ref, type: type));
    }

    final dao = ref.watch(streamDaoProvider);
    return dao.watchStreamsByQuery(account.id, type, query);
  }
}
