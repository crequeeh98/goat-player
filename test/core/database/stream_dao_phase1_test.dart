import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int accountId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountId = await db.accountDao.insertAccount(
      AccountsCompanion.insert(
        serverUrl: 'http://test.example',
        username: 'user',
        password: 'password',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('F1: SQLite FTS5 Search & Trigger Sync', () {
    test('returns empty list for blank query', () async {
      await db.streamDao.insertStreams([
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '101',
          name: 'BBC News',
          streamType: 'live',
        ),
      ]);

      final res = await db.streamDao.watchStreamsByQuery(accountId, 'live', '   ').first;
      expect(res, isEmpty);
    });

    test('matches prefix tokens, diacritics, and deduplicates by streamId', () async {
      final ftsCheck = await db.customSelect("SELECT name FROM sqlite_master WHERE name = 'streams_fts'").get();
      expect(ftsCheck.length, equals(1));
      final directFts = await db.customSelect(
        'SELECT s.* FROM streams s JOIN streams_fts f ON s.id = f.rowid WHERE streams_fts MATCH ?',
        variables: [Variable.withString('"cafe"*')],
      ).get();
      expect(directFts, isEmpty); // before insert

      await db.streamDao.insertStreams([
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '1',
          name: 'Café Racer Documentary',
          streamType: 'movie',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_2',
          streamId: '1',
          name: 'Café Racer Documentary',
          streamType: 'movie',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '2',
          name: 'Sports Live HD',
          streamType: 'live',
        ),
      ]);

      final movies = await db.streamDao.watchStreamsByQuery(accountId, 'movie', 'cafe doc').first;
      expect(movies.length, equals(1));
      expect(movies.first.streamId, equals('1'));

      final live = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'cafe').first;
      expect(live, isEmpty);
    });

    test('sanitizes FTS5 operators/quotes and falls back to LIKE when FTS5 is absent', () async {
      await db.streamDao.insertStreams([
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '10',
          name: 'Alpha "Star" News',
          streamType: 'live',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '11',
          name: 'Not Another Channel',
          streamType: 'live',
        ),
      ]);

      final quoted = await db.streamDao.watchStreamsByQuery(accountId, 'live', '"Alpha"* AND Star').first;
      expect(quoted.map((e) => e.streamId), equals(['10']));

      // Pure FTS operator token falls back to LIKE
      final operatorOnly = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'NOT').first;
      expect(operatorOnly.map((e) => e.streamId), equals(['11']));

      // Drop FTS5 table to verify runtime fallback to LIKE
      await db.customStatement('DROP TABLE IF EXISTS streams_fts;');
      final fallbackRes = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Alpha').first;
      expect(fallbackRes.map((e) => e.streamId), equals(['10']));
    });

    test('triggers keep streams_fts synced on insert, update, and delete', () async {
      await db.streamDao.insertStreams([
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '50',
          name: 'Old Channel Name',
          streamType: 'live',
        ),
      ]);

      var res = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Old').first;
      expect(res.length, equals(1));

      // Update name via Drift update
      final row = res.first;
      await (db.update(db.streams)..where((s) => s.id.equals(row.id))).write(
        const StreamsCompanion(name: Value('Fresh Renamed Channel')),
      );

      final oldRes = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Old').first;
      expect(oldRes, isEmpty);

      final newRes = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Fresh').first;
      expect(newRes.map((e) => e.streamId), equals(['50']));

      // Delete via clearStreamsByType
      await db.streamDao.clearStreamsByType(accountId, 'live');
      res = await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Fresh').first;
      expect(res, isEmpty);
    });
  });

  group('F2: Category Pagination & Count', () {
    test('watchStreamsByCategory supports optional limit/offset and countStreamsByCategory returns count', () async {
      await db.streamDao.insertStreams([
        StreamsCompanion.insert(accountId: accountId, categoryId: 'c1', streamId: 's1', name: 'Delta', streamType: 'movie'),
        StreamsCompanion.insert(accountId: accountId, categoryId: 'c1', streamId: 's2', name: 'Alpha', streamType: 'movie'),
        StreamsCompanion.insert(accountId: accountId, categoryId: 'c1', streamId: 's3', name: 'Charlie', streamType: 'movie'),
        StreamsCompanion.insert(accountId: accountId, categoryId: 'c1', streamId: 's4', name: 'Bravo', streamType: 'movie'),
        StreamsCompanion.insert(accountId: accountId, categoryId: 'c2', streamId: 's5', name: 'Other', streamType: 'movie'),
      ]);

      expect(await db.streamDao.countStreamsByCategory(accountId, 'c1'), equals(4));
      expect(await db.streamDao.countStreamsByCategory(accountId, 'c2'), equals(1));

      final all = await db.streamDao.watchStreamsByCategory(accountId, 'c1').first;
      expect(all.map((e) => e.name), equals(['Alpha', 'Bravo', 'Charlie', 'Delta']));

      final page1 = await db.streamDao.watchStreamsByCategory(accountId, 'c1', limit: 2, offset: 0).first;
      expect(page1.map((e) => e.name), equals(['Alpha', 'Bravo']));

      final page2 = await db.streamDao.getStreamsByCategoryPage(accountId, 'c1', limit: 2, offset: 2);
      expect(page2.map((e) => e.name), equals(['Charlie', 'Delta']));
    });
  });

  group('F3: Delta Upsert replaceStreamsByType', () {
    test('preserves unchanged row IDs, updates modified, inserts new, deletes stale, and keeps FTS5 synced', () async {
      await db.streamDao.replaceStreamsByType(accountId, 'live', [
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '1',
          name: 'Unchanged Channel',
          streamType: 'live',
          streamIcon: const Value('http://icon/1.png'),
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '2',
          name: 'Before Update',
          streamType: 'live',
          epgChannelId: const Value('epg_2'),
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '3',
          name: 'Stale Channel',
          streamType: 'live',
        ),
      ]);

      final initial = await db.streamDao.watchStreamsByCategory(accountId, 'cat_1').first;
      final id1 = initial.firstWhere((e) => e.streamId == '1').id;
      final id2 = initial.firstWhere((e) => e.streamId == '2').id;

      await db.streamDao.replaceStreamsByType(accountId, 'live', [
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '1',
          name: 'Unchanged Channel',
          streamType: 'live',
          streamIcon: const Value('http://icon/1.png'),
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '2',
          name: 'After Update',
          streamType: 'live',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_1',
          streamId: '4',
          name: 'Brand New Channel',
          streamType: 'live',
        ),
      ]);

      final updated = await db.streamDao.watchStreamsByCategory(accountId, 'cat_1').first;
      expect(updated.map((e) => e.streamId).toSet(), equals({'1', '2', '4'}));

      final row1 = updated.firstWhere((e) => e.streamId == '1');
      final row2 = updated.firstWhere((e) => e.streamId == '2');
      expect(row1.id, equals(id1));
      expect(row2.id, equals(id2));
      expect(row2.name, equals('After Update'));
      expect(row2.epgChannelId, isNull);

      // Verify FTS5 index reflects update, insert, and delete
      expect(await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Before').first, isEmpty);
      expect(await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Stale').first, isEmpty);
      expect((await db.streamDao.watchStreamsByQuery(accountId, 'live', 'After').first).map((e) => e.streamId), equals(['2']));
      expect((await db.streamDao.watchStreamsByQuery(accountId, 'live', 'Brand').first).map((e) => e.streamId), equals(['4']));
    });

    test('handles >500 chunked inserts, updates, and deletes', () async {
      final initialList = List.generate(
        1100,
        (i) => StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'bulk',
          streamId: 'id_$i',
          name: 'Stream $i',
          streamType: 'movie',
        ),
      );
      await db.streamDao.replaceStreamsByType(accountId, 'movie', initialList);
      expect(await db.streamDao.countStreamsByType(accountId, 'movie'), equals(1100));

      // Keep 0..499 unchanged, update 500..549, delete 550..1099, insert 1100..1649
      final nextList = <StreamsCompanion>[
        for (var i = 0; i < 500; i++)
          StreamsCompanion.insert(
            accountId: accountId,
            categoryId: 'bulk',
            streamId: 'id_$i',
            name: 'Stream $i',
            streamType: 'movie',
          ),
        for (var i = 500; i < 550; i++)
          StreamsCompanion.insert(
            accountId: accountId,
            categoryId: 'bulk',
            streamId: 'id_$i',
            name: 'Updated $i',
            streamType: 'movie',
          ),
        for (var i = 1100; i < 1650; i++)
          StreamsCompanion.insert(
            accountId: accountId,
            categoryId: 'bulk',
            streamId: 'id_$i',
            name: 'Stream $i',
            streamType: 'movie',
          ),
      ];
      await db.streamDao.replaceStreamsByType(accountId, 'movie', nextList);
      expect(await db.streamDao.countStreamsByType(accountId, 'movie'), equals(1100));
      expect(db.schemaVersion, equals(12));

      // Verify bulk FTS5 rebuild kept updated/new/deleted rows 100% accurate
      expect((await db.streamDao.watchStreamsByQuery(accountId, 'movie', 'Updated 505').first).map((e) => e.streamId), equals(['id_505']));
      expect((await db.streamDao.watchStreamsByQuery(accountId, 'movie', 'Stream 1200').first).map((e) => e.streamId), equals(['id_1200']));
      expect(await db.streamDao.watchStreamsByQuery(accountId, 'movie', 'Stream 600').first, isEmpty);
    });

    test('serializes concurrent replaceStreamsByType and replaceStreamsByCategory without duplicates', () async {
      final typeList = [
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'sports',
          streamId: '101',
          name: 'Sport 1',
          streamType: 'live',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'sports',
          streamId: '102',
          name: 'Sport 2',
          streamType: 'live',
        ),
      ];
      final catList = [
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'sports',
          streamId: '101',
          name: 'Sport 1',
          streamType: 'live',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'sports',
          streamId: '101',
          name: 'Sport 1 Duplicate',
          streamType: 'live',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'sports',
          streamId: '102',
          name: 'Sport 2',
          streamType: 'live',
        ),
      ];

      await Future.wait([
        db.streamDao.replaceStreamsByType(accountId, 'live', typeList),
        db.streamDao.replaceStreamsByCategory(accountId, 'sports', catList),
      ]);

      final rows = await db.streamDao.watchStreamsByCategory(accountId, 'sports').first;
      expect(rows.length, equals(2));
      expect(rows.map((e) => e.streamId).toSet(), equals({'101', '102'}));
      expect(await db.streamDao.countStreamsByCategory(accountId, 'sports'), equals(2));
    });

    test('watchStreamsByCategory deduplicates pre-existing duplicate stream rows', () async {
      await db.streamDao.insertStreams([
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'news',
          streamId: '201',
          name: 'News 1',
          streamType: 'live',
        ),
        StreamsCompanion.insert(
          accountId: accountId,
          categoryId: 'news',
          streamId: '201',
          name: 'News 1',
          streamType: 'live',
        ),
      ]);

      final watched = await db.streamDao.watchStreamsByCategory(accountId, 'news').first;
      expect(watched.length, equals(1));
      expect(watched.first.streamId, equals('201'));
    });
  });
}
