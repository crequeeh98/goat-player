import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/vod_sync_helper.dart';

final vodCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return VodSyncHelper.watchCategories(ref, 'movie');
});

final vodStreamsProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, categoryId) {
  return VodSyncHelper.watchStreamsByCategory(ref, 'movie', categoryId);
});

final vodSearchProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, query) {
  return VodSyncHelper.watchStreamsByQuery(ref, 'movie', query);
});

final vodControllerProvider = Provider<VodController>((ref) {
  return VodController(ref);
});

class VodController {
  final Ref _ref;
  bool _isSyncingAll = false;

  VodController(this._ref);

  Future<void> syncVodCategories({bool force = false}) =>
      VodSyncHelper.syncCategories(_ref, type: 'movie', force: force);

  Future<void> syncVodStreams(String categoryId) =>
      VodSyncHelper.syncCategoryStreams(_ref, type: 'movie', categoryId: categoryId);

  Future<void> syncAllVodStreams({bool force = false}) async {
    if (_isSyncingAll) return;
    _isSyncingAll = true;
    try {
      await VodSyncHelper.syncAllStreams(_ref, type: 'movie', force: force);
    } finally {
      _isSyncingAll = false;
    }
  }
}
