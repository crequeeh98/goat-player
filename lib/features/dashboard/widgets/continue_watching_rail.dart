import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../progress_provider.dart';
import '../../live_tv/widgets/tv_smart_iptv_overlays.dart';
import '../../vod_movies/movie_detail_modal.dart';
import '../../vod_series/series_detail_modal.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/core/utils/platform_utils.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:goat_player/main.dart';
import '../../../core/widgets/tv_focusable.dart';

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
  final VoidCallback? onExitLeft;
  final FocusNode? firstItemFocusNode;
  
  const ContinueWatchingRail({
    super.key,
    required this.type,
    this.onExitLeft,
    this.firstItemFocusNode,
  });

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
        
        final isDe = Localizations.localeOf(context).languageCode == 'de';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.continueWatching,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (GoatPlatform.isTv)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF87171),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isDe ? 'OK Halten: Entfernen' : 'Hold OK: Remove',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 175,
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

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 104,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TvFocusable(
                              focusNode: index == 0 ? firstItemFocusNode : null,
                              focusScale: 1.04,
                              borderRadius: BorderRadius.circular(8),
                              onKeyEvent: (node, event) {
                                if (GoatPlatform.isTv &&
                                    index == 0 &&
                                    (event is KeyDownEvent || event is KeyRepeatEvent) &&
                                    event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                                    onExitLeft != null) {
                                  onExitLeft!();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              onLongPress: GoatPlatform.isTv
                                  ? () async {
                                      final confirm = await TvColorActionPicker.showRemoveContinueWatching(
                                        context: context,
                                        itemTitle: seriesTitle,
                                        isDe: isDe,
                                      );
                                      if (confirm == true) {
                                        final db = ref.read(databaseProvider);
                                        final account = ref.read(activeAccountProvider);
                                        if (type == 'series') {
                                          db.playbackProgressDao.deleteSeriesProgress(item.seriesId ?? item.streamId, accountId: account?.id);
                                        } else {
                                          db.playbackProgressDao.deleteProgress(item.streamId, accountId: account?.id);
                                        }
                                      }
                                    }
                                  : null,
                              onPressed: () {
                                if (type == 'movie') {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      barrierDismissible: true,
                                      barrierColor: Colors.black54,
                                      transitionDuration: const Duration(milliseconds: 250),
                                      reverseTransitionDuration: const Duration(milliseconds: 250),
                                      pageBuilder: (context, _, __) => MovieDetailModal(
                                        movieName: item.title,
                                        streamId: item.streamId,
                                        posterUrl: item.coverUrl,
                                      ),
                                      transitionsBuilder: (context, animation, _, child) =>
                                          FadeTransition(opacity: animation, child: child),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      barrierDismissible: true,
                                      barrierColor: Colors.black54,
                                      transitionDuration: const Duration(milliseconds: 250),
                                      reverseTransitionDuration: const Duration(milliseconds: 250),
                                      pageBuilder: (context, _, __) => SeriesDetailModal(
                                        seriesName: seriesTitle,
                                        seriesId: item.seriesId ?? item.streamId,
                                        coverUrl: item.coverUrl,
                                        initialSeason: item.season?.toString(),
                                        initialEpisodeId: isAdvanced ? null : item.streamId,
                                        targetEpisodeNum: isAdvanced ? ((item.episode ?? 1) + 1) : item.episode,
                                      ),
                                      transitionsBuilder: (context, animation, _, child) =>
                                          FadeTransition(opacity: animation, child: child),
                                    ),
                                  );
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    item.coverUrl != null && item.coverUrl!.isNotEmpty
                                        ? Image.network(
                                            item.coverUrl!,
                                            fit: BoxFit.cover,
                                            cacheWidth: 220,
                                            cacheHeight: 330,
                                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie, size: 28)),
                                          )
                                        : Container(color: Colors.grey[800], child: const Icon(Icons.movie, size: 28)),

                                    // S/E Badge on Top-Left of Poster
                                    if (badge.isNotEmpty)
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: Colors.white24, width: 0.5),
                                          ),
                                          child: Text(
                                            badge,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
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
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                        child: LinearProgressIndicator(
                                          value: isAdvanced ? 0.0 : (item.duration > 0 ? item.position / item.duration : 0.0),
                                          backgroundColor: Colors.black54,
                                          color: Colors.redAccent,
                                          minHeight: 3.5,
                                        ),
                                      ),
                                    ),

                                    // Play Button Icon Overlay
                                    const Center(
                                      child: Icon(Icons.play_circle_fill, size: 34, color: Colors.white70),
                                    ),

                                    // Delete / Remove Card Button (Desktop/Mobile touch only; TV uses Long-Press OK)
                                    if (!GoatPlatform.isTv)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Material(
                                          color: Colors.black54,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () {
                                              final db = ref.read(databaseProvider);
                                              final account = ref.read(activeAccountProvider);
                                              if (type == 'series') {
                                                db.playbackProgressDao.deleteSeriesProgress(item.seriesId ?? item.streamId, accountId: account?.id);
                                              } else {
                                                db.playbackProgressDao.deleteProgress(item.streamId, accountId: account?.id);
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(3.0),
                                              child: Icon(Icons.close, size: 13, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Title
                          Text(
                            seriesTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white12,
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
