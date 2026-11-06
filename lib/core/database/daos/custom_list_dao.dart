import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'custom_list_dao.g.dart';

@DriftAccessor(tables: [CustomLists, CustomListItems, Streams])
class CustomListDao extends DatabaseAccessor<AppDatabase> with _$CustomListDaoMixin {
  CustomListDao(AppDatabase db) : super(db);

  Stream<List<CustomList>> watchCustomLists(int accountId, String type) {
    return (select(customLists)
          ..where((l) => l.accountId.equals(accountId) & l.type.equals(type))
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder), (l) => OrderingTerm(expression: l.name)]))
        .watch();
  }

  Future<List<CustomList>> getCustomLists(int accountId, String type) {
    return (select(customLists)
          ..where((l) => l.accountId.equals(accountId) & l.type.equals(type))
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder), (l) => OrderingTerm(expression: l.name)]))
        .get();
  }

  Future<int> createList(int accountId, String name, String type) async {
    final existing = await getCustomLists(accountId, type);
    final nextOrder = existing.isEmpty ? 0 : existing.last.sortOrder + 1;
    return into(customLists).insert(CustomListsCompanion.insert(
      accountId: accountId,
      name: name,
      type: type,
      sortOrder: Value(nextOrder),
    ));
  }

  Future<void> renameList(int listId, String newName) {
    return (update(customLists)..where((l) => l.id.equals(listId)))
        .write(CustomListsCompanion(name: Value(newName)));
  }

  Future<void> deleteList(int listId) async {
    await (delete(customListItems)..where((item) => item.listId.equals(listId))).go();
    await (delete(customLists)..where((l) => l.id.equals(listId))).go();
  }

  Future<void> reorderLists(int accountId, String type, List<int> orderedListIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedListIds.length; i++) {
        await (update(customLists)..where((l) => l.id.equals(orderedListIds[i])))
            .write(CustomListsCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<void> reorderListItems(int listId, List<String> orderedStreamIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedStreamIds.length; i++) {
        await (update(customListItems)
              ..where((item) => item.listId.equals(listId) & item.streamId.equals(orderedStreamIds[i])))
            .write(CustomListItemsCompanion(sortOrder: Value(i)));
      }
    });
  }

  Stream<List<CustomListItem>> watchListItems(int listId) {
    return (select(customListItems)
          ..where((i) => i.listId.equals(listId))
          ..orderBy([(i) => OrderingTerm(expression: i.sortOrder), (i) => OrderingTerm.desc(i.addedAt)]))
        .watch();
  }

  Future<void> addItemToList(
    int listId,
    int accountId,
    String streamId,
    String streamType,
    String? streamName,
  ) async {
    final countExp = customListItems.id.count();
    final count = await (selectOnly(customListItems)
          ..addColumns([countExp])
          ..where(customListItems.listId.equals(listId)))
        .map((row) => row.read(countExp))
        .getSingle();

    await into(customListItems).insertOnConflictUpdate(CustomListItemsCompanion.insert(
      listId: listId,
      accountId: accountId,
      streamId: streamId,
      streamType: streamType,
      streamName: streamName != null ? Value(streamName) : const Value.absent(),
      sortOrder: Value(count ?? 0),
    ));
  }

  Future<void> removeItemFromList(int listId, String streamId) {
    return (delete(customListItems)
          ..where((i) => i.listId.equals(listId) & i.streamId.equals(streamId)))
        .go();
  }

  Future<bool> isStreamInList(int listId, String streamId) async {
    final item = await (select(customListItems)
          ..where((i) => i.listId.equals(listId) & i.streamId.equals(streamId)))
        .getSingleOrNull();
    return item != null;
  }

  Future<List<int>> getListIdsContainingStream(int accountId, String streamId) async {
    final rows = await (select(customListItems)
          ..where((i) => i.accountId.equals(accountId) & i.streamId.equals(streamId)))
        .get();
    return rows.map((r) => r.listId).toList();
  }

  Stream<List<StreamItem>> watchStreamsForCustomList(int listId, int accountId) {
    final query = select(streams).join([
      innerJoin(
        customListItems,
        customListItems.streamId.equalsExp(streams.streamId) &
            customListItems.streamType.equalsExp(streams.streamType) &
            customListItems.accountId.equalsExp(streams.accountId),
      ),
    ])
      ..where(customListItems.listId.equals(listId) & streams.accountId.equals(accountId))
      ..orderBy([OrderingTerm.asc(customListItems.sortOrder), OrderingTerm.desc(customListItems.addedAt)]);

    return query.watch().map((rows) {
      final list = rows.map((row) => row.readTable(streams)).toList();
      final seen = <String>{};
      return list.where((item) => seen.add(item.streamId)).toList();
    });
  }

  Future<void> recoverMissingStreamIds(int accountId, String streamType) async {
    // Check if any items in customListItems for this account do not exist in Streams
    final allItems = await (select(customListItems)
          ..where((i) => i.accountId.equals(accountId) & i.streamType.equals(streamType)))
        .get();

    for (final item in allItems) {
      if (item.streamName == null || item.streamName!.isEmpty) continue;

      final streamExists = await (select(streams)
            ..where((s) => s.accountId.equals(accountId) & s.streamId.equals(item.streamId)))
          .getSingleOrNull();

      if (streamExists == null) {
        // Fallback: look up by name
        final matchedStream = await (select(streams)
              ..where((s) =>
                  s.accountId.equals(accountId) &
                  s.streamType.equals(streamType) &
                  s.name.equals(item.streamName!)))
            .getSingleOrNull();

        if (matchedStream != null) {
          // Re-link to new streamId
          await (update(customListItems)..where((i) => i.id.equals(item.id)))
              .write(CustomListItemsCompanion(streamId: Value(matchedStream.streamId)));
        }
      }
    }
  }
}
