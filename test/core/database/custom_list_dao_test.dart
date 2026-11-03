import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:goat_player/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const accountId = 1;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.accountDao.insertAccount(
      AccountsCompanion.insert(
        serverUrl: 'http://test.com',
        username: 'test',
        password: 'password',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomListDao', () {
    test('creates list, adds items, and reads streams', () async {
      // 1. Add sample streams
      await db.into(db.streams).insert(StreamsCompanion.insert(
            accountId: accountId,
            categoryId: 'cat_live',
            streamId: '100',
            name: 'Sky Sport 1 HD',
            streamType: 'live',
          ));
      await db.into(db.streams).insert(StreamsCompanion.insert(
            accountId: accountId,
            categoryId: 'cat_live',
            streamId: '101',
            name: 'Sky Sport 2 HD',
            streamType: 'live',
          ));

      // 2. Create custom list
      final listId = await db.customListDao.createList(accountId, 'Sport Highlights', 'live');
      expect(listId, greaterThan(0));

      final lists = await db.customListDao.getCustomLists(accountId, 'live');
      expect(lists.length, equals(1));
      expect(lists.first.name, equals('Sport Highlights'));

      // 3. Add stream 100 to list
      await db.customListDao.addItemToList(listId, accountId, '100', 'live', 'Sky Sport 1 HD');
      final isInList = await db.customListDao.isStreamInList(listId, '100');
      expect(isInList, isTrue);

      final streams = await db.customListDao.watchStreamsForCustomList(listId, accountId).first;
      expect(streams.length, equals(1));
      expect(streams.first.streamId, equals('100'));
      expect(streams.first.name, equals('Sky Sport 1 HD'));

      // 4. Remove item from list
      await db.customListDao.removeItemFromList(listId, '100');
      final isStillInList = await db.customListDao.isStreamInList(listId, '100');
      expect(isStillInList, isFalse);
    });

    test('recovers shifted streamId using streamName fallback', () async {
      final listId = await db.customListDao.createList(accountId, 'News', 'live');

      // Add item with old streamId 555 and name 'CNN International'
      await db.customListDao.addItemToList(listId, accountId, '555', 'live', 'CNN International');

      // Provider sync changed the streamId from 555 to 9999 for the same channel name
      await db.into(db.streams).insert(StreamsCompanion.insert(
            accountId: accountId,
            categoryId: 'cat_news',
            streamId: '9999',
            name: 'CNN International',
            streamType: 'live',
          ));

      // Before recovery: stream 555 doesn't exist in Streams
      var streams = await db.customListDao.watchStreamsForCustomList(listId, accountId).first;
      expect(streams.isEmpty, isTrue);

      // Trigger fuzzy recovery
      await db.customListDao.recoverMissingStreamIds(accountId, 'live');

      // After recovery: item's streamId is updated to 9999 and joins successfully!
      streams = await db.customListDao.watchStreamsForCustomList(listId, accountId).first;
      expect(streams.length, equals(1));
      expect(streams.first.streamId, equals('9999'));
      expect(streams.first.name, equals('CNN International'));
    });

    test('deleting custom list cascades and removes items', () async {
      final listId = await db.customListDao.createList(accountId, 'Favorites Plus', 'live');
      await db.customListDao.addItemToList(listId, accountId, '100', 'live', 'Sky Sport 1 HD');

      await db.customListDao.deleteList(listId);

      final lists = await db.customListDao.getCustomLists(accountId, 'live');
      expect(lists.isEmpty, isTrue);

      final items = await (db.select(db.customListItems)..where((i) => i.listId.equals(listId))).get();
      expect(items.isEmpty, isTrue);
    });
  });
}
