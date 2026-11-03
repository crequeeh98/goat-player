import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';
import 'category_dao.dart';

part 'category_preference_dao.g.dart';

@DriftAccessor(tables: [CategoryPreferences])
class CategoryPreferenceDao extends DatabaseAccessor<AppDatabase> with _$CategoryPreferenceDaoMixin {
  CategoryPreferenceDao(AppDatabase db) : super(db);

  Stream<List<CategoryPreference>> watchPreferences(int accountId, String type) {
    return (select(categoryPreferences)
          ..where((cp) => cp.accountId.equals(accountId) & cp.type.equals(type))
          ..orderBy([(cp) => OrderingTerm(expression: cp.sortOrder)]))
        .watch();
  }

  Future<List<CategoryPreference>> getPreferences(int accountId, String type) {
    return (select(categoryPreferences)
          ..where((cp) => cp.accountId.equals(accountId) & cp.type.equals(type))
          ..orderBy([(cp) => OrderingTerm(expression: cp.sortOrder)]))
        .get();
  }

  Future<void> setVisibility(int accountId, String categoryId, String type, bool isHidden, {int? sortOrder}) async {
    final existing = await (select(categoryPreferences)
          ..where((cp) => cp.accountId.equals(accountId) & cp.categoryId.equals(categoryId) & cp.type.equals(type)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(categoryPreferences)
            ..where((cp) => cp.id.equals(existing.id)))
          .write(CategoryPreferencesCompanion(isHidden: Value(isHidden)));
    } else {
      final defaultSort = sortOrder ?? (categoryId == 'favorites' ? -100 : (categoryId.startsWith('custom_list:') ? -50 : 0));
      await into(categoryPreferences).insert(CategoryPreferencesCompanion.insert(
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        isHidden: Value(isHidden),
        sortOrder: Value(defaultSort),
      ));
    }
  }

  Future<void> setAllVisibility(int accountId, String type, List<CategoryWithPref> items, bool isHidden) async {
    await transaction(() async {
      await (update(categoryPreferences)
            ..where((cp) => cp.accountId.equals(accountId) & cp.type.equals(type)))
          .write(CategoryPreferencesCompanion(isHidden: Value(isHidden)));

      final existing = await (select(categoryPreferences)
            ..where((cp) => cp.accountId.equals(accountId) & cp.type.equals(type)))
          .get();
      final existingIds = {for (final p in existing) p.categoryId};

      final missing = items.where((i) => !existingIds.contains(i.category.categoryId)).toList();
      if (missing.isNotEmpty) {
        await batch((b) {
          for (final item in missing) {
            b.insert(
              categoryPreferences,
              CategoryPreferencesCompanion.insert(
                accountId: accountId,
                categoryId: item.category.categoryId,
                type: type,
                isHidden: Value(isHidden),
                sortOrder: Value(item.sortOrder),
              ),
            );
          }
        });
      }
    });
  }

  Future<void> updateSortOrders(int accountId, String type, List<String> orderedCategoryIds) async {
    await transaction(() async {
      for (int i = 0; i < orderedCategoryIds.length; i++) {
        final catId = orderedCategoryIds[i];
        final existing = await (select(categoryPreferences)
              ..where((cp) => cp.accountId.equals(accountId) & cp.categoryId.equals(catId) & cp.type.equals(type)))
            .getSingleOrNull();

        if (existing != null) {
          await (update(categoryPreferences)..where((cp) => cp.id.equals(existing.id)))
              .write(CategoryPreferencesCompanion(sortOrder: Value(i)));
        } else {
          await into(categoryPreferences).insert(CategoryPreferencesCompanion.insert(
            accountId: accountId,
            categoryId: catId,
            type: type,
            sortOrder: Value(i),
          ));
        }
      }
    });
  }

  Future<void> markViewed(int accountId, String categoryId, String type) async {
    await (update(categoryPreferences)
          ..where((cp) => cp.accountId.equals(accountId) & cp.categoryId.equals(categoryId) & cp.type.equals(type)))
        .write(const CategoryPreferencesCompanion(isNew: Value(false)));
  }

  Future<void> markAllViewed(int accountId, String type) async {
    await (update(categoryPreferences)
          ..where((cp) => cp.accountId.equals(accountId) & cp.type.equals(type)))
        .write(const CategoryPreferencesCompanion(isNew: Value(false)));
  }

  Future<void> syncCategoryIds(int accountId, String type, List<String> incomingIds) async {
    if (incomingIds.isEmpty) return;

    final existing = await getPreferences(accountId, type);
    final existingMap = {for (final p in existing) p.categoryId: p};

    // First time for this account/type: initialize default A-Z / provider order
    if (existing.isEmpty) {
      await batch((b) {
        for (int i = 0; i < incomingIds.length; i++) {
          b.insert(
            categoryPreferences,
            CategoryPreferencesCompanion.insert(
              accountId: accountId,
              categoryId: incomingIds[i],
              type: type,
              sortOrder: Value(i),
              isNew: const Value(false),
            ),
          );
        }
      });
      return;
    }

    // Subsequent sync: detect new categories not seen before
    int maxOrder = existing.fold<int>(0, (prev, p) => p.sortOrder > prev ? p.sortOrder : prev);
    final toAdd = <String>[];
    for (final id in incomingIds) {
      if (!existingMap.containsKey(id)) {
        toAdd.add(id);
      }
    }

    if (toAdd.isNotEmpty) {
      await batch((b) {
        for (int i = 0; i < toAdd.length; i++) {
          maxOrder++;
          b.insert(
            categoryPreferences,
            CategoryPreferencesCompanion.insert(
              accountId: accountId,
              categoryId: toAdd[i],
              type: type,
              sortOrder: Value(maxOrder),
              isNew: const Value(true), // Mark as new with badge!
            ),
          );
        }
      });
    }
  }

  Future<void> resetToDefault(int accountId, String type) async {
    await (delete(categoryPreferences)
          ..where((cp) => cp.accountId.equals(accountId) & cp.type.equals(type)))
        .go();
  }
}
