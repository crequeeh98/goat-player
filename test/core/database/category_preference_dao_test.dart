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

  group('CategoryPreferenceDao', () {
    test('initializes default order and isNew=false on first sync', () async {
      final incoming = ['cat_1', 'cat_2', 'cat_3'];
      await db.categoryPreferenceDao.syncCategoryIds(accountId, 'live', incoming);

      final prefs = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefs.length, equals(3));
      expect(prefs[0].categoryId, equals('cat_1'));
      expect(prefs[0].sortOrder, equals(0));
      expect(prefs[0].isNew, isFalse);
      expect(prefs[0].isHidden, isFalse);

      expect(prefs[1].categoryId, equals('cat_2'));
      expect(prefs[1].sortOrder, equals(1));
      expect(prefs[2].categoryId, equals('cat_3'));
      expect(prefs[2].sortOrder, equals(2));
    });

    test('detects new incoming categories, appends them at end and marks isNew=true', () async {
      await db.categoryPreferenceDao.syncCategoryIds(accountId, 'live', ['cat_1', 'cat_2']);

      // User reorders: moves cat_2 to index 0, cat_1 to index 1
      await db.categoryPreferenceDao.updateSortOrders(accountId, 'live', ['cat_2', 'cat_1']);

      // New sync arrives with a brand new category 'cat_3'
      await db.categoryPreferenceDao.syncCategoryIds(accountId, 'live', ['cat_1', 'cat_2', 'cat_3']);

      final prefs = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefs.length, equals(3));

      // cat_2 and cat_1 retain their user sort order
      final p1 = prefs.firstWhere((p) => p.categoryId == 'cat_1');
      final p2 = prefs.firstWhere((p) => p.categoryId == 'cat_2');
      final p3 = prefs.firstWhere((p) => p.categoryId == 'cat_3');

      expect(p2.sortOrder, equals(0));
      expect(p2.isNew, isFalse);

      expect(p1.sortOrder, equals(1));
      expect(p1.isNew, isFalse);

      // cat_3 is appended with higher sortOrder and marked isNew=true
      expect(p3.sortOrder, greaterThan(1));
      expect(p3.isNew, isTrue);
    });

    test('markViewed clears isNew badge', () async {
      await db.categoryPreferenceDao.syncCategoryIds(accountId, 'live', ['cat_1']);
      await db.categoryPreferenceDao.syncCategoryIds(accountId, 'live', ['cat_1', 'cat_2']);

      var prefs = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefs.firstWhere((p) => p.categoryId == 'cat_2').isNew, isTrue);

      await db.categoryPreferenceDao.markViewed(accountId, 'cat_2', 'live');

      prefs = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefs.firstWhere((p) => p.categoryId == 'cat_2').isNew, isFalse);
    });

    test('setVisibility hides category correctly', () async {
      await db.categoryPreferenceDao.syncCategoryIds(accountId, 'live', ['cat_1']);
      await db.categoryPreferenceDao.setVisibility(accountId, 'cat_1', 'live', true);

      final prefs = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefs.first.isHidden, isTrue);

      await db.categoryPreferenceDao.setVisibility(accountId, 'cat_1', 'live', false);
      final prefsUnhidden = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefsUnhidden.first.isHidden, isFalse);
    });

    test('CategoryDao replaceCategories triggers syncCategoryIds and watchCategories filters hidden items', () async {
      final companions = [
        CategoriesCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_a',
          name: 'Category A',
          type: 'live',
        ),
        CategoriesCompanion.insert(
          accountId: accountId,
          categoryId: 'cat_b',
          name: 'Category B',
          type: 'live',
        ),
      ];

      await db.categoryDao.replaceCategories(accountId, 'live', companions);

      // Verify category preferences were auto-initialized
      final prefs = await db.categoryPreferenceDao.getPreferences(accountId, 'live');
      expect(prefs.length, equals(2));
      expect(prefs[0].categoryId, equals('cat_a'));
      expect(prefs[1].categoryId, equals('cat_b'));

      // Hide Category A
      await db.categoryPreferenceDao.setVisibility(accountId, 'cat_a', 'live', true);

      // watchCategories should now only return Category B!
      final visibleCats = await db.categoryDao.watchCategories(accountId, 'live').first;
      expect(visibleCats.length, equals(1));
      expect(visibleCats.first.categoryId, equals('cat_b'));
    });
  });
}
