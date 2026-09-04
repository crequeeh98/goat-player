import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../progress_provider.dart';
import '../../vod_movies/movie_detail_modal.dart';
import '../../vod_series/series_detail_modal.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:goat_player/main.dart';

class ContinueWatchingRail extends ConsumerWidget {
  final String type; // 'movie' or 'series'
  
  const ContinueWatchingRail({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'movie' ? inProgressMoviesProvider : inProgressSeriesProvider;
    final progressAsync = ref.watch(provider);
    
    return progressAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                AppLocalizations.of(context)!.continueWatching ?? 'Continue Watching',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
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
                              seriesName: item.title.split(' - ').first,
                              seriesId: item.seriesId ?? item.streamId, // Fallback
                              coverUrl: item.coverUrl,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                                      ? Image.network(
                                          item.coverUrl!,
                                          fit: BoxFit.cover,
                                          cacheWidth: 260,
                                          cacheHeight: 390,
                                          errorBuilder: (_,__,___) => const Center(child: Icon(Icons.movie, size: 32)),
                                        )
                                      : Container(color: Colors.grey[800], child: const Icon(Icons.movie, size: 32)),
                                ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: LinearProgressIndicator(
                                    value: item.duration > 0 ? item.position / item.duration : 0,
                                    backgroundColor: Colors.black54,
                                    color: Colors.red,
                                    minHeight: 4,
                                  ),
                                ),
                                const Center(
                                  child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        ref.read(databaseProvider).playbackProgressDao.deleteProgress(item.streamId);
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
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
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

