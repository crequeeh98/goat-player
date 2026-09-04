import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../progress_provider.dart';
import '../../vod_movies/movie_detail_modal.dart';
import '../../vod_series/series_detail_modal.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:goat_player/main.dart';

class _DisplayProgressItem {
  final PlaybackProgressItem item;
  final bool isAdvanced;

  const _DisplayProgressItem({
    required this.item,
    required this.isAdvanced,
  });
}

class ContinueWatchingRail extends ConsumerWidget {
  final String type; // 'movie' or 'series'
  
  const ContinueWatchingRail({super.key, required this.type});

  List<_DisplayProgressItem> _processItems(List<PlaybackProgressItem> rawItems) {
    if (type == 'movie') {
      return rawItems
          .where((item) => !item.isCompleted && !(item.duration > 0 && item.position / item.duration >= 0.95))
          .map((item) => _DisplayProgressItem(item: item, isAdvanced: false))
          .toList();
    }

    // Series: deduplicate by seriesId
    final Map<String, PlaybackProgressItem> grouped = {};
    for (final item in rawItems) {
      final key = item.seriesId ?? item.streamId;
      if (!grouped.containsKey(key)) {
        grouped[key] = item;
      } else {
        final existing = grouped[key]!;
        final existingScore = (existing.season ?? 0) * 1000 + (existing.episode ?? 0);
        final itemScore = (item.season ?? 0) * 1000 + (item.episode ?? 0);
        if (itemScore > existingScore || (itemScore == existingScore && item.updatedAt.isAfter(existing.updatedAt))) {
          grouped[key] = item;
        }
      }
    }

    final result = <_DisplayProgressItem>[];
    for (final item in grouped.values) {
      final isComp = item.isCompleted || (item.duration > 0 && item.position / item.duration >= 0.95);
      if (isComp) {
        // Advance to next episode
        result.add(_DisplayProgressItem(item: item, isAdvanced: true));
      } else {
        result.add(_DisplayProgressItem(item: item, isAdvanced: false));
      }
    }

    return result;
  }

  String _formatBadge(PlaybackProgressItem item, bool isAdvanced) {
    if (type != 'series') return '';
    final sNum = item.season ?? 1;
    final eNum = isAdvanced ? ((item.episode ?? 1) + 1) : (item.episode ?? 1);
    final s = sNum.toString().padLeft(2, '0');
    final e = eNum.toString().padLeft(2, '0');
    return 'S$s E$e';
  }

  static String _cleanCountryPrefix(String text) {
    var t = text.trim();
    final match = RegExp(r'^[A-Z]{2,4}\s*[-:|•]\s*').firstMatch(t);
    if (match != null) {
      t = t.substring(match.end).trim();
    }
    return t;
  }

  String _getSeriesTitle(PlaybackProgressItem item) {
    var title = item.title;
    title = _cleanCountryPrefix(title);
    if (title.contains(' - ')) {
      return title.split(' - ').first.trim();
    }
    return title;
  }

  String _getEpisodeSubtitle(BuildContext context, PlaybackProgressItem item, bool isAdvanced) {
    final l10n = AppLocalizations.of(context);
    if (type == 'movie') {
      return '';
    }
    if (isAdvanced) {
      final sNum = item.season ?? 1;
      final eNum = (item.episode ?? 1) + 1;
      final s = sNum.toString().padLeft(2, '0');
      final e = eNum.toString().padLeft(2, '0');
      return '${l10n?.upNext ?? 'Next'}: S$s E$e';
    }
    if (item.episodeTitle != null && item.episodeTitle!.isNotEmpty) {
      var epT = _cleanCountryPrefix(item.episodeTitle!);
      if (epT.contains(' - ')) {
        final parts = epT.split(' - ');
        return parts.last.trim();
      }
      return epT;
    }
    if (item.season != null && item.episode != null) {
      return '${l10n?.season ?? 'Season'} ${item.season}, ${l10n?.episodes ?? 'Ep.'} ${item.episode}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'movie' ? inProgressMoviesProvider : inProgressSeriesProvider;
    final progressAsync = ref.watch(provider);
    
    return progressAsync.when(
      data: (rawItems) {
        final displayItems = _processItems(rawItems);
        if (displayItems.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                AppLocalizations.of(context)!.continueWatching,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 235,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final displayItem = displayItems[index];
                  final item = displayItem.item;
                  final isAdvanced = displayItem.isAdvanced;
                  final badge = _formatBadge(item, isAdvanced);
                  final seriesTitle = _getSeriesTitle(item);
                  final subtitle = _getEpisodeSubtitle(context, item, isAdvanced);

                  return GestureDetector(
                    onTap: () {
                      if (type == 'movie') {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            barrierDismissible: true,
                            barrierColor: Colors.black54,
                            pageBuilder: (context, _, __) => MovieDetailModal(
                              movieName: item.title,
                              streamId: item.streamId,
                              posterUrl: item.coverUrl,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            barrierDismissible: true,
                            barrierColor: Colors.black54,
                            pageBuilder: (context, _, __) => SeriesDetailModal(
                              seriesName: seriesTitle,
                              seriesId: item.seriesId ?? item.streamId,
                              coverUrl: item.coverUrl,
                              initialSeason: item.season?.toString(),
                              initialEpisodeId: isAdvanced ? null : item.streamId,
                              targetEpisodeNum: isAdvanced ? ((item.episode ?? 1) + 1) : item.episode,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                                      ? Image.network(
                                          item.coverUrl!,
                                          fit: BoxFit.cover,
                                          cacheWidth: 280,
                                          cacheHeight: 420,
                                          errorBuilder: (_,__,___) => const Center(child: Icon(Icons.movie, size: 32)),
                                        )
                                      : Container(color: Colors.grey[800], child: const Icon(Icons.movie, size: 32)),
                                ),

                                // S/E Badge on Top-Left of Poster
                                if (badge.isNotEmpty)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.78),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white24, width: 0.5),
                                      ),
                                      child: Text(
                                        badge,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Progress Indicator at bottom of poster
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                    child: LinearProgressIndicator(
                                      value: isAdvanced ? 0.0 : (item.duration > 0 ? item.position / item.duration : 0.0),
                                      backgroundColor: Colors.black54,
                                      color: Colors.redAccent,
                                      minHeight: 4,
                                    ),
                                  ),
                                ),

                                // Play Button Icon Overlay
                                const Center(
                                  child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
                                ),

                                // Delete / Remove Card Button
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        final db = ref.read(databaseProvider);
                                        if (type == 'series') {
                                          db.playbackProgressDao.deleteSeriesProgress(item.seriesId ?? item.streamId);
                                        } else {
                                          db.playbackProgressDao.deleteProgress(item.streamId);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            seriesTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white12,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
