import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

class FavoriteQuery {
  final String streamId;
  final String streamType;

  FavoriteQuery({required this.streamId, required this.streamType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteQuery &&
          runtimeType == other.runtimeType &&
          streamId == other.streamId &&
          streamType == other.streamType;

  @override
  int get hashCode => streamId.hashCode ^ streamType.hashCode;
}

final isFavoriteProvider = StreamProvider.family.autoDispose<bool, FavoriteQuery>((ref, query) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return Stream.value(false);

  final db = ref.watch(databaseProvider);
  return db.favoriteDao.isFavorite(account.id, query.streamId, query.streamType);
});

final favoriteStreamIdsProvider = StreamProvider.family.autoDispose<Set<String>, String>((ref, streamType) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return Stream.value(<String>{});

  final db = ref.watch(databaseProvider);
  return db.favoriteDao.watchFavoriteStreamIds(account.id, streamType);
});
