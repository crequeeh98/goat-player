import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/main.dart';
import '../../core/utils/platform_utils.dart';
import 'package:flutter/foundation.dart';
import '../../core/player/widgets/stream_quality_badge.dart';
import '../../core/player/player_service.dart';
import '../../core/player/playback_controller.dart';
import '../../core/player/track_language_matcher.dart';
import '../../core/player/track_preference_service.dart';
import '../../core/utils/vod_title_cleaner.dart';
import '../../core/widgets/tv_focusable.dart';
import '../vod_series/widgets/in_player_episode_drawer.dart';

class VodPlayerScreen extends ConsumerStatefulWidget {
  final String streamUrl;
  final String title;
  final String? streamId;
  final String? streamType; // 'movie' or 'series'
  final String? seriesId;
  final String? coverUrl;
  final int? startPosition; // seconds
  final Map<String, List<dynamic>>? seasonsWithEpisodes;
  final String? currentSeason;
  final String? episodeNum;
  final String? seriesName;
  final String? episodeTitle;

  const VodPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.streamId,
    this.streamType,
    this.seriesId,
    this.coverUrl,
    this.startPosition,
    this.seasonsWithEpisodes,
    this.currentSeason,
    this.episodeNum,
    this.seriesName,
    this.episodeTitle,
  });

  @override
  ConsumerState<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends ConsumerState<VodPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool _isClosing = false;
  bool _canPop = false;
  bool _isStreamReady = false;
  bool _wasPlayingBeforeMinimize = true;
  bool _isVolumeMutedForSync = false;
  double _initialVolume = 100.0;
  StreamSubscription? _frameSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _tracksSub;
  Timer? _progressTimer;
  BoxFit _fit = BoxFit.contain;
  bool _showFitBanner = false;
  Timer? _fitBannerTimer;
  late final FocusNode _screenFocusNode = FocusNode(debugLabel: 'VodPlayerScreenFocus');

  late String _currentStreamUrl;
  late String _currentTitle;
  late String? _currentSeriesName;
  late String? _currentEpisodeTitle;
  late String? _currentStreamId;
  late String? _currentSeason;
  late String? _currentEpisodeNum;
  late String? _currentCoverUrl;

  Map<String, List<dynamic>> _seasonsWithEpisodes = {};
  Map<String, PlaybackProgressItem> _episodeProgress = {};
  bool _isEpisodeDrawerOpen = false;
  bool _isTrackModalOpen = false;
  bool _appliedAudioTrack = false;
  bool _appliedSubtitleTrack = false;
  String? _lastDemuxedTrackHash;
  late final ValueNotifier<String> _titleNotifier;

  static String _cleanCountryPrefix(String text) {
    var t = text.trim();
    final match = RegExp(r'^[A-Z]{2,4}\s*[-:|•]\s*').firstMatch(t);
    if (match != null) {
      t = t.substring(match.end).trim();
    }
    return t;
  }

  static String _extractSeriesName(String title) {
    final cleaned = _cleanCountryPrefix(title);
    if (cleaned.contains(' - ')) {
      return cleaned.split(' - ').first.trim();
    }
    return cleaned;
  }

  static String _extractEpisodeTitle(String title) {
    final cleaned = _cleanCountryPrefix(title);
    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      return parts.last.trim();
    }
    return cleaned;
  }

  static String _cleanDuplicatePrefix(String text) => VodTitleCleaner.cleanDuplicatePrefix(text);

  static String _formatEpisodeTitle({
    required String seriesName,
    required String season,
    required String epNum,
    required String epTitle,
  }) => VodTitleCleaner.formatDisplayTitle(
    seriesName: seriesName,
    season: season,
    epNum: epNum,
    epTitle: epTitle,
  );

  void _restoreVolume() {
    if (_isVolumeMutedForSync) {
      _isVolumeMutedForSync = false;
      player.setVolume(_initialVolume);
    }
  }

  void _armFrameListener() {
    if (_isStreamReady || !mounted) return;
    _frameSub?.cancel();

    int advancingTicks = 0;
    Duration? lastPos;
    final startTime = DateTime.now();

    _frameSub = player.stream.position.listen((pos) {
      final uri = player.state.playlist.medias.firstOrNull?.uri;
      final hasVideo = player.state.videoParams.w != null && player.state.videoParams.w! > 0;
      final isBuffering = player.state.buffering;

      if (!_isStreamReady && uri == _currentStreamUrl && hasVideo && !isBuffering) {
        if (widget.startPosition != null && widget.startPosition! > 0 && _currentStreamUrl == widget.streamUrl) {
          final targetSec = widget.startPosition!;
          if (pos.inSeconds < (targetSec - 5)) {
            // Still seeking to target keyframe, ignore premature ticks
            return;
          }
        }

        if (lastPos != null && pos != lastPos) {
          advancingTicks++;
        }
        lastPos = pos;

        // Ensure at least 5 frames advanced and at least 600ms have elapsed since stream opened
        final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
        if (advancingTicks >= 5 && elapsedMs >= 600) {
          _restoreVolume();
          if (mounted) {
            setState(() => _isStreamReady = true);
            _screenFocusNode.requestFocus();
            _handleTracksDemuxed(player.state.tracks);
          }
          _frameSub?.cancel();
        }
      }
    });

    // Safety fallback: 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (!_isStreamReady && mounted) {
        _restoreVolume();
        setState(() => _isStreamReady = true);
        _screenFocusNode.requestFocus();
        _handleTracksDemuxed(player.state.tracks);
        _frameSub?.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentStreamUrl = widget.streamUrl;
    final initialCleanTitle = _cleanDuplicatePrefix(widget.title);
    _currentTitle = initialCleanTitle;
    _titleNotifier = ValueNotifier<String>(initialCleanTitle);
    _currentSeriesName = widget.seriesName ?? _extractSeriesName(widget.title);
    _currentEpisodeTitle = widget.episodeTitle ?? _extractEpisodeTitle(widget.title);
    _currentStreamId = widget.streamId;
    _currentSeason = widget.currentSeason;
    _currentEpisodeNum = widget.episodeNum;
    _currentCoverUrl = widget.coverUrl;

    if (widget.seasonsWithEpisodes != null) {
      _seasonsWithEpisodes = Map.from(widget.seasonsWithEpisodes!);
    }

    final playerService = ref.read(playerServiceProvider);
    player = playerService.player;
    controller = playerService.controller;

    _wasPlayingBeforeMinimize = player.state.playing;
    _playingSub = player.stream.playing.listen((p) {
      if (!_isClosing && mounted) {
        _wasPlayingBeforeMinimize = p;
      }
    });

    final activePlayback = ref.read(playbackControllerProvider);
    final isReturningFromMiniPlayer = (activePlayback != null && activePlayback.streamUrl == widget.streamUrl) ||
        (player.state.playlist.medias.firstOrNull?.uri == widget.streamUrl);

    if (isReturningFromMiniPlayer && player.state.position > Duration.zero) {
      _isStreamReady = true;
      _isVolumeMutedForSync = false;
    } else {
      // Hold audio completely silent until video picture is actually rendered on screen
      _initialVolume = player.state.volume > 0 ? player.state.volume : (_initialVolume > 0 ? _initialVolume : 100.0);
      _isVolumeMutedForSync = true;
      player.setVolume(0);
      _isStreamReady = false;
    }
    
    // Auto-lock to landscape on mobile devices for cinema experience
    if (GoatPlatform.isMobile) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _screenFocusNode.requestFocus();
      final currentPlayback = ref.read(playbackControllerProvider);
      final isExistingStream = (currentPlayback != null && currentPlayback.streamUrl == widget.streamUrl) ||
          (player.state.playlist.medias.firstOrNull?.uri == widget.streamUrl);

      if (!isExistingStream) {
        await ref.read(playbackControllerProvider.notifier).playVod(
          title: widget.title,
          url: widget.streamUrl,
          streamType: widget.streamType == 'series' ? StreamType.series : StreamType.movie,
          streamId: widget.streamId,
          seriesId: widget.seriesId,
          coverUrl: widget.coverUrl,
          startPosition: widget.startPosition,
        );
        _armFrameListener();
      } else {
        // Returning from mini-player: continue from current playback without rewinding
        ref.read(playbackControllerProvider.notifier).expand();
        _restoreVolume();
        if (player.state.position > Duration.zero) {
          if (mounted) {
            setState(() => _isStreamReady = true);
            _screenFocusNode.requestFocus();
          }
        } else {
          _armFrameListener();
        }
      }
    });

    _setupListeners();
    _fetchSeriesDetailsIfNeeded();
    _startProgressTracking();
  }

  void _setupListeners() {
    _completedSub?.cancel();
    _completedSub = player.stream.completed.listen((completed) {
      if (completed && widget.streamType == 'series' && mounted && !_isClosing) {
        debugPrint('VodPlayerScreen: Stream completed. Auto-playing next episode...');
        _playNextEpisode(autoPlay: true);
      }
    });

    _tracksSub?.cancel();
    _tracksSub = player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      _handleTracksDemuxed(tracks);
    });
  }

  void _handleTracksDemuxed(Tracks tracks) {
    final currentHash = '${tracks.audio.map((a) => a.id).join(",")}|${tracks.subtitle.map((s) => s.id).join(",")}';
    if (currentHash == _lastDemuxedTrackHash && _appliedAudioTrack && _appliedSubtitleTrack) return;
    _lastDemuxedTrackHash = currentHash;

    final trackPref = ref.read(trackPreferenceServiceProvider);
    final mediaId = widget.streamType == 'series'
        ? (widget.seriesId ?? _currentStreamId ?? '')
        : (_currentStreamId ?? '');

    // 1. Audio track
    final realAudioTracks = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (!_appliedAudioTrack && realAudioTracks.isNotEmpty) {
      final rememberedAudio = trackPref.getMediaAudioChoice(mediaId);
      final targetAudio = rememberedAudio ?? trackPref.getPreferredAudioLanguage();
      final bestAudio = TrackLanguageMatcher.findBestAudioTrack(
        realAudioTracks,
        targetAudio,
        targetTitle: rememberedAudio,
      );
      if (bestAudio != null) {
        if (player.state.track.audio != bestAudio) {
          debugPrint('Auto-selecting audio track: ${bestAudio.title} (${bestAudio.language})');
          player.setAudioTrack(bestAudio);
        }
        _appliedAudioTrack = true;
      }
    }

    // 2. Subtitle track
    final targetSub = trackPref.getMediaSubtitleChoice(mediaId) ?? trackPref.getPreferredSubtitleLanguage();
    if (!_appliedSubtitleTrack) {
      if (targetSub.toLowerCase() == 'off' || targetSub.toLowerCase() == 'no') {
        final noSub = tracks.subtitle.firstWhere((t) => t.id == 'no', orElse: () => SubtitleTrack.no());
        ref.read(playerServiceProvider).setSubtitleTrack(noSub);
        _appliedSubtitleTrack = true;
      } else {
        final realSubTracks = tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
        if (realSubTracks.isNotEmpty) {
          final rememberedSub = trackPref.getMediaSubtitleChoice(mediaId);
          final activeAudioLang = player.state.track.audio.language ?? player.state.track.audio.title;
          final isAudioSame = TrackLanguageMatcher.matchesLanguage(activeAudioLang, null, targetSub);

          final bestSub = TrackLanguageMatcher.findBestSubtitleTrack(
            tracks.subtitle,
            targetSub,
            isAudioSameLanguage: isAudioSame,
            targetTitle: rememberedSub,
          );
          if (bestSub != null) {
            debugPrint('Auto-selecting subtitle track: ${bestSub.title} (${bestSub.language})');
            ref.read(playerServiceProvider).setSubtitleTrack(bestSub);
            _appliedSubtitleTrack = true;
          }
        }
      }
    }
  }

  Future<void> _fetchSeriesDetailsIfNeeded() async {
    if (widget.streamType != 'series' || widget.seriesId == null) return;

    final db = ref.read(databaseProvider);
    final progressList = await db.playbackProgressDao.getEpisodesProgressForSeries(widget.seriesId!);
    if (mounted) {
      setState(() {
        _episodeProgress = {for (var p in progressList) p.streamId: p};
      });
    }

    if (_seasonsWithEpisodes.isNotEmpty) return;

    final client = ref.read(xtreamClientProvider);
    if (client == null) return;

    try {
      final info = await client.getSeriesInfo(widget.seriesId!);
      if (info is Map && info['episodes'] is Map && mounted) {
        final rawEpisodes = info['episodes'] as Map;
        final mapped = <String, List<dynamic>>{};
        for (final entry in rawEpisodes.entries) {
          if (entry.value is List) {
            mapped[entry.key.toString()] = entry.value as List<dynamic>;
          }
        }
        setState(() {
          _seasonsWithEpisodes = mapped;
        });
      }
    } catch (e) {
      debugPrint('VodPlayerScreen failed to fetch series details: $e');
    }
  }

  Map<String, dynamic>? _getNextEpisode() {
    if (_seasonsWithEpisodes.isEmpty || _currentStreamId == null) return null;

    final sortedSeasonKeys = _seasonsWithEpisodes.keys.toList();
    sortedSeasonKeys.sort((a, b) {
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.compareTo(b);
    });

    final currentSeasonKey = _currentSeason ?? sortedSeasonKeys.first;
    final currentSeasonEpisodes = _seasonsWithEpisodes[currentSeasonKey] ?? [];

    final currentIndex = currentSeasonEpisodes.indexWhere(
      (ep) => ep['id']?.toString() == _currentStreamId,
    );

    if (currentIndex != -1 && currentIndex + 1 < currentSeasonEpisodes.length) {
      final nextEp = Map<String, dynamic>.from(currentSeasonEpisodes[currentIndex + 1] as Map);
      nextEp['season_key'] = currentSeasonKey;
      return nextEp;
    }

    // Rollover to next season
    final seasonIdx = sortedSeasonKeys.indexOf(currentSeasonKey);
    if (seasonIdx != -1 && seasonIdx + 1 < sortedSeasonKeys.length) {
      final nextSeasonKey = sortedSeasonKeys[seasonIdx + 1];
      final nextSeasonEpisodes = _seasonsWithEpisodes[nextSeasonKey] ?? [];
      if (nextSeasonEpisodes.isNotEmpty) {
        final nextEp = Map<String, dynamic>.from(nextSeasonEpisodes.first as Map);
        nextEp['season_key'] = nextSeasonKey;
        return nextEp;
      }
    }

    return null;
  }

  bool get _hasNextEpisode => _getNextEpisode() != null;

  Future<void> _switchEpisode(Map<String, dynamic> ep) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final nextId = ep['id']?.toString() ?? '';
    final nextExtension = ep['container_extension']?.toString() ?? 'mp4';
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final nextUrl = '$baseUrl/series/${account.username}/${account.password}/$nextId.$nextExtension';
    final nextEpTitle = ep['title']?.toString() ?? 'Episode';
    final nextSeason = ep['season']?.toString() ?? ep['season_key']?.toString() ?? _currentSeason ?? '1';
    final nextEpNum = ep['episode_num']?.toString() ?? '';
    final nextCover = ep['info']?['movie_image']?.toString() ?? _currentCoverUrl;

    if (_currentStreamId != null) {
      final db = ref.read(databaseProvider);
      final prevProgress = await db.playbackProgressDao.getProgress(_currentStreamId!);
      if (prevProgress != null && prevProgress.duration > 0) {
        await db.playbackProgressDao.markCompleted(_currentStreamId!);
      }
    }

    final seriesName = _currentSeriesName ?? widget.seriesName ?? _extractSeriesName(widget.title);
    final fullTitle = _formatEpisodeTitle(
      seriesName: seriesName,
      season: nextSeason,
      epNum: nextEpNum,
      epTitle: nextEpTitle,
    );

    setState(() {
      _currentStreamId = nextId;
      _currentStreamUrl = nextUrl;
      _currentSeriesName = seriesName;
      _currentEpisodeTitle = nextEpTitle;
      _currentSeason = nextSeason;
      _currentEpisodeNum = nextEpNum;
      _currentTitle = fullTitle;
      _currentCoverUrl = nextCover;
      _isStreamReady = false;
      _appliedAudioTrack = false;
      _appliedSubtitleTrack = false;
      _lastDemuxedTrackHash = null;
      _isVolumeMutedForSync = true;
    });
    _titleNotifier.value = fullTitle;
    player.setVolume(0);

    await ref.read(playbackControllerProvider.notifier).playVod(
      title: _currentTitle,
      url: nextUrl,
      streamType: StreamType.series,
      streamId: nextId,
      seriesId: widget.seriesId,
      coverUrl: nextCover,
      seriesName: seriesName,
      episodeTitle: nextEpTitle,
      currentSeason: nextSeason,
      episodeNum: nextEpNum,
      seasonsWithEpisodes: _seasonsWithEpisodes,
    );

    _armFrameListener();
    _startProgressTracking();
  }

  void _playNextEpisode({bool autoPlay = false}) {
    final nextEp = _getNextEpisode();
    if (nextEp != null) {
      _switchEpisode(nextEp);
      if (autoPlay && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nächste Folge: ${nextEp['title'] ?? ''}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAudioTracksDialog() {
    setState(() => _isTrackModalOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GoatPlatform.isTv ? const Color(0xFF1E1730) : null,
        title: const Text('Audio Tracks'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: player.state.tracks.audio.map((t) {
              final isSelected = player.state.track.audio == t;
              final label = t.title ?? t.language ?? t.id;
              void selectTrack() {
                player.setAudioTrack(t);
                final mediaId = widget.streamType == 'series'
                    ? (widget.seriesId ?? _currentStreamId ?? '')
                    : (_currentStreamId ?? '');
                if (mediaId.isNotEmpty) {
                  ref.read(trackPreferenceServiceProvider).setMediaAudioChoice(
                    mediaId,
                    label,
                  );
                }
                Navigator.pop(context);
              }
              if (GoatPlatform.isTv) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TvFocusable(
                    autofocus: isSelected,
                    focusScale: 1.0,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: selectTrack,
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                            : const Color(0xFF161124),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFB388FF) : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, size: 18, color: Color(0xFFB388FF)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return ListTile(
                title: Text(label),
                selected: isSelected,
                onTap: selectTrack,
              );
            }).toList(),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isTrackModalOpen = false);
      }
    });
  }

  void _showSubtitleTracksDialog() {
    setState(() => _isTrackModalOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GoatPlatform.isTv ? const Color(0xFF1E1730) : null,
        title: const Text('Subtitles'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: () {
              final uniqueTracks = <String, SubtitleTrack>{};
              for (final t in player.state.tracks.subtitle) {
                uniqueTracks.putIfAbsent(t.id, () => t);
              }
              return uniqueTracks.values.map((t) {
                String label = t.title ?? t.language ?? t.id;
                if (t.id == 'no') label = 'Off / Deaktiviert';
                if (t.id == 'auto') label = 'Auto / Automatisch';
                final isSelected = player.state.track.subtitle == t;
                void selectSub() {
                  ref.read(playerServiceProvider).setSubtitleTrack(t);
                  final mediaId = widget.streamType == 'series'
                      ? (widget.seriesId ?? _currentStreamId ?? '')
                      : (_currentStreamId ?? '');
                  if (mediaId.isNotEmpty) {
                    final choice = t.id == 'no' ? 'off' : (t.title ?? t.language ?? t.id);
                    ref.read(trackPreferenceServiceProvider).setMediaSubtitleChoice(
                      mediaId,
                      choice,
                    );
                  }
                  Navigator.pop(context);
                }
                if (GoatPlatform.isTv) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TvFocusable(
                      autofocus: isSelected,
                      focusScale: 1.0,
                      borderRadius: BorderRadius.circular(10),
                      onPressed: selectSub,
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                              : const Color(0xFF161124),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFB388FF) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, size: 18, color: Color(0xFFB388FF)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ListTile(
                  title: Text(label),
                  selected: isSelected,
                  onTap: selectSub,
                );
              }).toList();
            }(),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isTrackModalOpen = false);
      }
    });
  }
  
  Future<void> _saveCurrentProgress() async {
    if (_currentStreamId == null || widget.streamType == null) return;
    final position = player.state.position.inSeconds;
    final duration = player.state.duration.inSeconds;
    if (duration > 0 && position > 0) {
      final db = ref.read(databaseProvider);
      final isComp = (position / duration) >= 0.95;
      final item = PlaybackProgressItem(
        streamId: _currentStreamId!,
        streamType: widget.streamType!,
        seriesId: widget.seriesId,
        title: _currentSeriesName ?? _currentTitle,
        coverUrl: _currentCoverUrl,
        position: isComp ? duration : position,
        duration: duration,
        season: int.tryParse(_currentSeason ?? ''),
        episode: int.tryParse(_currentEpisodeNum ?? ''),
        episodeTitle: _currentEpisodeTitle ?? _currentTitle,
        isCompleted: isComp,
        updatedAt: DateTime.now(),
      );
      await db.playbackProgressDao.upsertProgress(item);
      if (mounted) {
        setState(() {
          _episodeProgress[_currentStreamId!] = item;
        });
      }
    }
  }

  void _startProgressTracking() {
    if (_currentStreamId == null || widget.streamType == null) return;
    
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isClosing) return;
      await _saveCurrentProgress();
    });
  }

  String _fitLabel(BuildContext context, BoxFit fit) {
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    switch (fit) {
      case BoxFit.cover:
        return 'Zoom';
      case BoxFit.fill:
        return isDe ? 'Ausfüllen' : 'Fill';
      case BoxFit.contain:
      default:
        return 'Original';
    }
  }

  void _cycleFit() {
    _fitBannerTimer?.cancel();
    setState(() {
      if (_fit == BoxFit.contain) {
        _fit = BoxFit.cover;
      } else if (_fit == BoxFit.cover) {
        _fit = BoxFit.fill;
      } else {
        _fit = BoxFit.contain;
      }
      _showFitBanner = true;
    });
    _fitBannerTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showFitBanner = false);
    });
  }

  @override
  void dispose() {
    if (GoatPlatform.isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _progressTimer?.cancel();
    _fitBannerTimer?.cancel();
    _frameSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();
    _restoreVolume();
    _titleNotifier.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _handleMinimize() {
    if (_isClosing) return;
    if (GoatPlatform.isTv || GoatPlatform.isMobile) {
      _handleClose();
      return;
    }
    _restoreVolume();
    
    final shouldKeepPlaying = _wasPlayingBeforeMinimize;
    
    setState(() {
      _isClosing = true;
      _canPop = true;
    });
    
    ref.read(playbackControllerProvider.notifier).minimize();
    
    if (shouldKeepPlaying) {
      player.play();
    } else {
      player.pause();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        if (shouldKeepPlaying && !player.state.playing) {
          player.play();
        }
      }
    });
  }

  void _handleClose() {
    if (_isClosing) return;
    _restoreVolume();
    _saveCurrentProgress();
    
    if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    setState(() {
      _isClosing = true;
      _canPop = true;
    });
    
    ref.read(playbackControllerProvider.notifier).stop();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  Widget _buildCenterTitle() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ValueListenableBuilder<String>(
            valueListenable: _titleNotifier,
            builder: (context, title, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  StreamQualityBadges(
                    player: player,
                    streamTitle: title,
                    isCompact: true,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleMinimize();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isClosing 
          ? const SizedBox.expand() 
          : Focus(
              focusNode: _screenFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) {
                if (GoatPlatform.isTv) {
                  return KeyEventResult.ignored;
                }
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.space) {
                    player.playOrPause();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    final current = player.state.position;
                    final newPosition = current - const Duration(seconds: 10);
                    player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    final current = player.state.position;
                    final duration = player.state.duration;
                    final newPosition = current + const Duration(seconds: 10);
                    player.seek(newPosition > duration ? duration : newPosition);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.keyN) {
                    if (widget.streamType == 'series' && _hasNextEpisode) {
                      _playNextEpisode();
                      return KeyEventResult.handled;
                    }
                  }
                  if (event.logicalKey == LogicalKeyboardKey.escape ||
                      event.logicalKey == LogicalKeyboardKey.goBack) {
                    if (_isEpisodeDrawerOpen) {
                      setState(() => _isEpisodeDrawerOpen = false);
                      return KeyEventResult.handled;
                    }
                    if (isFullscreen(context)) {
                      toggleFullscreen(context);
                      return KeyEventResult.handled;
                    } else {
                      _handleMinimize();
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _screenFocusNode.requestFocus();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                MaterialDesktopVideoControlsTheme(
                  normal: MaterialDesktopVideoControlsThemeData(
                    hideMouseOnControlsRemoval: true,
                    playAndPauseOnTap: false,
                    toggleFullscreenOnDoublePress: true,
                    keyboardShortcuts: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        if (_isEpisodeDrawerOpen) {
                          setState(() => _isEpisodeDrawerOpen = false);
                          return;
                        }
                        if (ModalRoute.of(context)?.isCurrent != true) {
                          Navigator.of(context, rootNavigator: true).maybePop();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.space): () => player.playOrPause(),
                      const SingleActivator(LogicalKeyboardKey.keyN): () {
                        if (widget.streamType == 'series' && _hasNextEpisode) {
                          _playNextEpisode();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                        final current = player.state.position;
                        final newPosition = current - const Duration(seconds: 10);
                        player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                      },
                      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                        final current = player.state.position;
                        final duration = player.state.duration;
                        final newPosition = current + const Duration(seconds: 10);
                        player.seek(newPosition > duration ? duration : newPosition);
                      },
                    },
                    topButtonBar: [
                      MaterialDesktopCustomButton(
                        onPressed: _handleMinimize,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      MaterialDesktopCustomButton(
                        onPressed: _handleClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                    bottomButtonBar: [
                      const MaterialPlayOrPauseButton(),
                      MaterialDesktopCustomButton(
                        onPressed: () {
                          final current = player.state.position;
                          final newPosition = current - const Duration(seconds: 10);
                          player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                        },
                        icon: const Icon(Icons.replay_10),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: () {
                          final current = player.state.position;
                          final duration = player.state.duration;
                          final newPosition = current + const Duration(seconds: 10);
                          player.seek(newPosition > duration ? duration : newPosition);
                        },
                        icon: const Icon(Icons.forward_10),
                      ),
                      const MaterialDesktopVolumeButton(),
                      const MaterialDesktopPositionIndicator(),
                      _buildCenterTitle(),
                      MaterialDesktopCustomButton(
                        onPressed: _showAudioTracksDialog,
                        icon: const Icon(Icons.audiotrack, color: Colors.white),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: _showSubtitleTracksDialog,
                        icon: const Icon(Icons.subtitles, color: Colors.white),
                      ),
                      if (widget.streamType == 'series' && _seasonsWithEpisodes.isNotEmpty)
                        MaterialDesktopCustomButton(
                          onPressed: () {
                            setState(() => _isEpisodeDrawerOpen = !_isEpisodeDrawerOpen);
                          },
                          icon: const Icon(Icons.video_library_outlined, color: Colors.white),
                        ),
                      if (widget.streamType == 'series' && _hasNextEpisode)
                        MaterialDesktopCustomButton(
                          onPressed: () => _playNextEpisode(),
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                        ),
                      const MaterialDesktopFullscreenButton(),
                    ],
                  ),
                  fullscreen: MaterialDesktopVideoControlsThemeData(
                    hideMouseOnControlsRemoval: true,
                    playAndPauseOnTap: false,
                    toggleFullscreenOnDoublePress: true,
                    keyboardShortcuts: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        if (_isEpisodeDrawerOpen) {
                          setState(() => _isEpisodeDrawerOpen = false);
                          return;
                        }
                        if (ModalRoute.of(context)?.isCurrent != true) {
                          Navigator.of(context, rootNavigator: true).maybePop();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.space): () => player.playOrPause(),
                      const SingleActivator(LogicalKeyboardKey.keyN): () {
                        if (widget.streamType == 'series' && _hasNextEpisode) {
                          _playNextEpisode();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                        final current = player.state.position;
                        final newPosition = current - const Duration(seconds: 10);
                        player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                      },
                      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                        final current = player.state.position;
                        final duration = player.state.duration;
                        final newPosition = current + const Duration(seconds: 10);
                        player.seek(newPosition > duration ? duration : newPosition);
                      },
                    },
                    topButtonBar: [
                      MaterialDesktopCustomButton(
                        onPressed: _handleMinimize,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      MaterialDesktopCustomButton(
                        onPressed: _handleClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                    bottomButtonBar: [
                      const MaterialPlayOrPauseButton(),
                      MaterialDesktopCustomButton(
                        onPressed: () {
                          final current = player.state.position;
                          final newPosition = current - const Duration(seconds: 10);
                          player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                        },
                        icon: const Icon(Icons.replay_10),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: () {
                          final current = player.state.position;
                          final duration = player.state.duration;
                          final newPosition = current + const Duration(seconds: 10);
                          player.seek(newPosition > duration ? duration : newPosition);
                        },
                        icon: const Icon(Icons.forward_10),
                      ),
                      const MaterialDesktopVolumeButton(),
                      const MaterialDesktopPositionIndicator(),
                      _buildCenterTitle(),
                      MaterialDesktopCustomButton(
                        onPressed: _showAudioTracksDialog,
                        icon: const Icon(Icons.audiotrack, color: Colors.white),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: _showSubtitleTracksDialog,
                        icon: const Icon(Icons.subtitles, color: Colors.white),
                      ),
                      if (widget.streamType == 'series' && _seasonsWithEpisodes.isNotEmpty)
                        MaterialDesktopCustomButton(
                          onPressed: () {
                            setState(() => _isEpisodeDrawerOpen = !_isEpisodeDrawerOpen);
                          },
                          icon: const Icon(Icons.video_library_outlined, color: Colors.white),
                        ),
                      if (widget.streamType == 'series' && _hasNextEpisode)
                        MaterialDesktopCustomButton(
                          onPressed: () => _playNextEpisode(),
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                        ),
                      if (GoatPlatform.isMobile)
                        MaterialDesktopCustomButton(
                          onPressed: _cycleFit,
                          icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                        ),
                      const MaterialDesktopFullscreenButton(),
                    ],
                  ),
                  child: Visibility(
                    visible: _isStreamReady,
                    maintainState: true,
                    child: Video(
                      controller: controller,
                      fit: _fit,
                      controls: (state) => _VodControls(
                        key: ValueKey(_currentStreamId),
                        videoState: state,
                        titleNotifier: _titleNotifier,
                        onMinimize: _handleMinimize,
                        onClose: _handleClose,
                        onShowAudioTracks: _showAudioTracksDialog,
                        onShowSubtitleTracks: _showSubtitleTracksDialog,
                        onCycleFit: GoatPlatform.isMobile ? _cycleFit : null,
                        isSeries: widget.streamType == 'series',
                        hasEpisodes: widget.streamType == 'series' && _seasonsWithEpisodes.isNotEmpty,
                        hasNextEpisode: widget.streamType == 'series' && _hasNextEpisode,
                        onToggleEpisodeDrawer: () {
                          setState(() => _isEpisodeDrawerOpen = !_isEpisodeDrawerOpen);
                        },
                        onPlayNextEpisode: () => _playNextEpisode(),
                        isEpisodeDrawerOpen: _isEpisodeDrawerOpen,
                        isTrackModalOpen: _isTrackModalOpen,
                        onCloseDrawer: () => setState(() => _isEpisodeDrawerOpen = false),
                      ),
                      subtitleViewConfiguration: const SubtitleViewConfiguration(
                        visible: false,
                      ),
                    ),
                  ),
                ),

                // Aspect Ratio Indicator Toast
                if (_showFitBanner)
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xD914141E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.aspect_ratio, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _fitLabel(context, _fit),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Pure solid black shield during loading/sync (NO poster)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _isStreamReady,
                    child: AnimatedOpacity(
                      opacity: _isStreamReady ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                ),

                // In-Player Episode Drawer backdrop & drawer
                if (widget.streamType == 'series' && _isEpisodeDrawerOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isEpisodeDrawerOpen = false),
                      child: const ColoredBox(color: Colors.black38),
                    ),
                  ),
                if (widget.streamType == 'series' && _seasonsWithEpisodes.isNotEmpty && _isEpisodeDrawerOpen)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: InPlayerEpisodeDrawer(
                      seriesName: _currentSeriesName ?? widget.seriesName ?? _extractSeriesName(widget.title),
                      seasonsWithEpisodes: _seasonsWithEpisodes,
                      currentEpisodeId: _currentStreamId ?? '',
                      currentSeason: _currentSeason,
                      episodeProgress: _episodeProgress,
                      isOpen: true,
                      onSelectEpisode: (ep) {
                        setState(() => _isEpisodeDrawerOpen = false);
                        _switchEpisode(ep);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _screenFocusNode.requestFocus();
                        });
                      },
                      onClose: () {
                        setState(() => _isEpisodeDrawerOpen = false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _screenFocusNode.requestFocus();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VodControls extends StatefulWidget {
  final VideoState videoState;
  final ValueListenable<String> titleNotifier;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final VoidCallback? onShowAudioTracks;
  final VoidCallback? onShowSubtitleTracks;
  final VoidCallback? onCycleFit;
  final bool isSeries;
  final bool hasEpisodes;
  final bool hasNextEpisode;
  final VoidCallback? onToggleEpisodeDrawer;
  final VoidCallback? onPlayNextEpisode;
  final bool isEpisodeDrawerOpen;
  final bool isTrackModalOpen;
  final VoidCallback? onCloseDrawer;

  const _VodControls({
    super.key,
    required this.videoState,
    required this.titleNotifier,
    this.onMinimize,
    this.onClose,
    this.onShowAudioTracks,
    this.onShowSubtitleTracks,
    this.onCycleFit,
    this.isSeries = false,
    this.hasEpisodes = false,
    this.hasNextEpisode = false,
    this.onToggleEpisodeDrawer,
    this.onPlayNextEpisode,
    this.isEpisodeDrawerOpen = false,
    this.isTrackModalOpen = false,
    this.onCloseDrawer,
  });

  @override
  State<_VodControls> createState() => _VodControlsState();
}

class _VodControlsState extends State<_VodControls> {
  late final Player _player = widget.videoState.widget.controller.player;
  late bool _isPlaying = _player.state.playing;
  late Duration _position = _player.state.position;
  late Duration _duration = _player.state.duration;
  double? _dragValue;
  bool _isControlsVisible = true;
  bool _showSkipLeft = false;
  bool _showSkipRight = false;
  int _lastSkipDelta = 10;
  DateTime _lastSeekKeyTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastScrubRepeatTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSeekAction = DateTime.fromMillisecondsSinceEpoch(0);
  int _scrubRepeatCount = 0;
  int _consecutiveSeekCount = 0;
  Timer? _hideTimer;
  Timer? _skipLeftTimer;
  Timer? _skipRightTimer;
  StreamSubscription? _playingSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  late final FocusNode _focusNode = FocusNode(debugLabel: 'VodControlsRoot');
  late final FocusNode _tvScrubberNode = FocusNode(debugLabel: 'TvVodScrubber');
  late final FocusNode _tvPlayPauseNode = FocusNode(debugLabel: 'TvVodPlayPause');
  late final FocusNode _tvRewindNode = FocusNode(debugLabel: 'TvVodRewind');
  late final FocusNode _tvForwardNode = FocusNode(debugLabel: 'TvVodForward');
  late final FocusNode _tvNextEpNode = FocusNode(debugLabel: 'TvVodNextEp');
  late final FocusNode _tvEpisodesNode = FocusNode(debugLabel: 'TvVodEpisodes');
  late final FocusNode _tvAudioNode = FocusNode(debugLabel: 'TvVodAudio');
  late final FocusNode _tvSubtitlesNode = FocusNode(debugLabel: 'TvVodSubtitles');
  late final FocusNode _tvFormatNode = FocusNode(debugLabel: 'TvVodFormat');
  bool _isTvScrubberFocused = false;

  FocusNode get _lastLeftBtnNode {
    if (widget.hasEpisodes) return _tvEpisodesNode;
    if (widget.hasNextEpisode) return _tvNextEpNode;
    return _tvForwardNode;
  }

  @override
  void initState() {
    super.initState();
    _isPlaying = _player.state.playing;
    _position = _player.state.position;
    _duration = _player.state.duration;

    _playingSub = _player.stream.playing.listen((p) {
      if (mounted) {
        setState(() {
          _isPlaying = p;
        });
        if (!p) {
          _hideTimer?.cancel();
          setState(() => _isControlsVisible = true);
        } else {
          _startHideTimer();
        }
      }
    });
    _posSub = _player.stream.position.listen((pos) {
      if (mounted && _dragValue == null && DateTime.now().difference(_lastSeekAction).inMilliseconds > 400) {
        setState(() => _position = pos);
      }
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
      }
    });

    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (GoatPlatform.isTv) {
          _tvPlayPauseNode.requestFocus();
        } else {
          _focusNode.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _tvScrubberNode.dispose();
    _tvPlayPauseNode.dispose();
    _tvRewindNode.dispose();
    _tvForwardNode.dispose();
    _tvNextEpNode.dispose();
    _tvEpisodesNode.dispose();
    _tvAudioNode.dispose();
    _tvSubtitlesNode.dispose();
    _tvFormatNode.dispose();
    _hideTimer?.cancel();
    _skipLeftTimer?.cancel();
    _skipRightTimer?.cancel();
    _playingSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _VodControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTrackModalOpen != oldWidget.isTrackModalOpen) {
      if (widget.isTrackModalOpen) {
        _hideTimer?.cancel();
        setState(() => _isControlsVisible = true);
      } else {
        _startHideTimer();
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isPlaying && !widget.isEpisodeDrawerOpen && !widget.isTrackModalOpen) {
      _hideTimer = Timer(Duration(seconds: GoatPlatform.isTv ? 8 : 3), () {
        if (mounted && _isPlaying && !widget.isEpisodeDrawerOpen && !widget.isTrackModalOpen) {
          setState(() => _isControlsVisible = false);
          if (GoatPlatform.isTv) {
            _focusNode.requestFocus();
          }
        }
      });
    }
  }

  DateTime _lastTimerReset = DateTime.fromMillisecondsSinceEpoch(0);

  void _onPointerMove() {
    if (!_focusNode.hasFocus && mounted) {
      _focusNode.requestFocus();
    }
    if (!_isControlsVisible) {
      setState(() => _isControlsVisible = true);
    }
    final now = DateTime.now();
    if (now.difference(_lastTimerReset).inMilliseconds > 250) {
      _lastTimerReset = now;
      _startHideTimer();
    }
  }

  void _onMouseExit() {
    _hideTimer?.cancel();
    if (mounted && _isPlaying) {
      setState(() => _isControlsVisible = false);
    }
  }

  void _togglePlayPause() {
    _player.playOrPause();
    if (!GoatPlatform.isTv) {
      _focusNode.requestFocus();
    }
    setState(() => _isControlsVisible = true);
    _startHideTimer();
  }

  int _computeAcceleratedDelta(int direction) {
    final now = DateTime.now();
    if (now.difference(_lastSeekKeyTime).inMilliseconds < 500) {
      _consecutiveSeekCount++;
    } else {
      _consecutiveSeekCount = 1;
    }
    _lastSeekKeyTime = now;
    final step = _consecutiveSeekCount >= 8 ? 30 : (_consecutiveSeekCount >= 4 ? 20 : 10);
    return direction * step;
  }

  void _seekRelative(int deltaSeconds, {bool showRipple = false}) {
    _lastSeekAction = DateTime.now();
    final current = _position;
    final duration = _duration > Duration.zero ? _duration : _player.state.duration;
    final target = current + Duration(seconds: deltaSeconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && target > duration ? duration : target);
    _player.seek(clamped);
    setState(() {
      _position = clamped;
      _lastSkipDelta = deltaSeconds.abs();
    });
    if (showRipple) {
      if (deltaSeconds < 0) {
        _skipLeftTimer?.cancel();
        setState(() => _showSkipLeft = true);
        _skipLeftTimer = Timer(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _showSkipLeft = false);
        });
      } else {
        _skipRightTimer?.cancel();
        setState(() => _showSkipRight = true);
        _skipRightTimer = Timer(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _showSkipRight = false);
        });
      }
    }
    if (_isControlsVisible) {
      _startHideTimer();
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildTvControlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    FocusNode? focusNode,
    bool isPrimary = false,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: TvFocusable(
        focusNode: focusNode,
        focusScale: 1.05,
        borderRadius: BorderRadius.circular(10),
        onKeyEvent: (node, event) {
          if (onKeyEvent != null) {
            final res = onKeyEvent(node, event);
            if (res == KeyEventResult.handled) return res;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _tvScrubberNode.requestFocus();
            _startHideTimer();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        onPressed: () {
          _startHideTimer();
          onPressed();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isPrimary ? 18 : 14,
            vertical: isPrimary ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF7C3AED)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPrimary ? const Color(0xFFB388FF) : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: isPrimary ? 22 : 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isPrimary ? 13.5 : 12.5,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTvCinemaHud(BuildContext context, double currentSecs, double totalSecs) {
    final progressRatio = (totalSecs > 0 ? (currentSecs / totalSecs) : 0.0).clamp(0.0, 1.0);
    final isDe = Localizations.localeOf(context).languageCode == 'de';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xB3000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xE608060E),
          ],
          stops: [0.0, 0.22, 0.62, 1.0],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // TOP HEADER: Title + Quality Badges
            Positioned(
              top: 20,
              left: 32,
              right: 32,
              child: ValueListenableBuilder<String>(
                valueListenable: widget.titleNotifier,
                builder: (context, title, _) {
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.isSeries ? (isDe ? 'SERIE' : 'SERIES') : (isDe ? 'FILM' : 'MOVIE'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      StreamQualityBadges(
                        player: _player,
                        streamTitle: title,
                        isCompact: false,
                      ),
                    ],
                  );
                },
              ),
            ),

            // CENTER PAUSE INDICATOR (only when paused)
            if (!_isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFB388FF), width: 2),
                  ),
                  child: const Icon(Icons.pause_rounded, color: Colors.white, size: 54),
                ),
              ),

            // BOTTOM 2-ROW SMART-TV HUD: Row 1 Scrubber, Row 2 Action Buttons
            Positioned(
              left: 32,
              right: 32,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ROW 1: Focusable Timeline Scrubber Bar
                  Focus(
                    focusNode: _tvScrubberNode,
                    onFocusChange: (focused) {
                      if (mounted) setState(() => _isTvScrubberFocused = focused);
                    },
                    onKeyEvent: (node, event) {
                      final key = event.logicalKey;
                      if (event is KeyDownEvent) {
                        if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
                          _scrubRepeatCount = 0;
                          _lastScrubRepeatTime = DateTime.now();
                          final dir = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
                          _seekRelative(_computeAcceleratedDelta(dir), showRipple: true);
                          _startHideTimer();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowDown) {
                          _tvPlayPauseNode.requestFocus();
                          _startHideTimer();
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.select ||
                            key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.numpadEnter) {
                          _togglePlayPause();
                          return KeyEventResult.handled;
                        }
                      } else if (event is KeyRepeatEvent) {
                        if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
                          final now = DateTime.now();
                          if (now.difference(_lastScrubRepeatTime).inMilliseconds >= 120) {
                            _lastScrubRepeatTime = now;
                            _scrubRepeatCount++;
                            final step = _scrubRepeatCount > 60
                                ? 60
                                : (_scrubRepeatCount > 38
                                    ? 40
                                    : (_scrubRepeatCount > 20
                                        ? 20
                                        : (_scrubRepeatCount > 8 ? 10 : 5)));
                            final dir = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
                            _seekRelative(dir * step, showRipple: true);
                            _startHideTimer();
                          }
                          return KeyEventResult.handled;
                        }
                      } else if (event is KeyUpEvent) {
                        if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
                          _scrubRepeatCount = 0;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isTvScrubberFocused
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isTvScrubberFocused
                              ? const Color(0xFFB388FF)
                              : Colors.white.withValues(alpha: 0.1),
                          width: _isTvScrubberFocused ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(Duration(seconds: currentSecs.round())),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, barConstraints) {
                                final barW = barConstraints.maxWidth;
                                final fillW = (barW * progressRatio).clamp(0.0, barW);
                                return SizedBox(
                                  height: 18,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      Container(
                                        height: _isTvScrubberFocused ? 8 : 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      Container(
                                        width: fillW,
                                        height: _isTvScrubberFocused ? 8 : 5,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF7C3AED), Color(0xFFB388FF)],
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      Positioned(
                                        left: (fillW - 7).clamp(0.0, (barW - 14).clamp(0.0, double.infinity)),
                                        child: Container(
                                          width: _isTvScrubberFocused ? 16 : 12,
                                          height: _isTvScrubberFocused ? 16 : 12,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: _isTvScrubberFocused
                                                ? const [
                                                    BoxShadow(
                                                      color: Color(0xFFB388FF),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ROW 2: Bottom Action Buttons Row
                  Row(
                    children: [
                      _buildTvControlBtn(
                        focusNode: _tvRewindNode,
                        icon: Icons.replay_10_rounded,
                        label: '-10s',
                        onPressed: () => _seekRelative(-10, showRipple: true),
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                            _tvPlayPauseNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                      ),
                      _buildTvControlBtn(
                        focusNode: _tvPlayPauseNode,
                        isPrimary: true,
                        icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        label: _isPlaying
                            ? (isDe ? 'Pause' : 'Pause')
                            : (isDe ? 'Abspielen' : 'Play'),
                        onPressed: _togglePlayPause,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              _tvRewindNode.requestFocus();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              _tvForwardNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                      ),
                      _buildTvControlBtn(
                        focusNode: _tvForwardNode,
                        icon: Icons.forward_10_rounded,
                        label: '+10s',
                        onPressed: () => _seekRelative(10, showRipple: true),
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              _tvPlayPauseNode.requestFocus();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              if (widget.hasNextEpisode) {
                                _tvNextEpNode.requestFocus();
                              } else if (widget.hasEpisodes) {
                                _tvEpisodesNode.requestFocus();
                              } else {
                                _tvAudioNode.requestFocus();
                              }
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                      ),
                      if (widget.hasNextEpisode)
                        _buildTvControlBtn(
                          focusNode: _tvNextEpNode,
                          icon: Icons.skip_next_rounded,
                          label: isDe ? 'Nächste Folge' : 'Next Ep',
                          onPressed: () => widget.onPlayNextEpisode?.call(),
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                _tvForwardNode.requestFocus();
                                return KeyEventResult.handled;
                              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                if (widget.hasEpisodes) {
                                  _tvEpisodesNode.requestFocus();
                                } else {
                                  _tvAudioNode.requestFocus();
                                }
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                        ),
                      if (widget.hasEpisodes)
                        _buildTvControlBtn(
                          focusNode: _tvEpisodesNode,
                          icon: Icons.video_library_outlined,
                          label: isDe ? 'Folgen' : 'Episodes',
                          onPressed: () => widget.onToggleEpisodeDrawer?.call(),
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                if (widget.hasNextEpisode) {
                                  _tvNextEpNode.requestFocus();
                                } else {
                                  _tvForwardNode.requestFocus();
                                }
                                return KeyEventResult.handled;
                              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                _tvAudioNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                        ),
                      const Spacer(),
                      _buildTvControlBtn(
                        focusNode: _tvAudioNode,
                        icon: Icons.audiotrack_rounded,
                        label: 'Audio',
                        onPressed: () => widget.onShowAudioTracks?.call(),
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              _lastLeftBtnNode.requestFocus();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              _tvSubtitlesNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                      ),
                      _buildTvControlBtn(
                        focusNode: _tvSubtitlesNode,
                        icon: Icons.subtitles_rounded,
                        label: isDe ? 'Untertitel' : 'Subtitles',
                        onPressed: () => widget.onShowSubtitleTracks?.call(),
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              _tvAudioNode.requestFocus();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.onCycleFit != null && !GoatPlatform.isTv) {
                              _tvFormatNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                      ),
                      if (widget.onCycleFit != null && !GoatPlatform.isTv)
                        _buildTvControlBtn(
                          focusNode: _tvFormatNode,
                          icon: Icons.aspect_ratio_rounded,
                          label: isDe ? 'Format' : 'Format',
                          onPressed: () => widget.onCycleFit?.call(),
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              _tvSubtitlesNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSecs = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final currentSecs = (_dragValue ?? _position.inSeconds.toDouble()).clamp(0.0, totalSecs);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;

          if (GoatPlatform.isTv) {
            if (widget.isEpisodeDrawerOpen) {
              if (key == LogicalKeyboardKey.escape ||
                  key == LogicalKeyboardKey.backspace ||
                  key == LogicalKeyboardKey.goBack) {
                widget.onCloseDrawer?.call();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _tvEpisodesNode.requestFocus();
                });
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }

            // Dedicated Media Remote keys work anytime
            if (key == LogicalKeyboardKey.mediaPlayPause ||
                key == LogicalKeyboardKey.mediaPlay ||
                key == LogicalKeyboardKey.mediaPause) {
              _togglePlayPause();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaRewind) {
              _seekRelative(_computeAcceleratedDelta(-1), showRipple: true);
              setState(() => _isControlsVisible = true);
              _startHideTimer();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaFastForward) {
              _seekRelative(_computeAcceleratedDelta(1), showRipple: true);
              setState(() => _isControlsVisible = true);
              _startHideTimer();
              return KeyEventResult.handled;
            }

            final hudShown = _isControlsVisible || !_isPlaying;

            // Back key on TV: 1. Hide HUD if visible while playing; 2. Exit VOD player
            if (key == LogicalKeyboardKey.escape ||
                key == LogicalKeyboardKey.backspace ||
                key == LogicalKeyboardKey.goBack) {
              if (_isControlsVisible && _isPlaying) {
                _hideTimer?.cancel();
                setState(() => _isControlsVisible = false);
                _focusNode.requestFocus();
                return KeyEventResult.handled;
              }
              (widget.onClose ?? widget.onMinimize)?.call();
              return KeyEventResult.handled;
            }

            // When HUD is hidden:
            // - Left/Right immediately scrubs +/-10s (accelerated), wakes HUD & focuses Scrubber
            // - Up/Down/OK wakes HUD & focuses Play/Pause button
            if (!hudShown) {
              if (key == LogicalKeyboardKey.arrowLeft) {
                _seekRelative(_computeAcceleratedDelta(-1), showRipple: true);
                setState(() => _isControlsVisible = true);
                _startHideTimer();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _tvScrubberNode.requestFocus();
                });
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                _seekRelative(_computeAcceleratedDelta(1), showRipple: true);
                setState(() => _isControlsVisible = true);
                _startHideTimer();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _tvScrubberNode.requestFocus();
                });
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowUp ||
                  key == LogicalKeyboardKey.arrowDown ||
                  key == LogicalKeyboardKey.select ||
                  key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.numpadEnter) {
                setState(() => _isControlsVisible = true);
                _startHideTimer();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _tvEpisodesNode.requestFocus();
                });
                return KeyEventResult.handled;
              }
            } else {
              // HUD is visible: reset auto-hide timer on any D-Pad activity
              _startHideTimer();
            }
            return KeyEventResult.ignored;
          }

          // Play / Pause toggle (Space, Select, Enter, Remote Play/Pause)
          if (key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.mediaPlayPause ||
              key == LogicalKeyboardKey.mediaPlay ||
              key == LogicalKeyboardKey.mediaPause) {
            _togglePlayPause();
            return KeyEventResult.handled;
          }

          // Seek Backward (Arrow Left, Rewind)
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.mediaRewind) {
            _seekRelative(-10);
            _onPointerMove();
            return KeyEventResult.handled;
          }

          // Seek Forward (Arrow Right, Fast Forward)
          if (key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.mediaFastForward) {
            _seekRelative(10);
            _onPointerMove();
            return KeyEventResult.handled;
          }

          // D-Pad Up: Reveal controls & extend hide timer
          if (key == LogicalKeyboardKey.arrowUp) {
            _onPointerMove();
            return KeyEventResult.handled;
          }

          // D-Pad Down: Hide controls immediately
          if (key == LogicalKeyboardKey.arrowDown) {
            if (_isControlsVisible) {
              setState(() => _isControlsVisible = false);
              return KeyEventResult.handled;
            }
          }

          // Back keys (Escape, Backspace, Android/TV GoBack, Tizen 10009, webOS 461)
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.backspace ||
              key == LogicalKeyboardKey.goBack) {
            if (widget.isEpisodeDrawerOpen) {
              widget.onCloseDrawer?.call();
              return KeyEventResult.handled;
            }
            if (isFullscreen(context)) {
              toggleFullscreen(context);
              return KeyEventResult.handled;
            } else if (widget.onMinimize != null) {
              widget.onMinimize!();
              return KeyEventResult.handled;
            }
          }
        } else if (event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.mediaRewind ||
              key == LogicalKeyboardKey.mediaFastForward) {
            final now = DateTime.now();
            if (now.difference(_lastScrubRepeatTime).inMilliseconds >= 120) {
              _lastScrubRepeatTime = now;
              _scrubRepeatCount++;
              final step = _scrubRepeatCount > 60
                  ? 60
                  : (_scrubRepeatCount > 38
                      ? 40
                      : (_scrubRepeatCount > 20
                          ? 20
                          : (_scrubRepeatCount > 8 ? 10 : 5)));
              final isLeft = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.mediaRewind;
              _seekRelative((isLeft ? -1 : 1) * step, showRipple: true);
              if (!_isControlsVisible) setState(() => _isControlsVisible = true);
              _startHideTimer();
            }
            return KeyEventResult.handled;
          }
        } else if (event is KeyUpEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.mediaRewind ||
              key == LogicalKeyboardKey.mediaFastForward) {
            _scrubRepeatCount = 0;
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.requestFocus();
              if (widget.isEpisodeDrawerOpen) {
                widget.onCloseDrawer?.call();
                _startHideTimer();
                return;
              }
              if (GoatPlatform.isTv) {
                setState(() => _isControlsVisible = !_isControlsVisible);
                if (_isControlsVisible) {
                  _startHideTimer();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _tvPlayPauseNode.requestFocus();
                  });
                } else {
                  _hideTimer?.cancel();
                  _focusNode.requestFocus();
                }
                return;
              }
              if (GoatPlatform.isMobile) {
                setState(() => _isControlsVisible = !_isControlsVisible);
                if (_isControlsVisible) {
                  _startHideTimer();
                } else {
                  _hideTimer?.cancel();
                }
              } else {
                _onPointerMove();
              }
            },
            onDoubleTapDown: GoatPlatform.isPhone
                ? (details) {
                    final dx = details.localPosition.dx;
                    final w = constraints.maxWidth;
                    if (dx < w * 0.45) {
                      _seekRelative(-10, showRipple: true);
                    } else if (dx > w * 0.55) {
                      _seekRelative(10, showRipple: true);
                    } else {
                      _togglePlayPause();
                    }
                  }
                : null,
            onDoubleTap: GoatPlatform.isPhone ? () {} : null,
            child: MouseRegion(
              onHover: (_) => _onPointerMove(),
              onEnter: (_) => _onPointerMove(),
              onExit: (_) => _onMouseExit(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Smoothly elevated subtitle overlay
                  StreamBuilder<List<String>>(
                    stream: _player.stream.subtitle,
                    initialData: _player.state.subtitle,
                    builder: (context, snapshot) {
                      final textList = snapshot.data ?? [];
                      if (textList.isEmpty || textList.every((s) => s.trim().isEmpty)) {
                        return const SizedBox.shrink();
                      }
                      final text = textList.join('\n');
                      final hudActive = (_isControlsVisible || !_isPlaying) && !widget.isEpisodeDrawerOpen;
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        left: 32,
                        right: 32,
                        bottom: hudActive ? (GoatPlatform.isMobile ? 100.0 : 136.0) : (GoatPlatform.isMobile ? 22.0 : 36.0),
                        child: IgnorePointer(
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.3,
                              fontSize: GoatPlatform.isMobile ? 19.0 : 26.0,
                              letterSpacing: 0.2,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: GoatPlatform.isMobile
                                  ? const [
                                      Shadow(offset: Offset(-1.0, -1.0), color: Colors.black, blurRadius: 1.5),
                                      Shadow(offset: Offset(1.0, -1.0), color: Colors.black, blurRadius: 1.5),
                                      Shadow(offset: Offset(1.0, 1.0), color: Colors.black, blurRadius: 1.5),
                                      Shadow(offset: Offset(-1.0, 1.0), color: Colors.black, blurRadius: 1.5),
                                      Shadow(offset: Offset(0, 1.5), color: Colors.black87, blurRadius: 3.0),
                                    ]
                                  : const [
                                      Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 2.0),
                                      Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 2.0),
                                      Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 2.0),
                                      Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 2.0),
                                      Shadow(offset: Offset(0, 2.0), color: Colors.black87, blurRadius: 4.0),
                                    ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Controls Overlay
                  AnimatedOpacity(
                    opacity: (_isControlsVisible || !_isPlaying) && !widget.isEpisodeDrawerOpen ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: (!(_isControlsVisible || !_isPlaying)) || widget.isEpisodeDrawerOpen,
                      child: GoatPlatform.isTv
                          ? _buildTvCinemaHud(context, currentSecs, totalSecs)
                          : GoatPlatform.isMobile
                          ? Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black54,
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black87,
                                  ],
                                  stops: [0.0, 0.25, 0.7, 1.0],
                                ),
                              ),
                              child: SafeArea(
                                child: Stack(
                                  children: [
                                    // TOP BAR: Back button (left) & Aspect Ratio (right)
                                    Positioned(
                                      top: 8,
                                      left: 12,
                                      right: 12,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                            onPressed: widget.onClose ?? widget.onMinimize,
                                          ),
                                          const Spacer(),
                                          if (widget.onCycleFit != null)
                                            IconButton(
                                              icon: const Icon(Icons.aspect_ratio, color: Colors.white, size: 24),
                                              onPressed: () {
                                                widget.onCycleFit!();
                                                _startHideTimer();
                                              },
                                            ),
                                        ],
                                      ),
                                    ),

                                    // CENTER: Play / Pause Button
                                    Center(
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black45,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          iconSize: 68,
                                          color: Colors.white,
                                          icon: Icon(
                                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                          ),
                                          onPressed: _togglePlayPause,
                                        ),
                                      ),
                                    ),

                                    // BOTTOM BAR: Seek Slider + Controls Row (like Windows without Volume)
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 6,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Seek Bar
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: const Color(0xFFB388FF),
                                              inactiveTrackColor: Colors.white24,
                                              thumbColor: Colors.white,
                                              overlayColor: const Color(0x33B388FF),
                                              trackHeight: 3.5,
                                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                                            ),
                                            child: Slider(
                                              value: currentSecs,
                                              min: 0.0,
                                              max: totalSecs,
                                              onChangeStart: (v) {
                                                _hideTimer?.cancel();
                                                setState(() => _dragValue = v);
                                              },
                                              onChanged: (v) {
                                                setState(() => _dragValue = v);
                                              },
                                              onChangeEnd: (v) {
                                                final target = Duration(seconds: v.round());
                                                _player.seek(target);
                                                setState(() {
                                                  _position = target;
                                                  _dragValue = null;
                                                });
                                                _startHideTimer();
                                              },
                                            ),
                                          ),

                                          // Bottom Button Row
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                visualDensity: VisualDensity.compact,
                                                onPressed: _togglePlayPause,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 22),
                                                visualDensity: VisualDensity.compact,
                                                onPressed: () => _seekRelative(-10),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 22),
                                                visualDensity: VisualDensity.compact,
                                                onPressed: () => _seekRelative(10),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${_formatDuration(Duration(seconds: currentSecs.round()))} / ${_formatDuration(_duration)}',
                                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                              ),

                                              // Center Title & Quality Badges
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                                  child: ValueListenableBuilder<String>(
                                                    valueListenable: widget.titleNotifier,
                                                    builder: (context, title, _) {
                                                      return Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            title,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 13.5,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            textAlign: TextAlign.center,
                                                          ),
                                                          const SizedBox(height: 2),
                                                          StreamQualityBadges(
                                                            player: _player,
                                                            streamTitle: title,
                                                            isCompact: true,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),

                                              // Right Action Buttons: Audio, Subtitles, Episode Drawer, Next Episode
                                              IconButton(
                                                icon: const Icon(Icons.audiotrack, color: Colors.white, size: 22),
                                                visualDensity: VisualDensity.compact,
                                                onPressed: () {
                                                  _startHideTimer();
                                                  widget.onShowAudioTracks?.call();
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.subtitles, color: Colors.white, size: 22),
                                                visualDensity: VisualDensity.compact,
                                                onPressed: () {
                                                  _startHideTimer();
                                                  widget.onShowSubtitleTracks?.call();
                                                },
                                              ),
                                              if (widget.hasEpisodes)
                                                IconButton(
                                                  icon: const Icon(Icons.video_library_outlined, color: Colors.white, size: 22),
                                                  visualDensity: VisualDensity.compact,
                                                  onPressed: () {
                                                    widget.onToggleEpisodeDrawer?.call();
                                                  },
                                                ),
                                              if (widget.hasNextEpisode)
                                                IconButton(
                                                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                                                  visualDensity: VisualDensity.compact,
                                                  onPressed: () {
                                                    widget.onPlayNextEpisode?.call();
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                MaterialDesktopVideoControls(widget.videoState),
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        iconSize: 76,
                                        color: Colors.white,
                                        icon: Icon(
                                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                        ),
                                        onPressed: _togglePlayPause,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Double-Tap / TV Scrub Left/Right Visual Indicator (-10s / +10s / 30s / 60s)
                  if (_showSkipLeft)
                    Positioned(
                      left: 48,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.replay_10, color: Colors.white, size: 26),
                                const SizedBox(width: 6),
                                Text('-${_lastSkipDelta}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_showSkipRight)
                    Positioned(
                      right: 48,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('+${_lastSkipDelta}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(width: 6),
                                const Icon(Icons.forward_10, color: Colors.white, size: 26),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

