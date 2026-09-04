import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'epg_dao.g.dart';

@DriftAccessor(tables: [EpgPrograms])
class EpgDao extends DatabaseAccessor<AppDatabase> with _$EpgDaoMixin {
  EpgDao(AppDatabase db) : super(db);

  Future<void> insertPrograms(List<EpgProgramsCompanion> programs) async {
    await batch((batch) {
      batch.insertAll(epgPrograms, programs, mode: InsertMode.insertOrReplace);
    });
  }

  Stream<List<EpgProgram>> watchProgramsForChannel(int accountId, String channelId) {
    final now = DateTime.now();
    return (select(epgPrograms)
          ..where((p) => p.accountId.equals(accountId) & p.channelId.equals(channelId) & p.stopTime.isBiggerOrEqualValue(now))
          ..orderBy([(p) => OrderingTerm(expression: p.startTime)])
          ..limit(20))
        .watch();
  }

  Future<Map<String, EpgProgram>> getCurrentProgramsMap(int accountId) async {
    final now = DateTime.now();
    final query = select(epgPrograms)
      ..where((p) => p.accountId.equals(accountId) & p.startTime.isSmallerOrEqualValue(now) & p.stopTime.isBiggerOrEqualValue(now));
    final list = await query.get();
    final map = <String, EpgProgram>{};
    for (final prog in list) {
      map[prog.channelId] = prog;
    }
    return map;
  }

  Future<void> clearPrograms(int accountId) {
    return (delete(epgPrograms)..where((p) => p.accountId.equals(accountId))).go();
  }

  Future<void> replacePrograms(int accountId, List<EpgProgramsCompanion> programs) async {
    await transaction(() async {
      await (delete(epgPrograms)..where((p) => p.accountId.equals(accountId))).go();
      const chunkSize = 1000;
      for (var i = 0; i < programs.length; i += chunkSize) {
        final end = (i + chunkSize < programs.length) ? i + chunkSize : programs.length;
        final chunk = programs.sublist(i, end);
        await batch((batch) {
          batch.insertAll(epgPrograms, chunk, mode: InsertMode.insertOrReplace);
        });
      }
    });
  }
}
