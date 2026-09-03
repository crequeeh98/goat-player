import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/epg_isolate_parser.dart';
import 'package:dio/dio.dart';

final epgControllerProvider = Provider<EpgController>((ref) {
  return EpgController(ref);
});

final currentProgramsMapProvider = FutureProvider.autoDispose<Map<String, EpgProgram>>((ref) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return {};
  final dao = ref.watch(epgDaoProvider);
  return dao.getCurrentProgramsMap(account.id);
});

class EpgController {
  final Ref _ref;
  
  EpgController(this._ref);

  bool _isSyncing = false;

  Future<void> syncEpgData() async {
    if (_isSyncing) {
      debugPrint('EPG sync already in progress. Skipping.');
      return;
    }
    
    final account = _ref.read(activeAccountProvider);
    if (account == null) return;
    
    _isSyncing = true;
    try {
      debugPrint('Fetching EPG data from XMLTV API...');
      final xmltvUrl = '${account.serverUrl}/xmltv.php?username=${account.username}&password=${account.password}';
      
      final dio = Dio();
      final response = await dio.get<String>(xmltvUrl);
      
      if (response.data != null) {
        debugPrint('EPG data downloaded. Length: ${response.data!.length}');
        debugPrint('Starting background XMLTV parse...');
        final programs = await EpgIsolateParser.parse(response.data!);
        debugPrint('EPG parsed items: ${programs.length}');
        
        final dao = _ref.read(epgDaoProvider);
        final companions = programs.map((p) {
          final startDt = EpgIsolateParser.parseXmltvDate(p.start) ?? DateTime.now();
          final stopDt = EpgIsolateParser.parseXmltvDate(p.stop) ?? DateTime.now().add(const Duration(hours: 1));
          
          return EpgProgramsCompanion.insert(
            accountId: account.id,
            channelId: p.channelId,
            title: p.title,
            description: p.description != null ? Value(p.description!) : const Value.absent(),
            startTime: startDt,
            stopTime: stopDt,
          );
        }).toList();
        
        // Clear old EPG for this account first to prevent bloated database
        await dao.clearPrograms(account.id);
        await dao.insertPrograms(companions);
        debugPrint('EPG Successfully inserted ${companions.length} programs into DB');
      } else {
        debugPrint('EPG response data was null');
      }
    } catch (e) {
      debugPrint('Failed to sync EPG: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
