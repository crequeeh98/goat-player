import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../main.dart';

final channelProgramsProvider = StreamProvider.family.autoDispose<List<EpgProgram>, String>((ref, channelId) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const Stream.empty();
  
  final dao = ref.watch(epgDaoProvider);
  return dao.watchProgramsForChannel(account.id, channelId);
});

class EpgTimelineWidget extends ConsumerWidget {
  final String? channelId;

  const EpgTimelineWidget({super.key, this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channelId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_view_day, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.selectChannelEpg, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final programsAsync = ref.watch(channelProgramsProvider(channelId!));

    return programsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.failedToLoadEpg}$err')),
      data: (programs) {
        final now = DateTime.now();
        
        // Deduplicate and filter out programs that ended more than 1 hour ago
        final uniquePrograms = <EpgProgram>[];
        final seen = <String>{};
        
        for (final p in programs) {
          if (p.stopTime.isBefore(now.subtract(const Duration(hours: 1)))) continue;
          
          final key = '${p.title}_${p.startTime.millisecondsSinceEpoch}';
          if (!seen.contains(key)) {
            seen.add(key);
            uniquePrograms.add(p);
          }
        }

        if (uniquePrograms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, size: 48, color: Colors.white24),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.noUpcomingEpg, style: const TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: uniquePrograms.length,
          itemBuilder: (context, index) {
            final program = uniquePrograms[index];
            final timeFormat = DateFormat('HH:mm');
            
            final isPlaying = now.isAfter(program.startTime) && now.isBefore(program.stopTime);

            return ListTile(
              leading: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeFormat.format(program.startTime),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPlaying ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  Text(
                    timeFormat.format(program.stopTime),
                    style: TextStyle(
                      fontSize: 10, 
                      color: isPlaying ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(180) : Colors.grey
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      program.title,
                      style: TextStyle(
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        color: isPlaying ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                  ),
                  if (isPlaying)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                ],
              ),
              subtitle: program.description != null && program.description!.isNotEmpty 
                  ? Text(
                      program.description!, 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(200) : null,
                      ),
                    ) 
                  : null,
              tileColor: isPlaying ? Theme.of(context).colorScheme.primaryContainer : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          },
        );
      },
    );
  }
}
