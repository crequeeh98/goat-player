import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../main.dart';
import '../dashboard/favorites_provider.dart';
import '../vod_movies/vod_player_screen.dart';

class SeriesDetailModal extends ConsumerStatefulWidget {
  final String seriesName;
  final String seriesId;
  final String? coverUrl;

  const SeriesDetailModal({
    super.key,
    required this.seriesName,
    required this.seriesId,
    this.coverUrl,
  });

  @override
  ConsumerState<SeriesDetailModal> createState() => _SeriesDetailModalState();
}

class _SeriesDetailModalState extends ConsumerState<SeriesDetailModal> {
  Map<String, dynamic>? xtreamInfo;
  bool isLoading = true;
  String? errorMessage;
  
  String? selectedSeason;
  List<dynamic> currentEpisodes = [];
  Map<String, dynamic> _episodeProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchSeriesData();
    _fetchProgress();
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
        setState(() {
          xtreamInfo = details is Map<String, dynamic> ? details : null;
          isLoading = false;
          
          // Auto-select first season
          final episodesMap = xtreamInfo?['episodes'];
          if (episodesMap != null && episodesMap is Map && episodesMap.isNotEmpty) {
            selectedSeason = episodesMap.keys.first.toString();
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
      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.resumePlayback ?? 'Resume Playback'),
          content: Text('${AppLocalizations.of(ctx)!.resumeFrom ?? 'Do you want to resume from'} ${_formatDuration(progress.position)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppLocalizations.of(ctx)!.startOver ?? 'Start Over'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppLocalizations.of(ctx)!.resume ?? 'Resume'),
            ),
          ],
        ),
      );
      
      if (resume == null) return;
      if (resume == true) {
        startPosition = progress.position;
      }
    }
    
    if (!mounted) return;
    
    final extension = episode['container_extension']?.toString() ?? 'mp4';
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final url = '$baseUrl/series/${account.username}/${account.password}/$episodeId.$extension';
    
    final epTitle = episode['title']?.toString() ?? 'Episode';
    final cover = episode['info']?['movie_image']?.toString();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VodPlayerScreen(
          streamUrl: url,
          title: '${widget.seriesName} - $epTitle',
          streamId: episodeId,
          streamType: 'series',
          seriesId: widget.seriesId,
          coverUrl: cover ?? widget.coverUrl,
          startPosition: startPosition,
        ),
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
    final info = xtreamInfo?['info'] as Map<String, dynamic>?;
    
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

        return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.seriesName, 
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.seriesId, streamType: 'series'))).value ?? false;
                            return IconButton(
                              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                              color: isFavorite ? Colors.red : null,
                              iconSize: 32,
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
                    if (director != null && director.toString().isNotEmpty) _buildInfoRow(context, Icons.movie_creation, AppLocalizations.of(context)!.director ?? 'Director', director.toString()),
                    if (cast != null && cast.toString().isNotEmpty) _buildInfoRow(context, Icons.people, AppLocalizations.of(context)!.cast ?? 'Cast', cast.toString()),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    Text(AppLocalizations.of(context)!.episodes ?? 'Episodes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (errorMessage != null)
                      Center(child: Text(errorMessage!))
                    else if (xtreamInfo?['episodes'] != null && (xtreamInfo!['episodes'] as Map).isNotEmpty)
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
                                  label: Text('${AppLocalizations.of(context)!.season ?? 'Season'} $season'),
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
                            final episodes = xtreamInfo!['episodes'][selectedSeason] as List<dynamic>? ?? [];
                            if (episodes.isEmpty) return const Text('No episodes found');
                            
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: episodes.length,
                              itemBuilder: (context, index) {
                                final ep = episodes[index] as Map<String, dynamic>;
                                final title = ep['title']?.toString() ?? 'Episode ${index + 1}';
                                final duration = ep['info']?['duration']?.toString() ?? '';
                                final hasProgress = ep['progress'] != null;
                                final progress = hasProgress ? ep['progress'] : null;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.play_circle_fill, size: 36),
                                        title: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                                        subtitle: duration.isNotEmpty ? Text(duration, style: Theme.of(context).textTheme.bodySmall) : null,
                                        onTap: () => _playEpisode(ep),
                                      ),
                                      if (hasProgress)
                                        LinearProgressIndicator(
                                          value: progress!.position / progress.duration,
                                          backgroundColor: Colors.transparent,
                                          color: Colors.red,
                                          minHeight: 3,
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

