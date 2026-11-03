import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'category_dao.g.dart';

class CategoryWithPref {
  final Category category;
  final bool isHidden;
  final int sortOrder;
  final bool isNew;

  const CategoryWithPref({
    required this.category,
    this.isHidden = false,
    this.sortOrder = 0,
    this.isNew = false,
  });
}

@DriftAccessor(tables: [Categories, CategoryPreferences])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(AppDatabase db) : super(db);

  Future<void> insertCategories(List<CategoriesCompanion> categories) async {
    await batch((batch) {
      batch.insertAll(this.categories, categories, mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<CategoryWithPref>> watchVisibleCategoriesWithPrefs(int accountId, String type) {
    final query = select(categories).join([
      leftOuterJoin(
        categoryPreferences,
        categoryPreferences.accountId.equalsExp(categories.accountId) &
            categoryPreferences.categoryId.equalsExp(categories.categoryId) &
            categoryPreferences.type.equalsExp(categories.type),
      ),
    ])
      ..where(
        categories.accountId.equals(accountId) &
            categories.type.equals(type) &
            (categoryPreferences.isHidden.isNull() | categoryPreferences.isHidden.equals(false)),
      )
      ..orderBy([
        OrderingTerm(
          expression: categoryPreferences.sortOrder,
          nulls: NullsOrder.last,
          mode: OrderingMode.asc,
        ),
        OrderingTerm.asc(categories.name),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final cat = row.readTable(categories);
        final pref = row.readTableOrNull(categoryPreferences);
        return CategoryWithPref(
          category: cat,
          isHidden: pref?.isHidden ?? false,
          sortOrder: pref?.sortOrder ?? 999999,
          isNew: pref?.isNew ?? false,
        );
      }).toList();
    });
  }

  Stream<List<CategoryWithPref>> watchAllCategoriesWithPrefs(int accountId, String type) {
    final query = select(categories).join([
      leftOuterJoin(
        categoryPreferences,
        categoryPreferences.accountId.equalsExp(categories.accountId) &
            categoryPreferences.categoryId.equalsExp(categories.categoryId) &
            categoryPreferences.type.equalsExp(categories.type),
      ),
    ])
      ..where(
        categories.accountId.equals(accountId) & categories.type.equals(type),
      )
      ..orderBy([
        OrderingTerm(
          expression: categoryPreferences.sortOrder,
          nulls: NullsOrder.last,
          mode: OrderingMode.asc,
        ),
        OrderingTerm.asc(categories.name),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final cat = row.readTable(categories);
        final pref = row.readTableOrNull(categoryPreferences);
        return CategoryWithPref(
          category: cat,
          isHidden: pref?.isHidden ?? false,
          sortOrder: pref?.sortOrder ?? 999999,
          isNew: pref?.isNew ?? false,
        );
      }).toList();
    });
  }

  Stream<List<Category>> watchCategories(int accountId, String type) {
    return watchVisibleCategoriesWithPrefs(accountId, type).map(
      (list) => list.map((item) => item.category).toList(),
    );
  }

  Future<void> clearCategories(int accountId, String type) {
    return (delete(categories)..where((c) => c.accountId.equals(accountId) & c.type.equals(type))).go();
  }

  Future<void> replaceCategories(int accountId, String type, List<CategoriesCompanion> newCategories) async {
    await transaction(() async {
      await (delete(categories)..where((c) => c.accountId.equals(accountId) & c.type.equals(type))).go();
      await batch((batch) {
        batch.insertAll(categories, newCategories, mode: InsertMode.insertOrReplace);
      });
      final incomingIds = newCategories.map((c) => c.categoryId.value).toList();
      await db.categoryPreferenceDao.syncCategoryIds(accountId, type, incomingIds);
    });
  }
}
