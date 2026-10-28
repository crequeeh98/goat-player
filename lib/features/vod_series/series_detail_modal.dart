import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/vod_title_cleaner.dart';
import '../../core/widgets/tv_focusable.dart';
import '../dashboard/favorites_provider.dart';
import '../vod_movies/vod_player_screen.dart';

class SeriesDetailModal extends ConsumerStatefulWidget {
  final String seriesName;
  final String seriesId;
  final String? coverUrl;
  final String? initialSeason;
  final String? initialEpisodeId;
  final int? targetEpisodeNum;

  const SeriesDetailModal({
    super.key,
    required this.seriesName,
    required this.seriesId,
    this.coverUrl,
    this.initialSeason,
    this.initialEpisodeId,
    this.targetEpisodeNum,
  });

  @override
  ConsumerState<SeriesDetailModal> createState() => _SeriesDetailModalState();
}

class _SeriesDetailModalState extends ConsumerState<SeriesDetailModal> {
  Map<String, dynamic>? xtreamInfo;
  bool isLoading = true;
  String? errorMessage;
  
  String? selectedSeason;
  String? _highlightEpisodeId;
  List<dynamic> currentEpisodes = [];
  Map<String, PlaybackProgressItem> _episodeProgress = {};
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSeriesData();
    _fetchProgress();
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProgress() async {
    final db = ref.read(databaseProvider);
    final list = await db.playbackProgressDao.getEpisodesProgressForSeries(widget.seriesId);
    if (mounted) {
      setState(() {
        _episodeProgress = { for (var item in list) item.streamId : item };
      });
    }
  }

