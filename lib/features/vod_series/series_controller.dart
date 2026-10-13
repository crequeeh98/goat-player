import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart';
import '../../core/utils/title_sanitizer.dart';
import '../../core/settings/locale_controller.dart';

final seriesCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(categoryDaoProvider);
  return dao.watchCategories(account.id, 'series').map((list) {
    final favoritesCat = Category(
      id: -1, 
      accountId: account.id, 
      categoryId: 'favorites', 
      name: 'Watchlist', 
      type: 'series'
    );
    final seen = <String>{'favorites'};
    final uniqueList = list.where((c) => seen.add(c.categoryId)).toList();
    return [favoritesCat, ...uniqueList];
  });
});

final seriesStreamsProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, categoryId) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(streamDaoProvider);
  if (categoryId == 'favorites') {
    return dao.watchFavoriteStreams(account.id, 'series');
  }
  return dao.watchStreamsByCategory(account.id, categoryId);
});

final seriesSearchProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, query) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(streamDaoProvider);
  return dao.watchStreamsByQuery(account.id, 'series', query);
});

final seriesControllerProvider = Provider<SeriesController>((ref) {
  return SeriesController(ref);
});

class SeriesController {
  final Ref _ref;
  
  SeriesController(this._ref);

  Future<void> syncSeriesCategories({bool force = false}) async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    final prefs = _ref.read(sharedPreferencesProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSync = prefs.getInt('last_sync_categories_series_${account.id}') ?? 0;
    if (!force && (nowMs - lastSync < 6 * 60 * 60 * 1000)) {
      debugPrint('Series categories synced recently. Skipping.');
      return;
    }

    try {
      debugPrint('Syncing Series categories...');
      final rawCategories = await client.getSeriesCategories();
      debugPrint('Series categories raw response length: ${rawCategories.length}');
      
      final dao = _ref.read(categoryDaoProvider);
      
      final seenIds = <String>{};
      final companions = <CategoriesCompanion>[];
      for (final c in rawCategories) {
        final catId = c['category_id'].toString();
        if (seenIds.add(catId)) {
          companions.add(CategoriesCompanion.insert(
            accountId: account.id,
            categoryId: catId,
            name: c['category_name'].toString(),
            type: 'series',
          ));
        }
      }
      
      await dao.replaceCategories(account.id, 'series', companions);
      await prefs.setInt('last_sync_categories_series_${account.id}', nowMs);
    } catch (e) {
      debugPrint('Failed to sync series categories: $e');
    }
  }

  Future<void> syncSeriesStreams(String categoryId) async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    try {
      debugPrint('Syncing Series streams for category: $categoryId...');
      final rawStreams = await client.getSeries(categoryId: categoryId);
      debugPrint('Series streams raw response length: ${rawStreams.length}');
      
      final dao = _ref.read(streamDaoProvider);
      
      final companions = rawStreams.map((s) {
        final seriesId = s['series_id']?.toString() ?? s['stream_id']?.toString() ?? 'unknown';
        final icon = s['cover']?.toString() ?? s['stream_icon']?.toString();
        final added = _parseAdded(s['last_modified'] ?? s['added']);
        return StreamsCompanion.insert(
          accountId: account.id,
          streamId: seriesId,
          name: TitleSanitizer.sanitize(s['name']?.toString() ?? 'Unknown'),
          streamType: 'series',
          categoryId: categoryId,
          streamIcon: icon != null && icon.isNotEmpty ? Value(icon) : const Value.absent(),
          added: added != null ? Value(added) : const Value.absent(),
        );
      }).toList();
      
      await dao.replaceStreamsByCategory(account.id, categoryId, companions);
    } catch (e) {
      debugPrint('Failed to sync series streams: $e');
    }
  }

  bool _isSyncingAll = false;

  Future<void> syncAllSeriesStreams({bool force = false}) async {
    if (_isSyncingAll) return;
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    final prefs = _ref.read(sharedPreferencesProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSync = prefs.getInt('last_sync_all_series_${account.id}') ?? 0;
    if (!force && (nowMs - lastSync < 12 * 60 * 60 * 1000)) {
      debugPrint('Series streams were synced recently (${(nowMs - lastSync) ~/ (60 * 1000)}m ago). Skipping full sync.');
      return;
    }

    _isSyncingAll = true;
    try {
      debugPrint('Syncing ALL Series streams...');
      final rawStreams = await client.getSeries();
      debugPrint('ALL Series streams raw response length: ${rawStreams.length}');
      
      final dao = _ref.read(streamDaoProvider);
      
      final companions = await compute(_mapSeriesStreams, {'accountId': account.id, 'streams': rawStreams});
      
      await dao.replaceStreamsByType(account.id, 'series', companions);
      await prefs.setInt('last_sync_all_series_${account.id}', nowMs);
      debugPrint('Finished syncing ALL Series streams.');
    } catch (e) {
      debugPrint('Failed to sync all series streams: $e');
    } finally {
      _isSyncingAll = false;
    }
  }
}

int? _parseAdded(dynamic val) {
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

// Top-level function for compute
List<StreamsCompanion> _mapSeriesStreams(Map<String, dynamic> data) {
  final int accountId = data['accountId'];
  final List<dynamic> rawStreams = data['streams'];
  return rawStreams.map((s) {
    final seriesId = s['series_id']?.toString() ?? s['stream_id']?.toString() ?? 'unknown';
    final icon = s['cover']?.toString() ?? s['stream_icon']?.toString();
    final added = _parseAdded(s['last_modified'] ?? s['added']);
    return StreamsCompanion.insert(
      accountId: accountId,
      streamId: seriesId,
      name: TitleSanitizer.sanitize(s['name']?.toString() ?? 'Unknown'),
      streamType: 'series',
      categoryId: s['category_id']?.toString() ?? 'unknown',
      streamIcon: icon != null && icon.isNotEmpty ? Value(icon) : const Value.absent(),
      added: added != null ? Value(added) : const Value.absent(),
    );
  }).toList();
}

