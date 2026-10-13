import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../../main.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart';
import '../../core/utils/title_sanitizer.dart';
import '../../core/settings/locale_controller.dart';

class SelectedLiveCategory extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}
final selectedLiveCategoryProvider = NotifierProvider<SelectedLiveCategory, String?>(SelectedLiveCategory.new);

class SelectedLiveStream extends Notifier<StreamItem?> {
  @override
  StreamItem? build() => null;
  void set(StreamItem? value) => state = value;
}
final selectedLiveStreamProvider = NotifierProvider<SelectedLiveStream, StreamItem?>(SelectedLiveStream.new);

class IsLiveFullWidth extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
  void toggle() => state = !state;
}
final isLiveFullWidthProvider = NotifierProvider<IsLiveFullWidth, bool>(IsLiveFullWidth.new);

class SyncingCategories extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void add(String categoryId) {
    state = {...state, categoryId};
  }

  void remove(String categoryId) {
    state = state.where((id) => id != categoryId).toSet();
  }
}
final syncingCategoriesProvider = NotifierProvider<SyncingCategories, Set<String>>(SyncingCategories.new);

final liveCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(categoryDaoProvider);
  return dao.watchCategories(account.id, 'live').map((list) {
    final favoritesCat = Category(
      id: -1, 
      accountId: account.id, 
      categoryId: 'favorites', 
      name: 'Favorites', 
      type: 'live'
    );
    final seen = <String>{'favorites'};
    final uniqueList = list.where((c) => seen.add(c.categoryId)).toList();
    return [favoritesCat, ...uniqueList];
  });
});

final liveStreamsProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, categoryId) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(streamDaoProvider);
  if (categoryId == 'favorites') {
    return dao.watchFavoriteStreams(account.id, 'live');
  }
  return dao.watchStreamsByCategory(account.id, categoryId);
});

final liveTvSearchProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, query) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(streamDaoProvider);
  return dao.watchStreamsByQuery(account.id, 'live', query);
});

final liveTvControllerProvider = Provider<LiveTvController>((ref) {
  return LiveTvController(ref);
});

class LiveTvController {
  final Ref _ref;
  
  LiveTvController(this._ref);

  Future<void> syncLiveCategories({bool force = false}) async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    final prefs = _ref.read(sharedPreferencesProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSync = prefs.getInt('last_sync_categories_live_${account.id}') ?? 0;
    if (!force && (nowMs - lastSync < 6 * 60 * 60 * 1000)) {
      debugPrint('Live categories synced recently. Skipping.');
      return;
    }

    try {
      final rawCategories = await client.getLiveCategories();
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
            type: 'live',
          ));
        }
      }
      
      await dao.replaceCategories(account.id, 'live', companions);
      await prefs.setInt('last_sync_categories_live_${account.id}', nowMs);
    } catch (e) {
      debugPrint('Failed to sync live categories: $e');
    }
  }

  Future<void> syncLiveStreams(String categoryId) async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    _ref.read(syncingCategoriesProvider.notifier).add(categoryId);
    try {
      final rawStreams = await client.getLiveStreams(categoryId: categoryId);
      final dao = _ref.read(streamDaoProvider);
      
      final companions = rawStreams.map((s) {
        return StreamsCompanion.insert(
          accountId: account.id,
          categoryId: s['category_id'].toString(),
          streamId: s['stream_id'].toString(),
          epgChannelId: s['epg_channel_id'] != null ? Value(s['epg_channel_id'].toString()) : const Value.absent(),
          name: TitleSanitizer.sanitizeLiveTvChannel(s['name']?.toString() ?? 'Unknown'),
          streamType: 'live',
          streamIcon: s['stream_icon'] != null ? Value(s['stream_icon'].toString()) : const Value.absent(),
        );
      }).toList();
      
      await dao.replaceStreamsByCategory(account.id, categoryId, companions);
    } catch (e) {
      debugPrint('Failed to sync live streams: $e');
    } finally {
      _ref.read(syncingCategoriesProvider.notifier).remove(categoryId);
    }
  }

  bool _isSyncingAll = false;

  Future<void> syncAllLiveStreams({bool force = false}) async {
    if (_isSyncingAll) return;
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    final prefs = _ref.read(sharedPreferencesProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSync = prefs.getInt('last_sync_all_live_${account.id}') ?? 0;
    if (!force && (nowMs - lastSync < 12 * 60 * 60 * 1000)) {
      debugPrint('Live streams were synced recently (${(nowMs - lastSync) ~/ (60 * 1000)}m ago). Skipping full sync.');
      return;
    }

    _isSyncingAll = true;
    try {
      debugPrint('Syncing ALL Live streams...');
      final rawStreams = await client.getLiveStreams();
      debugPrint('ALL Live streams raw response length: ${rawStreams.length}');
      
      final dao = _ref.read(streamDaoProvider);
      
      final companions = await compute(_mapLiveStreams, {'accountId': account.id, 'streams': rawStreams});
      
      await dao.replaceStreamsByType(account.id, 'live', companions);
      await prefs.setInt('last_sync_all_live_${account.id}', nowMs);
      debugPrint('Finished syncing ALL Live streams.');
    } catch (e) {
      debugPrint('Failed to sync all live streams: $e');
    } finally {
      _isSyncingAll = false;
    }
  }
}

// Top-level function for compute
List<StreamsCompanion> _mapLiveStreams(Map<String, dynamic> data) {
  final int accountId = data['accountId'];
  final List<dynamic> rawStreams = data['streams'];
  return rawStreams.map((s) {
    return StreamsCompanion.insert(
      accountId: accountId,
      streamId: s['stream_id']?.toString() ?? 'unknown',
      epgChannelId: s['epg_channel_id'] != null && s['epg_channel_id'].toString().isNotEmpty 
          ? Value(s['epg_channel_id'].toString()) 
          : const Value.absent(),
      name: TitleSanitizer.sanitizeLiveTvChannel(s['name']?.toString() ?? 'Unknown'),
      streamType: 'live',
      categoryId: s['category_id']?.toString() ?? 'unknown',
      streamIcon: s['stream_icon'] != null && s['stream_icon'].toString().isNotEmpty 
          ? Value(s['stream_icon'].toString()) 
          : const Value.absent(),
    );
  }).toList();
}
