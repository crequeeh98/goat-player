import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    print('[DriftWeb] Initializing pure JS sql.js (asm.js) database...');
    try {
      final storage = await DriftWebStorage.indexedDbIfSupported('goat_player_db');
      print('[DriftWeb] sql.js storage ready, opening WebDatabase with storage...');
      return DatabaseConnection(WebDatabase.withStorage(
        storage,
        logStatements: false,
      ));
    } catch (e, stack) {
      print('[DriftWeb] Error initializing storage ($e), falling back to localStorage WebDatabase: $stack');
      return DatabaseConnection(WebDatabase(
        'goat_player_db',
        logStatements: false,
      ));
    }
  }));
}
