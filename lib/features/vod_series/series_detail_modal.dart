import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/vod_title_cleaner.dart';
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
        String? targetSeason = widget.initialSeason;
        final episodesMap = infoMap?['episodes'];
        if (targetSeason == null && episodesMap is Map && episodesMap.isNotEmpty) {
          final lastWatched = await ref.read(databaseProvider).playbackProgressDao.getLastWatchedForSeries(widget.seriesId);
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

        if (highlightId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _contentScrollController.hasClients) {
              final eps = currentEpisodes;
              final idx = eps.indexWhere((ep) => ep['id']?.toString() == highlightId);
              final targetOffset = idx != -1 ? (350.0 + idx * 72.0) : 350.0;
              _contentScrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
        }
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
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppLocalizations.of(ctx)!.startOver),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppLocalizations.of(ctx)!.resume),
              ),
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

  @override
  Widget build(BuildContext context) {
    final info = xtreamInfo?['info'] is Map ? (xtreamInfo!['info'] as Map).cast<String, dynamic>() : null;
    
    final plot = info?['plot'] ?? info?['description'] ?? 'No synopsis available.';
    final director = info?['director'];
    final cast = info?['cast'] ?? info?['actors'];
    final genre = info?['genre'];
    final releaseDate = info?['releaseDate'] ?? info?['year'];
    
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
        width: isMobile ? double.infinity : 540,
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
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
              aspectRatio: 16 / 9,
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
                      child: IconButton(
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
              child: SingleChildScrollView(
                controller: _contentScrollController,
                padding: isMobile 
                    ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
                    : const EdgeInsets.all(24.0),
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
                                : Theme.of(context).textTheme.headlineMedium)?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.seriesId, streamType: 'series'))).value ?? false;
                            return IconButton(
                              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                              color: isFavorite ? Colors.red : null,
                              iconSize: isMobile ? 26 : 32,
                              onPressed: () async {
                                final account = ref.read(activeAccountProvider);
                                if (account != null) {
                                  await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, widget.seriesId, 'series');
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (releaseDate != null || genre != null)
                      Wrap(
                        spacing: 8,
                        children: [
                          if (releaseDate != null) Chip(label: Text(releaseDate.toString()), visualDensity: VisualDensity.compact),
                          if (genre != null) Chip(label: Text(genre.toString()), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Text(plot, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                    const SizedBox(height: 24),
                    if (director != null && director.toString().isNotEmpty) _buildInfoRow(context, Icons.movie_creation, AppLocalizations.of(context)!.director, director.toString()),
                    if (cast != null && cast.toString().isNotEmpty) _buildInfoRow(context, Icons.people, AppLocalizations.of(context)!.cast, cast.toString()),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    Text(AppLocalizations.of(context)!.episodes, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (errorMessage != null)
                      Center(child: Text(errorMessage!))
                    else if (xtreamInfo?['episodes'] != null && xtreamInfo!['episodes'] is Map && (xtreamInfo!['episodes'] as Map).isNotEmpty)
                      ...[
                        // Seasons tabs
                        Container(
                          height: 50,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: (xtreamInfo!['episodes'] as Map).keys.map((season) {
                              final isSelected = selectedSeason == season.toString();
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
                            
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: episodes.length,
                              itemBuilder: (context, index) {
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
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
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
                                        onTap: () => _playEpisode(ep),
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
                              },
                            );
                          },
                        ),
                      ],
                  ],
                ),
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

