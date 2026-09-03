import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../main.dart';
import '../dashboard/favorites_provider.dart';
import 'vod_player_screen.dart';
import '../../core/player/player_service.dart';

class MovieDetailModal extends ConsumerStatefulWidget {
  final String movieName;
  final String streamId;
  final String? posterUrl;

  const MovieDetailModal({
    super.key,
    required this.movieName,
    required this.streamId,
    this.posterUrl,
  });

  @override
  ConsumerState<MovieDetailModal> createState() => _MovieDetailModalState();
}

class _MovieDetailModalState extends ConsumerState<MovieDetailModal> {
  Map<String, dynamic>? xtreamInfo;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchXtreamData();
  }

  Future<void> _fetchXtreamData() async {
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
      final details = await client.getVodInfo(widget.streamId);
      if (mounted) {
        setState(() {
          xtreamInfo = details is Map<String, dynamic> ? details : null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Xtream Info Error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load movie details.';
        });
      }
    }
  }

  Future<void> _playMovie() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    
    // Check for existing progress
    final db = ref.read(databaseProvider);
    final progress = await db.playbackProgressDao.getProgress(widget.streamId);
    
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
    
    final movieData = xtreamInfo?['movie_data'] as Map<String, dynamic>?;
    final extension = movieData?['container_extension'] ?? 'mp4';
    
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final url = '$baseUrl/movie/${account.username}/${account.password}/${widget.streamId}.$extension';
    
    // Stop any active stream (e.g. Live TV) immediately so it doesn't fight for resources
    ref.read(playerServiceProvider).stop();

    // Seamless instant transition directly into VodPlayerScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => VodPlayerScreen(
          streamUrl: url,
          title: widget.movieName,
          streamId: widget.streamId,
          streamType: 'movie',
          coverUrl: widget.posterUrl,
          startPosition: startPosition,
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
    final info = xtreamInfo?['info'] as Map<String, dynamic>?;
    
    // Fallback UI data
    final plot = info?['plot'] ?? info?['description'] ?? 'No synopsis available.';
    final director = info?['director'];
    final cast = info?['cast'] ?? info?['actors'];
    final genre = info?['genre'];
    final rating = info?['rating'];
    final releaseDate = info?['releasedate'] ?? info?['year'];
    
    // Prefer backdrop, fallback to cover_big, fallback to posterUrl
    String? backdropUrl;
    if (info?['backdrop_path'] != null && info!['backdrop_path'] is List && (info['backdrop_path'] as List).isNotEmpty) {
      backdropUrl = (info['backdrop_path'] as List).first;
    } else if (info?['cover_big'] != null) {
      backdropUrl = info!['cover_big'];
    } else if (widget.posterUrl != null) {
      backdropUrl = widget.posterUrl;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile 
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 24)
          : const EdgeInsets.all(16),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
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
                    if (widget.posterUrl != null)
                      Hero(
                        tag: 'movie_${widget.streamId}',
                        child: Image.network(widget.posterUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.movie, size: 64, color: Colors.white))),
                      )
                    else
                      const Center(child: Icon(Icons.movie, size: 64, color: Colors.white)),
                      
                    if (backdropUrl != null && backdropUrl != widget.posterUrl)
                      AnimatedOpacity(
                        opacity: isLoading ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Image.network(backdropUrl, fit: BoxFit.cover),
                      ),
                    
                    // Gradient overlay to make text readable if we overlay anything
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
                    
                    // Floating Close Button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withAlpha(150),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                    widget.movieName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  if (isLoading)
                    const LinearProgressIndicator()
                  else if (errorMessage != null)
                    Text(errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                  else ...[
                    // Metadata row
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (releaseDate != null && releaseDate.toString().isNotEmpty)
                          _buildChip(context, releaseDate.toString()),
                        if (genre != null && genre.toString().isNotEmpty)
                          _buildChip(context, genre.toString()),
                        if (rating != null && rating.toString() != '0' && rating.toString().isNotEmpty)
                          _buildChip(context, '★ $rating', isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Plot
                    Text(
                      plot,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    
                    // Cast & Director
                    if (director != null && director.toString().isNotEmpty)
                      _buildInfoRow(context, Icons.movie_creation, AppLocalizations.of(context)!.director, director.toString()),
                    if (cast != null && cast.toString().isNotEmpty)
                      _buildInfoRow(context, Icons.people, AppLocalizations.of(context)!.cast, cast.toString()),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _playMovie,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(AppLocalizations.of(context)!.playMovie),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.streamId, streamType: 'movie'))).value ?? false;
                          return IconButton(
                            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                            color: isFavorite ? Colors.red : null,
                            iconSize: 32,
                            onPressed: () async {
                              final account = ref.read(activeAccountProvider);
                              if (account != null) {
                                await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, widget.streamId, 'movie');
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.amber.withAlpha(50) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: isHighlight ? Border.all(color: Colors.amber.withAlpha(100)) : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isHighlight ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
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
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
