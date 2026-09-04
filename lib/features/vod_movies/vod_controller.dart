import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' hide Category;
import '../../main.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart';
import '../../core/utils/title_sanitizer.dart';

final vodCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(categoryDaoProvider);
  return dao.watchCategories(account.id, 'movie').map((list) {
    final favoritesCat = Category(
      id: -1, 
      accountId: account.id, 
      categoryId: 'favorites', 
      name: 'Watchlist', 
      type: 'movie'
    );
    final seen = <String>{'favorites'};
    final uniqueList = list.where((c) => seen.add(c.categoryId)).toList();
    return [favoritesCat, ...uniqueList];
  });
});

final vodStreamsProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, categoryId) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(streamDaoProvider);
  if (categoryId == 'favorites') {
    return dao.watchFavoriteStreams(account.id, 'movie');
  }
  return dao.watchStreamsByCategory(account.id, categoryId);
});

final vodSearchProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, query) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(streamDaoProvider);
  return dao.watchStreamsByQuery(account.id, 'movie', query);
});

final vodControllerProvider = Provider<VodController>((ref) {
  return VodController(ref);
});

class VodController {
  final Ref _ref;
  
  VodController(this._ref);

  Future<void> syncVodCategories() async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    try {
      debugPrint('Syncing VOD categories...');
      final rawCategories = await client.getVodCategories();
      debugPrint('VOD categories raw response length: ${rawCategories.length}');
      
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
            type: 'movie',
          ));
        }
      }
      
      await dao.replaceCategories(account.id, 'movie', companions);
    } catch (e) {
      debugPrint('Failed to sync vod categories: $e');
    }
  }

  Future<void> syncVodStreams(String categoryId) async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    try {
      debugPrint('Syncing VOD streams for category: $categoryId...');
      final rawStreams = await client.getVodStreams(categoryId: categoryId);
      debugPrint('VOD streams raw response length: ${rawStreams.length}');
      
      final dao = _ref.read(streamDaoProvider);
      
      final companions = rawStreams.map((s) {
        return StreamsCompanion.insert(
          accountId: account.id,
          streamId: s['stream_id'].toString(),
          name: TitleSanitizer.sanitize(s['name']?.toString() ?? 'Unknown'),
          streamType: 'movie',
          categoryId: categoryId,
          streamIcon: s['stream_icon'] != null ? Value(s['stream_icon'].toString()) : const Value.absent(),
        );
      }).toList();
      
      await dao.replaceStreamsByCategory(account.id, categoryId, companions);
    } catch (e) {
      debugPrint('Failed to sync vod streams: $e');
    }
  }

  Future<void> syncAllVodStreams() async {
    final client = _ref.read(xtreamClientProvider);
    final account = _ref.read(activeAccountProvider);
    if (client == null || account == null) return;
    
    try {
      debugPrint('Syncing ALL VOD streams...');
      final rawStreams = await client.getVodStreams();
      debugPrint('ALL VOD streams raw response length: ${rawStreams.length}');
      
      final dao = _ref.read(streamDaoProvider);
      
      final companions = await compute(_mapVodStreams, {'accountId': account.id, 'streams': rawStreams});
      
      await dao.clearStreamsByType(account.id, 'movie');
      await dao.insertStreams(companions);
      debugPrint('Finished syncing ALL VOD streams.');
    } catch (e) {
      debugPrint('Failed to sync all vod streams: $e');
    }
  }
}

// Top-level function for compute
List<StreamsCompanion> _mapVodStreams(Map<String, dynamic> data) {
  final int accountId = data['accountId'];
  final List<dynamic> rawStreams = data['streams'];
  return rawStreams.map((s) {
    return StreamsCompanion.insert(
      accountId: accountId,
      streamId: s['stream_id']?.toString() ?? 'unknown',
      name: TitleSanitizer.sanitize(s['name']?.toString() ?? 'Unknown'),
      streamType: 'movie',
      categoryId: s['category_id']?.toString() ?? 'unknown',
      streamIcon: s['stream_icon'] != null && s['stream_icon'].toString().isNotEmpty 
          ? Value(s['stream_icon'].toString()) 
          : const Value.absent(),
    );
  }).toList();
}

