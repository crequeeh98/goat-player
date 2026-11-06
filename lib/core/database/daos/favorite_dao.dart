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

  Stream<Set<String>> watchFavoriteStreamIds(int accountId, String streamType) {
    return (select(favorites)
          ..where((f) => f.accountId.equals(accountId) & f.streamType.equals(streamType)))
        .watch()
        .map((rows) => rows.map((r) => r.streamId).toSet());
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
      final countExp = favorites.id.count();
      final count = await (selectOnly(favorites)
            ..addColumns([countExp])
            ..where(favorites.accountId.equals(accountId) & favorites.streamType.equals(streamType)))
          .map((row) => row.read(countExp))
          .getSingle();

      await into(favorites).insert(FavoritesCompanion.insert(
        accountId: accountId,
        streamId: streamId,
        streamType: streamType,
        sortOrder: Value(count ?? 0),
      ));
    }
  }

  Future<void> reorderFavorites(int accountId, String streamType, List<String> orderedStreamIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedStreamIds.length; i++) {
        await (update(favorites)
              ..where((f) => f.accountId.equals(accountId) & f.streamType.equals(streamType) & f.streamId.equals(orderedStreamIds[i])))
            .write(FavoritesCompanion(sortOrder: Value(i)));
      }
    });
  }
}
