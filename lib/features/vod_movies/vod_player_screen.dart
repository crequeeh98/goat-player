import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/main.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/player/widgets/mobile_gesture_detector.dart';
import '../../core/player/player_service.dart';
import '../../core/player/playback_controller.dart';
import '../../core/player/track_language_matcher.dart';
import '../../core/player/track_preference_service.dart';
import '../../core/utils/vod_title_cleaner.dart';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Tracks'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: player.state.tracks.audio.map((t) {
              return ListTile(
                title: Text(t.title ?? t.language ?? t.id),
                selected: player.state.track.audio == t,
                onTap: () {
                  player.setAudioTrack(t);
                  final mediaId = widget.streamType == 'series'
                      ? (widget.seriesId ?? _currentStreamId ?? '')
                      : (_currentStreamId ?? '');
                  if (mediaId.isNotEmpty) {
                    ref.read(trackPreferenceServiceProvider).setMediaAudioChoice(
                      mediaId,
                      t.title ?? t.language ?? t.id,
                    );
                  }
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showSubtitleTracksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                return ListTile(
                  title: Text(label),
                  selected: player.state.track.subtitle == t,
                  onTap: () {
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
                  },
                );
              }).toList();
            }(),
          ),
        ),
      ),
    );
  }
  
  void _startProgressTracking() {
    if (_currentStreamId == null || widget.streamType == null) return;
    
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isClosing) return;
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
    });
  }

  void _cycleFit() {
    setState(() {
      if (_fit == BoxFit.contain) {
        _fit = BoxFit.cover;
      } else if (_fit == BoxFit.cover) {
        _fit = BoxFit.fill;
      } else {
        _fit = BoxFit.contain;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aspect: ${_fit.name.toUpperCase()}'),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _progressTimer?.cancel();
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
    if (GoatPlatform.isTv) {
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
    
    setState(() {
      _isClosing = true;
      _canPop = true;
    });
    
    ref.read(playbackControllerProvider.notifier).stop();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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
              return Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
                    child: GoatPlatform.isMobile
                        ? MobileGestureDetector(
                            player: player,
                            enableSeek: false,
                            onDoubleTap: () => toggleFullscreen(context),
                            child: Video(
                              controller: controller,
                              fit: _fit,
                              controls: (state) => _VodControls(
                                key: ValueKey(_currentStreamId),
                                videoState: state,
                                onMinimize: _handleMinimize,
                                isEpisodeDrawerOpen: _isEpisodeDrawerOpen,
                                onCloseDrawer: () => setState(() => _isEpisodeDrawerOpen = false),
                              ),
                              subtitleViewConfiguration: const SubtitleViewConfiguration(
                                visible: true,
                                style: TextStyle(
                                  height: 1.3,
                                  fontSize: 26.0,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 2.0),
                                    Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 2.0),
                                    Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 2.0),
                                    Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 2.0),
                                    Shadow(offset: Offset(0, 2.0), color: Colors.black87, blurRadius: 4.0),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                padding: EdgeInsets.fromLTRB(32.0, 0.0, 32.0, 36.0),
                              ),
                            ),
                          )
                        : Video(
                            controller: controller,
                            fit: _fit,
                            controls: (state) => _VodControls(
                              key: ValueKey(_currentStreamId),
                              videoState: state,
                              onMinimize: _handleMinimize,
                              isEpisodeDrawerOpen: _isEpisodeDrawerOpen,
                              onCloseDrawer: () => setState(() => _isEpisodeDrawerOpen = false),
                            ),
                            subtitleViewConfiguration: const SubtitleViewConfiguration(
                              visible: true,
                              style: TextStyle(
                                height: 1.3,
                                fontSize: 26.0,
                                letterSpacing: 0.2,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 2.0),
                                  Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 2.0),
                                  Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 2.0),
                                  Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 2.0),
                                  Shadow(offset: Offset(0, 2.0), color: Colors.black87, blurRadius: 4.0),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              padding: EdgeInsets.fromLTRB(32.0, 0.0, 32.0, 36.0),
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
                if (widget.streamType == 'series' && _seasonsWithEpisodes.isNotEmpty)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _isEpisodeDrawerOpen ? 0 : -440,
                    top: 0,
                    bottom: 0,
                    child: InPlayerEpisodeDrawer(
                      seriesName: _currentSeriesName ?? widget.seriesName ?? _extractSeriesName(widget.title),
                      seasonsWithEpisodes: _seasonsWithEpisodes,
                      currentEpisodeId: _currentStreamId ?? '',
                      currentSeason: _currentSeason,
                      episodeProgress: _episodeProgress,
                      isOpen: _isEpisodeDrawerOpen,
                      onSelectEpisode: (ep) {
                        setState(() => _isEpisodeDrawerOpen = false);
                        _switchEpisode(ep);
                      },
                      onClose: () => setState(() => _isEpisodeDrawerOpen = false),
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
  final VoidCallback? onMinimize;
  final bool isEpisodeDrawerOpen;
  final VoidCallback? onCloseDrawer;

  const _VodControls({
    super.key,
    required this.videoState,
    this.onMinimize,
    this.isEpisodeDrawerOpen = false,
    this.onCloseDrawer,
  });

  @override
  State<_VodControls> createState() => _VodControlsState();
}

class _VodControlsState extends State<_VodControls> {
  late final Player _player = widget.videoState.widget.controller.player;
  late bool _isPlaying = _player.state.playing;
  bool _isControlsVisible = true;
  Timer? _hideTimer;
  StreamSubscription? _playingSub;
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isPlaying = _player.state.playing;
    _playingSub = _player.stream.playing.listen((p) {
      if (mounted) {
        setState(() {
          _isPlaying = p;
          if (!p) {
            _isControlsVisible = true;
            _hideTimer?.cancel();
          } else {
            _onPointerMove();
          }
        });
      }
    });
    _onPointerMove();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _hideTimer?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  DateTime _lastTimerReset = DateTime.now();

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
      _hideTimer?.cancel();
      if (_isPlaying) {
        _hideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _isPlaying) {
            setState(() => _isControlsVisible = false);
          }
        });
      }
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
    _focusNode.requestFocus();
    _onPointerMove();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;

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
            final current = _player.state.position;
            final newPosition = current - const Duration(seconds: 10);
            _player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
            _onPointerMove();
            return KeyEventResult.handled;
          }

          // Seek Forward (Arrow Right, Fast Forward)
          if (key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.mediaFastForward) {
            final current = _player.state.position;
            final duration = _player.state.duration;
            final newPosition = current + const Duration(seconds: 10);
            _player.seek(newPosition > duration ? duration : newPosition);
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
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _focusNode.requestFocus();
          _onPointerMove();
        },
        child: MouseRegion(
          onHover: (_) => _onPointerMove(),
          onEnter: (_) => _onPointerMove(),
          onExit: (_) => _onMouseExit(),
          child: AnimatedOpacity(
            opacity: (_isControlsVisible || !_isPlaying) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !(_isControlsVisible || !_isPlaying),
              child: Stack(
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
        ),
      ),
    );
  }
}

