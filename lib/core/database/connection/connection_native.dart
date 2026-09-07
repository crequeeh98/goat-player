import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return driftDatabase(
    name: 'goat_player_db',
    native: const DriftNativeOptions(
      databaseDirectory: _getDatabaseDirectory,
    ),
  );
}

Future<Directory> _getDatabaseDirectory() async {
  final appDir = await getApplicationDocumentsDirectory();
  return Directory('${appDir.path}/goat_player');
}
