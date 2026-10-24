import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/title_sanitizer.dart';
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
        
        // Deduplicate, merge overlapping same-title scraper feeds, and filter out shows that already ended
        final sorted = programs
            .where((p) => p.stopTime.isAfter(now))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        String normTitle(String title) {
          return TitleSanitizer.unescapeHtml(title)
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[\s\-_.:,;!?]+'), ' ');
        }

        final uniquePrograms = <EpgProgram>[];

        for (final rawProg in sorted) {
          final cleanTitle = TitleSanitizer.unescapeHtml(rawProg.title).trim();
          final cleanDesc = rawProg.description != null
              ? TitleSanitizer.unescapeHtml(rawProg.description!).trim()
              : null;
          final prog = rawProg.copyWith(
            title: cleanTitle,
            description: cleanDesc != null ? Value(cleanDesc) : const Value.absent(),
          );

          int? mergeIdx;
          final norm = normTitle(prog.title);

          // Check recently merged programs (last 5) for same title and overlapping/matching timeframe
          for (int i = uniquePrograms.length - 1; i >= 0 && i >= uniquePrograms.length - 5; i--) {
            final existing = uniquePrograms[i];
            if (normTitle(existing.title) == norm) {
              final isSameStart = prog.startTime.isAtSameMomentAs(existing.startTime);
              final isOverlapping = prog.startTime.isBefore(existing.stopTime) &&
                  prog.startTime.difference(existing.startTime).inMinutes.abs() < 120;
              if (isSameStart || isOverlapping) {
                mergeIdx = i;
                break;
              }
            }
          }

          if (mergeIdx != null) {
            final existing = uniquePrograms[mergeIdx];
            final earlierStart = prog.startTime.isBefore(existing.startTime) ? prog.startTime : existing.startTime;
            final laterStop = prog.stopTime.isAfter(existing.stopTime) ? prog.stopTime : existing.stopTime;
            final betterDesc = (existing.description ?? '').length >= (prog.description ?? '').length
                ? existing.description
                : prog.description;

            uniquePrograms[mergeIdx] = existing.copyWith(
              startTime: earlierStart,
              stopTime: laterStop,
              description: betterDesc != null ? Value(betterDesc) : const Value.absent(),
            );
          } else {
            uniquePrograms.add(prog);
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

        // Determine the single active/currently playing program
        int? activeIndex;
        final matches = <int>[];
        for (int i = 0; i < uniquePrograms.length; i++) {
          final p = uniquePrograms[i];
          if ((now.isAfter(p.startTime) || now.isAtSameMomentAs(p.startTime)) && now.isBefore(p.stopTime)) {
            matches.add(i);
          }
        }

        if (matches.isNotEmpty) {
          if (matches.length == 1) {
            activeIndex = matches.first;
          } else {
            // Prioritize most recently started program, then shortest duration
            matches.sort((a, b) {
              final progA = uniquePrograms[a];
              final progB = uniquePrograms[b];
              final startCmp = progB.startTime.compareTo(progA.startTime);
              if (startCmp != 0) return startCmp;
              final durA = progA.stopTime.difference(progA.startTime);
              final durB = progB.stopTime.difference(progB.startTime);
              return durA.compareTo(durB);
            });
            activeIndex = matches.first;
          }
        }

        return ListView.builder(
          clipBehavior: Clip.hardEdge,
          itemCount: uniquePrograms.length,
          itemBuilder: (context, index) {
            final program = uniquePrograms[index];
            final timeFormat = DateFormat('HH:mm');
            
            final isPlaying = index == activeIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isPlaying ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}
