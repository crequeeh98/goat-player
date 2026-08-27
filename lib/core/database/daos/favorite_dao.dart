import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'favorite_dao.g.dart';

@DriftAccessor(tables: [Favorites])
class FavoriteDao extends DatabaseAccessor<AppDatabase> with _$FavoriteDaoMixin {
  FavoriteDao(AppDatabase db) : super(db);

  Stream<bool> isFavorite(int accountId, String streamId, String streamType) {
    return (select(favorites)
          ..where((f) => f.accountId.equals(accountId) & f.streamId.equals(streamId) & f.streamType.equals(streamType)))
        .watchSingleOrNull()
        .map((favorite) => favorite != null);
  }

  Future<void> toggleFavorite(int accountId, String streamId, String streamType) async {
    final existing = await (select(favorites)
          ..where((f) => f.accountId.equals(accountId) & f.streamId.equals(streamId) & f.streamType.equals(streamType)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(favorites)
            ..where((f) => f.accountId.equals(accountId) & f.streamId.equals(streamId) & f.streamType.equals(streamType)))
          .go();
    } else {
      await into(favorites).insert(FavoritesCompanion.insert(
        accountId: accountId,
        streamId: streamId,
        streamType: streamType,
      ));
    }
  }
}