  Future<void> _fetchSeriesData() async {
    final client = ref.read(xtreamClientProvider);
    if (client == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'No active connection.';
        });
      }
      return;
    }

    try {
      final details = await client.getSeriesInfo(widget.seriesId);
      if (mounted) {
        final infoMap = details is Map ? details.cast<String, dynamic>() : null;
        
        // Smart season selection: initialSeason > last watched season from DB > first season
        final lastWatched = await ref.read(databaseProvider).playbackProgressDao.getLastWatchedForSeries(widget.seriesId);
        String? targetSeason = widget.initialSeason;
        final episodesMap = infoMap?['episodes'];
        if (targetSeason == null && episodesMap is Map && episodesMap.isNotEmpty) {
          if (lastWatched?.season != null && episodesMap.containsKey(lastWatched!.season.toString())) {
            targetSeason = lastWatched.season.toString();
          } else {
            targetSeason = episodesMap.keys.first.toString();
          }
        }

        String? highlightId = widget.initialEpisodeId;

        // If targetEpisodeNum is specified (e.g. from Continue Watching advanced card)
        if (highlightId == null && widget.targetEpisodeNum != null && episodesMap is Map) {
          final currentSeasonEps = (episodesMap[targetSeason] is List) ? (episodesMap[targetSeason] as List) : [];
          final match = currentSeasonEps.firstWhere(
            (ep) => int.tryParse(ep['episode_num']?.toString() ?? '') == widget.targetEpisodeNum,
            orElse: () => null,
          );
          if (match != null) {
            highlightId = match['id']?.toString();
          } else {
            // Check if next season has it (e.g. after season finale)
            final seasonKeys = episodesMap.keys.toList();
            final currIdx = seasonKeys.indexOf(targetSeason);
            if (currIdx != -1 && currIdx + 1 < seasonKeys.length) {
              final nextSeasonKey = seasonKeys[currIdx + 1];
              final nextSeasonEps = (episodesMap[nextSeasonKey] is List) ? (episodesMap[nextSeasonKey] as List) : [];
              if (nextSeasonEps.isNotEmpty) {
                targetSeason = nextSeasonKey;
                highlightId = nextSeasonEps.first['id']?.toString();
              }
            }
          }
        }

        if (highlightId == null && lastWatched != null) {
          highlightId = lastWatched.streamId;
        }

        setState(() {
          xtreamInfo = infoMap;
          isLoading = false;
          _highlightEpisodeId = highlightId;
          
          if (episodesMap != null && episodesMap is Map && episodesMap.isNotEmpty) {
            selectedSeason = (targetSeason != null && episodesMap.containsKey(targetSeason))
                ? targetSeason
                : episodesMap.keys.first.toString();
            currentEpisodes = _getEpisodesForSeason(selectedSeason!);
          }
        });
      }
    } catch (e) {
      debugPrint('Xtream Series Info Error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load series details.';
        });
      }
    }
  }
  
  List<dynamic> _getEpisodesForSeason(String seasonStr) {
    final episodesMap = xtreamInfo?['episodes'];
    if (episodesMap is Map) {
      final eps = episodesMap[seasonStr] ?? episodesMap[int.tryParse(seasonStr)];
      if (eps is List) {
        return eps;
      }
    }
    return [];
  }

  Future<void> _playEpisode(Map<String, dynamic> episode) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    
    final episodeId = episode['id']?.toString() ?? '';
    
    // Check for existing progress
    final db = ref.read(databaseProvider);
    final progress = await db.playbackProgressDao.getProgress(episodeId);
    
    int? startPosition;
    
    if (progress != null && mounted) {
      final isComp = progress.isCompleted || (progress.duration > 0 && (progress.position / progress.duration) >= 0.95);
      if (!isComp) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.resumePlayback),
            content: Text('${AppLocalizations.of(ctx)!.resumeFrom} ${_formatDuration(progress.position)}?'),
            actions: [
              if (GoatPlatform.isTv) ...[
                TvFocusable(
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(AppLocalizations.of(ctx)!.startOver),
                  ),
                ),
                TvFocusable(
                  autofocus: true,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(ctx)!.resume,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppLocalizations.of(ctx)!.startOver),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(AppLocalizations.of(ctx)!.resume),
                ),
              ],
            ],
          ),
        );
        
        if (resume == null) return;
        if (resume == true) {
          startPosition = progress.position;
        }
      }
    }
    
    if (!mounted) return;
    
    final extension = episode['container_extension']?.toString() ?? 'mp4';
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final url = '$baseUrl/series/${account.username}/${account.password}/$episodeId.$extension';
    
    final epTitle = episode['title']?.toString() ?? 'Episode';
    final cover = episode['info']?['movie_image']?.toString();
    
    // Convert seasons map for player
    final seasonsMap = <String, List<dynamic>>{};
    if (xtreamInfo?['episodes'] is Map) {
      for (final entry in (xtreamInfo!['episodes'] as Map).entries) {
        if (entry.value is List) {
          seasonsMap[entry.key.toString()] = entry.value as List<dynamic>;
        }
      }
    }

    if (!mounted) return;

    final cleanTitle = VodTitleCleaner.formatDisplayTitle(
      seriesName: widget.seriesName,
      season: selectedSeason ?? '1',
      epNum: episode['episode_num']?.toString() ?? '1',
      epTitle: epTitle,
    );

    // Seamless instant transition directly into VodPlayerScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => VodPlayerScreen(
          streamUrl: url,
          title: cleanTitle,
          seriesName: widget.seriesName,
          episodeTitle: epTitle,
          streamId: episodeId,
          streamType: 'series',
          seriesId: widget.seriesId,
          coverUrl: cover ?? widget.coverUrl,
          startPosition: startPosition,
          seasonsWithEpisodes: seasonsMap,
          currentSeason: selectedSeason,
          episodeNum: episode['episode_num']?.toString(),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }

  Widget _buildTvChip(String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFFEAB308).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight ? const Color(0xFFEAB308).withValues(alpha: 0.6) : Colors.white12,
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isHighlight ? const Color(0xFFFDE047) : Colors.white70,
          fontSize: 11,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = xtreamInfo?['info'] is Map ? (xtreamInfo!['info'] as Map).cast<String, dynamic>() : null;
    
    final plot = info?['plot'] ?? info?['description'] ?? 'No synopsis available.';
    final director = info?['director'];
    final cast = info?['cast'] ?? info?['actors'];
    final genre = info?['genre'];
    final releaseDate = info?['releaseDate'] ?? info?['year'];
    final rating = info?['rating'] ?? info?['rating_5based'];

    if (GoatPlatform.isTv) {
      final episodes = (xtreamInfo?['episodes'] is Map && xtreamInfo!['episodes'][selectedSeason] is List)
          ? (xtreamInfo!['episodes'][selectedSeason] as List<dynamic>)
          : const [];
      final seasonKeys = (xtreamInfo?['episodes'] is Map)
          ? (xtreamInfo!['episodes'] as Map).keys.map((k) => k.toString()).toList()
          : <String>[];

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: 740,
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF160F26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. Top Section: Poster + Info (height: ~190)
              SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Series Poster (width: 135)
                    SizedBox(
                      width: 135,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.coverUrl != null)
                            Image.network(
                              widget.coverUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              cacheHeight: 300,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF23183C),
                                child: const Center(child: Icon(Icons.tv, size: 48, color: Colors.white24)),
                              ),
                            )
                          else
                            Container(
                              color: const Color(0xFF23183C),
                              child: const Center(child: Icon(Icons.tv, size: 48, color: Colors.white24)),
                            ),
                        ],
                      ),
                    ),
                    // Right: Info Column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Title + Close Button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.seriesName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final isFav = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.seriesId, streamType: 'series'))).value ?? false;
                                    Future<void> toggleFav() async {
                                      final account = ref.read(activeAccountProvider);
                                      if (account != null) {
                                        await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, widget.seriesId, 'series');
                                      }
                                    }
                                    return TvFocusable(
                                      borderRadius: BorderRadius.circular(16),
                                      focusScale: 1.05,
                                      onPressed: toggleFav,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isFav ? Colors.amber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                          color: isFav ? Colors.amber : Colors.white70,
                                          size: 16,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                TvFocusable(
                                  borderRadius: BorderRadius.circular(16),
                                  focusScale: 1.05,
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white70, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Meta chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (releaseDate != null) _buildTvChip('$releaseDate'),
                                if (rating != null && rating.toString().isNotEmpty)
                                  _buildTvChip('★ $rating', isHighlight: true),
                                if (genre != null && genre.toString().isNotEmpty)
                                  _buildTvChip('$genre'),
                                if (seasonKeys.isNotEmpty)
                                  _buildTvChip('${seasonKeys.length} ${seasonKeys.length == 1 ? AppLocalizations.of(context)!.season.trim() : 'Staffeln'}'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Plot
                            Text(
                              plot,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                            ),
                            const Spacer(),
                            if (cast != null && cast.toString().isNotEmpty)
                              Text(
                                'Besetzung: $cast',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white12),

              // 2. Seasons Selector Bar (height: 36)
              if (seasonKeys.isNotEmpty)
                Container(
                  height: 36,
                  color: Colors.black.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: seasonKeys.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final sKey = seasonKeys[idx];
                      final isSelected = selectedSeason == sKey;
                      return TvFocusable(
                        autofocus: (selectedSeason != null ? isSelected : idx == 0),
                        borderRadius: BorderRadius.circular(6),
                        focusScale: 1.02,
                        onPressed: () {
                          setState(() {
                            selectedSeason = sKey;
                            currentEpisodes = _getEpisodesForSeason(sKey);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFB388FF) : Colors.white10,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${AppLocalizations.of(context)!.season} $sKey',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 3. Episodes List (Expanded, scrollable)
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (errorMessage != null
                        ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.white60)))
                        : (episodes.isEmpty
                            ? const Center(child: Text('Keine Episoden gefunden', style: TextStyle(color: Colors.white54)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                itemCount: episodes.length,
                                itemBuilder: (context, index) {
                                  final ep = episodes[index] is Map ? (episodes[index] as Map).cast<String, dynamic>() : <String, dynamic>{};
                                  final epId = ep['id']?.toString() ?? '';
                                  final epNum = ep['episode_num']?.toString() ?? '${index + 1}';
                                  final epTitle = ep['title']?.toString() ?? 'Episode $epNum';
                                  final duration = ep['info']?['duration']?.toString() ?? '';
                                  final isTarget = epId == (_highlightEpisodeId ?? widget.initialEpisodeId);

                                  final progress = _episodeProgress[epId];
                                  final isCompleted = progress?.isCompleted == true ||
                                      (progress != null && progress.duration > 0 && (progress.position / progress.duration) >= 0.95);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: TvFocusable(
                                      autofocus: isTarget,
                                      borderRadius: BorderRadius.circular(8),
                                      focusScale: 1.01,
                                      onPressed: () => _playEpisode(ep),
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: isTarget
                                              ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                                              : Colors.white.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isTarget ? const Color(0xFFB388FF).withValues(alpha: 0.5) : Colors.white10,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isCompleted ? Icons.check_circle : Icons.play_arrow_rounded,
                                              size: 18,
                                              color: isCompleted ? Colors.greenAccent : const Color(0xFFB388FF),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'E$epNum',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white70),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                epTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                              ),
                                            ),
                                            if (duration.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                duration,
                                                style: const TextStyle(fontSize: 11, color: Colors.white38),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ))),
              ),
            ],
          ),
        ),
      );
    }
    
    String? backdropUrl;
    if (info?['backdrop_path'] != null && info!['backdrop_path'] is List && (info['backdrop_path'] as List).isNotEmpty) {
      backdropUrl = (info['backdrop_path'] as List).first;
    } else if (info?['cover'] != null) {
      backdropUrl = info!['cover'];
    } else if (widget.coverUrl != null) {
      backdropUrl = widget.coverUrl;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile 
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 36)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: isMobile ? double.infinity : (GoatPlatform.isTv ? 840 : 540),
        constraints: BoxConstraints(
          maxWidth: GoatPlatform.isTv ? 840 : 540,
          maxHeight: MediaQuery.sizeOf(context).height * (GoatPlatform.isTv ? 0.94 : 0.78),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: GoatPlatform.isTv ? 840 / 110 : 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.coverUrl != null)
                      Hero(
                        tag: 'series-${widget.seriesId}',
                        child: Image.network(
                          widget.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.tv, size: 64, color: Colors.white24),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.tv, size: 64, color: Colors.white24),
                      ),
                      
                    if (backdropUrl != null && backdropUrl != widget.coverUrl)
                      AnimatedOpacity(
                        opacity: isLoading ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Image.network(
                          backdropUrl, 
                          fit: BoxFit.cover,
                        ),
                      ),
                    
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              Theme.of(context).colorScheme.surface.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Close button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GoatPlatform.isTv
                          ? TvFocusable(
                              borderRadius: BorderRadius.circular(20),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black45,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Content
            Flexible(
              child: Builder(
                builder: (context) {
                  final hasProgress = widget.initialEpisodeId != null ||
                      widget.targetEpisodeNum != null ||
                      _highlightEpisodeId != null ||
                      _episodeProgress.values.any((p) => p.position > 0);

                  return SingleChildScrollView(
                    controller: _contentScrollController,
                    padding: isMobile 
                        ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
                        : (GoatPlatform.isTv ? const EdgeInsets.fromLTRB(16, 10, 16, 10) : const EdgeInsets.all(24.0)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.seriesName, 
                                style: (isMobile 
                                    ? Theme.of(context).textTheme.titleLarge 
                                    : (GoatPlatform.isTv ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineMedium))?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, child) {
                                final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.seriesId, streamType: 'series'))).value ?? false;
                                Future<void> toggleFav() async {
                                  final account = ref.read(activeAccountProvider);
                                  if (account != null) {
                                    await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, widget.seriesId, 'series');
                                  }
                                }
                                if (GoatPlatform.isTv) {
                                  return TvFocusable(
                                    autofocus: !hasProgress,
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: toggleFav,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite ? Colors.red : Colors.white70,
                                    size: 26,
                                  ),
                                ),
                              );
                            }
                            return IconButton(
                              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                              color: isFavorite ? Colors.red : null,
                              iconSize: isMobile ? 26 : 32,
                              onPressed: toggleFav,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (releaseDate != null || genre != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (releaseDate != null) Chip(label: Text(releaseDate.toString()), visualDensity: VisualDensity.compact),
                          if (genre != null) Chip(label: Text(genre.toString()), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    SizedBox(height: GoatPlatform.isTv ? 6 : 16),
                    Text(
                      plot,
                      maxLines: GoatPlatform.isTv ? 2 : null,
                      overflow: GoatPlatform.isTv ? TextOverflow.ellipsis : null,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    SizedBox(height: GoatPlatform.isTv ? 6 : 16),
                    if (director != null && director.toString().isNotEmpty) _buildInfoRow(context, Icons.movie_creation, AppLocalizations.of(context)!.director, director.toString()),
                    if (cast != null && cast.toString().isNotEmpty) _buildInfoRow(context, Icons.people, AppLocalizations.of(context)!.cast, cast.toString()),
                    
                    SizedBox(height: GoatPlatform.isTv ? 8 : 16),
                    const Divider(),
                    SizedBox(height: GoatPlatform.isTv ? 6 : 12),
                    
                    Text(AppLocalizations.of(context)!.episodes, style: TextStyle(fontSize: GoatPlatform.isTv ? 16 : 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: GoatPlatform.isTv ? 6 : 12),
                    
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (errorMessage != null)
                      Center(child: Text(errorMessage!))
                    else if (xtreamInfo?['episodes'] != null && xtreamInfo!['episodes'] is Map && (xtreamInfo!['episodes'] as Map).isNotEmpty)
                      ...[
                        // Seasons tabs
                        Container(
                          height: GoatPlatform.isTv ? 38 : 50,
                          margin: EdgeInsets.only(bottom: GoatPlatform.isTv ? 8 : 16),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: (xtreamInfo!['episodes'] as Map).keys.map((season) {
                              final seasonStr = season.toString();
                              final isSelected = selectedSeason == seasonStr;
                              if (GoatPlatform.isTv) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: TvFocusable(
                                    borderRadius: BorderRadius.circular(10),
                                    onPressed: () {
                                      setState(() {
                                        selectedSeason = seasonStr;
                                        currentEpisodes = _getEpisodesForSeason(seasonStr);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${AppLocalizations.of(context)!.season}$seasonStr',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : Colors.white70,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text('${AppLocalizations.of(context)!.season}$season'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) setState(() => selectedSeason = season.toString());
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        // Episodes list
                        Builder(
                          builder: (context) {
                            final episodes = (xtreamInfo!['episodes'] is Map && xtreamInfo!['episodes'][selectedSeason] is List) 
                                ? (xtreamInfo!['episodes'][selectedSeason] as List<dynamic>) 
                                : const [];
                            if (episodes.isEmpty) return const Text('No episodes found');

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int index = 0; index < episodes.length; index++) ...[
                                  Builder(
                                    builder: (context) {
                                      final ep = episodes[index] is Map ? (episodes[index] as Map).cast<String, dynamic>() : <String, dynamic>{};
                                      final epId = ep['id']?.toString() ?? '';
                                      final title = ep['title']?.toString() ?? 'Episode ${index + 1}';
                                      final duration = ep['info']?['duration']?.toString() ?? '';
                                      final isTarget = epId == (_highlightEpisodeId ?? widget.initialEpisodeId);

                                      final progress = _episodeProgress[epId];
                                      final isCompleted = progress?.isCompleted == true ||
                                          (progress != null && progress.duration > 0 && (progress.position / progress.duration) >= 0.95);
                                      final double progressRatio = (progress != null && progress.duration > 0)
                                          ? (isCompleted ? 1.0 : (progress.position / progress.duration).clamp(0.0, 1.0))
                                          : 0.0;
                                      
                                      final cardWidget = Card(
                                        margin: EdgeInsets.only(bottom: GoatPlatform.isTv ? 0 : 8),
                                        clipBehavior: Clip.antiAlias,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: isTarget
                                                ? Theme.of(context).colorScheme.primary
                                                : (isCompleted ? Colors.green.withValues(alpha: 0.4) : Colors.transparent),
                                            width: isTarget ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            ListTile(
                                              leading: Icon(
                                                isCompleted ? Icons.check_circle : Icons.play_circle_fill,
                                                size: 36,
                                                color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
                                              ),
                                              title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                                              subtitle: duration.isNotEmpty ? Text(duration, style: Theme.of(context).textTheme.bodySmall) : null,
                                              onTap: GoatPlatform.isTv ? null : () => _playEpisode(ep),
                                            ),
                                            if (progressRatio > 0.0)
                                              LinearProgressIndicator(
                                                value: progressRatio,
                                                backgroundColor: Colors.white12,
                                                color: isCompleted ? Colors.green : Colors.red,
                                                minHeight: 4,
                                              ),
                                          ],
                                        ),
                                      );

                                      if (GoatPlatform.isTv) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: TvFocusable(
                                            autofocus: hasProgress && isTarget,
                                            scrollAlignment: 0.3,
                                            focusScale: 1.01,
                                            borderRadius: BorderRadius.circular(10),
                                            onPressed: () => _playEpisode(ep),
                                            child: cardWidget,
                                          ),
                                        );
                                      }
                                      return cardWidget;
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
          ],
        ),
      ),
    );

  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 11)),
                Text(value, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

