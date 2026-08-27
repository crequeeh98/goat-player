import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(AppDatabase db) : super(db);

  Future<void> insertCategories(List<CategoriesCompanion> categories) async {
    await batch((batch) {
      batch.insertAll(this.categories, categories, mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<Category>> watchCategories(int accountId, String type) {
    return (select(categories)
          ..where((c) => c.accountId.equals(accountId) & c.type.equals(type))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  Future<void> clearCategories(int accountId, String type) {
    return (delete(categories)..where((c) => c.accountId.equals(accountId) & c.type.equals(type))).go();
  }
}
