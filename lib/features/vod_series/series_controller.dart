import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/vod_sync_helper.dart';

final seriesCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return VodSyncHelper.watchCategories(ref, 'series');
});

final seriesStreamsProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, categoryId) {
  return VodSyncHelper.watchStreamsByCategory(ref, 'series', categoryId);
});

final seriesSearchProvider = StreamProvider.family.autoDispose<List<StreamItem>, String>((ref, query) {
  return VodSyncHelper.watchStreamsByQuery(ref, 'series', query);
});

final seriesControllerProvider = Provider<SeriesController>((ref) {
  return SeriesController(ref);
});

class SeriesController {
  final Ref _ref;
  bool _isSyncingAll = false;

  SeriesController(this._ref);

  Future<void> syncSeriesCategories({bool force = false}) =>
      VodSyncHelper.syncCategories(_ref, type: 'series', force: force);

  Future<void> syncSeriesStreams(String categoryId) =>
      VodSyncHelper.syncCategoryStreams(_ref, type: 'series', categoryId: categoryId);

  Future<void> syncAllSeriesStreams({bool force = false}) async {
    if (_isSyncingAll) return;
    _isSyncingAll = true;
    try {
      await VodSyncHelper.syncAllStreams(_ref, type: 'series', force: force);
    } finally {
      _isSyncingAll = false;
    }
  }
}
