import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../main.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/widgets/tv_focusable.dart';
import '../dashboard/favorites_provider.dart';
import 'vod_player_screen.dart';

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
          xtreamInfo = details is Map ? details.cast<String, dynamic>() : null;
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
    
    if (!mounted) return;
    
    final movieData = xtreamInfo?['movie_data'] is Map ? (xtreamInfo!['movie_data'] as Map).cast<String, dynamic>() : null;
    final extension = movieData?['container_extension'] ?? 'mp4';
    
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final url = '$baseUrl/movie/${account.username}/${account.password}/${widget.streamId}.$extension';
    
    if (!mounted) return;

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
    final info = xtreamInfo?['info'] is Map ? (xtreamInfo!['info'] as Map).cast<String, dynamic>() : null;
    
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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600 && !GoatPlatform.isTv;

    if (GoatPlatform.isTv || !isMobile) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Container(
          width: 820,
          height: 440,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Movie Poster (2:3 aspect ratio)
              SizedBox(
                width: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.posterUrl != null)
                      Hero(
                        tag: 'movie_${widget.streamId}',
                        child: Image.network(
                          widget.posterUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 330,
                          cacheHeight: 500,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF23183C),
                            child: const Center(child: Icon(Icons.movie, size: 64, color: Colors.white24)),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF23183C),
                        child: const Center(child: Icon(Icons.movie, size: 64, color: Colors.white24)),
                      ),
                  ],
                ),
              ),
              // Right: Content Details Column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title + Close Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.movieName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TvFocusable(
                            borderRadius: BorderRadius.circular(16),
                            focusScale: 1.05,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white70, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Meta Chips Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (releaseDate != null) _buildChip(context, '$releaseDate'),
                          if (rating != null && rating.toString().isNotEmpty)
                            _buildChip(context, '★ $rating', isHighlight: true),
                          if (info?['duration'] != null || info?['runtime'] != null)
                            _buildChip(context, '${info?['duration'] ?? info?['runtime']}'),
                          if (genre != null && genre.toString().isNotEmpty)
                            _buildChip(context, '$genre'),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Synopsis / Plot
                      Text(
                        plot,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                      ),
                      const SizedBox(height: 10),

                      // Director & Cast in compact layout
                      if (director != null && director.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'Regie: $director',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      if (cast != null && cast.toString().isNotEmpty)
                        Text(
                          'Besetzung: $cast',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),

                      const Spacer(),

                      // Action Buttons Row
                      Row(
                        children: [
                          TvFocusable(
                            autofocus: true,
                            focusScale: 1.02,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: _playMovie,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context)!.playMovie,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Consumer(
                            builder: (context, ref, child) {
                              final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.streamId, streamType: 'movie'))).value ?? false;
                              Future<void> toggleFav() async {
                                final account = ref.read(activeAccountProvider);
                                if (account != null) {
                                  await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, widget.streamId, 'movie');
                                }
                              }
                              return TvFocusable(
                                focusScale: 1.02,
                                borderRadius: BorderRadius.circular(10),
                                onPressed: toggleFav,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: isFavorite ? Colors.amber : Colors.white70,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppLocalizations.of(context)!.favorites,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isFavorite ? Colors.amber : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile 
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 36)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: isMobile ? double.infinity : (GoatPlatform.isTv ? 720 : 540),
        constraints: BoxConstraints(
          maxWidth: GoatPlatform.isTv ? 720 : 540,
          maxHeight: MediaQuery.sizeOf(context).height * (GoatPlatform.isTv ? 0.92 : 0.78),
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
              aspectRatio: GoatPlatform.isTv ? 720 / 130 : 16 / 9,
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
                      child: GoatPlatform.isTv
                          ? TvFocusable(
                              borderRadius: BorderRadius.circular(20),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(150),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            )
                          : IconButton.filled(
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
                padding: isMobile 
                    ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
                    : const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movieName,
                      style: (isMobile 
                          ? Theme.of(context).textTheme.titleLarge 
                          : Theme.of(context).textTheme.headlineMedium)?.copyWith(fontWeight: FontWeight.bold),
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
                ],
              ),
            ),
          ),
            
            // Pinned Middle-Bottom Action Footer
            Container(
              padding: isMobile 
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (GoatPlatform.isTv)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                      child: TvFocusable(
                        autofocus: true,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _playMovie,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, size: 24, color: Theme.of(context).colorScheme.onPrimary),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.playMovie,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (isMobile)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _playMovie,
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: Text(
                          AppLocalizations.of(context)!.playMovie,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                      child: ElevatedButton.icon(
                        onPressed: _playMovie,
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: Text(
                          AppLocalizations.of(context)!.playMovie,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: widget.streamId, streamType: 'movie'))).value ?? false;
                      Future<void> toggleFav() async {
                        final account = ref.read(activeAccountProvider);
                        if (account != null) {
                          await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, widget.streamId, 'movie');
                        }
                      }
                      if (GoatPlatform.isTv) {
                        return TvFocusable(
                          borderRadius: BorderRadius.circular(12),
                          onPressed: toggleFav,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.redAccent : Colors.white70,
                              size: 24,
                            ),
                          ),
                        );
                      }
                      return IconButton.filledTonal(
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                        color: isFavorite ? Colors.redAccent : Colors.white70,
                        iconSize: 24,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: toggleFav,
                      );
                    },
                  ),
                ],
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
