import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'stream_dao.g.dart';

@DriftAccessor(tables: [Streams, Favorites])
class StreamDao extends DatabaseAccessor<AppDatabase> with _$StreamDaoMixin {
  StreamDao(AppDatabase db) : super(db);

  Future<void> insertStreams(List<StreamsCompanion> streamList) async {
    await batch((batch) {
      batch.insertAll(streams, streamList, mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<StreamItem>> watchStreamsByCategory(int accountId, String categoryId) {
    return (select(streams)
          ..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))
          ..orderBy([(s) => OrderingTerm(expression: s.name)]))
        .watch();
  }

  Stream<List<StreamItem>> watchFavoriteStreams(int accountId, String streamType) {
    final query = select(streams).join([
      innerJoin(
        favorites,
        favorites.streamId.equalsExp(streams.streamId) &
            favorites.streamType.equalsExp(streams.streamType) &
            favorites.accountId.equalsExp(streams.accountId),
      ),
    ])
      ..where(streams.accountId.equals(accountId) & streams.streamType.equals(streamType))
      ..orderBy([OrderingTerm.desc(favorites.addedAt)]);

    return query.watch().map((rows) {
      final list = rows.map((row) => row.readTable(streams)).toList();
      final seen = <String>{};
      return list.where((item) => seen.add(item.streamId)).toList();
    });
  }

  Stream<List<StreamItem>> watchStreamsByQuery(int accountId, String streamType, String query) {
    final cleanQuery = '%${query.trim().toLowerCase()}%';
    return (select(streams)
          ..where((s) => s.accountId.equals(accountId) & s.streamType.equals(streamType) & s.name.lower().like(cleanQuery))
          ..orderBy([(s) => OrderingTerm(expression: s.name)]))
        .watch()
        .map((list) {
          final seen = <String>{};
          return list.where((item) => seen.add(item.streamId)).toList();
        });
  }

  Future<int> countStreamsByType(int accountId, String streamType) async {
    final countExp = streams.id.count();
    final query = selectOnly(streams)
      ..addColumns([countExp])
      ..where(streams.accountId.equals(accountId) & streams.streamType.equals(streamType));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Future<void> replaceStreamsByType(int accountId, String streamType, List<StreamsCompanion> streamList) async {
    await transaction(() async {
      await (delete(streams)..where((s) => s.accountId.equals(accountId) & s.streamType.equals(streamType))).go();
      for (var i = 0; i < streamList.length; i += 500) {
        final end = (i + 500 < streamList.length) ? i + 500 : streamList.length;
        await batch((batch) {
          batch.insertAll(streams, streamList.sublist(i, end), mode: InsertMode.insertOrReplace);
        });
      }
    });
  }

  Future<void> clearStreamsByType(int accountId, String streamType) {
    return (delete(streams)..where((s) => s.accountId.equals(accountId) & s.streamType.equals(streamType))).go();
  }

  Future<void> clearStreamsByCategory(int accountId, String categoryId) {
    return (delete(streams)..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))).go();
  }

  Future<void> clearAllStreams(int accountId) {
    return (delete(streams)..where((s) => s.accountId.equals(accountId))).go();
  }

  Future<void> replaceStreamsByCategory(int accountId, String categoryId, List<StreamsCompanion> streamList) async {
    await transaction(() async {
      await (delete(streams)..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))).go();
      await batch((batch) {
        batch.insertAll(streams, streamList, mode: InsertMode.insertOrReplace);
      });
    });
  }
}
