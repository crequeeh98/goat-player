import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/main.dart';

import 'dart:io' show Platform;
import '../../core/player/widgets/mobile_gesture_detector.dart';
import '../../core/player/player_service.dart';
import '../../core/player/playback_controller.dart';

class VodPlayerScreen extends ConsumerStatefulWidget {
  final String streamUrl;
  final String title;
  final String? streamId;
  final String? streamType; // 'movie' or 'series'
  final String? seriesId;
  final String? coverUrl;
  final int? startPosition; // seconds

  const VodPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.streamId,
    this.streamType,
    this.seriesId,
    this.coverUrl,
    this.startPosition,
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
  Timer? _progressTimer;
  BoxFit _fit = BoxFit.contain;

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

      if (!_isStreamReady && uri == widget.streamUrl && hasVideo && !isBuffering) {
        if (widget.startPosition != null && widget.startPosition! > 0) {
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
          if (mounted) setState(() => _isStreamReady = true);
          _frameSub?.cancel();
        }
      }
    });

    // Safety fallback: 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (!_isStreamReady && mounted) {
        _restoreVolume();
        setState(() => _isStreamReady = true);
        _frameSub?.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
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
    final isReturningFromMiniPlayer = activePlayback != null &&
        activePlayback.streamUrl == widget.streamUrl &&
        activePlayback.isMinimized;

    if (isReturningFromMiniPlayer && player.state.position > Duration.zero) {
      _isStreamReady = true;
    } else {
      // Hold audio completely silent until video picture is actually rendered on screen
      _initialVolume = player.state.volume > 0 ? player.state.volume : 100.0;
      _isVolumeMutedForSync = true;
      player.setVolume(0);
      _isStreamReady = false;
    }
    
    // Auto-lock to landscape on mobile devices for cinema experience
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final currentPlayback = ref.read(playbackControllerProvider);
      if (currentPlayback == null || currentPlayback.streamUrl != widget.streamUrl) {
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
        if (player.state.position > Duration.zero) {
          if (mounted) setState(() => _isStreamReady = true);
        } else {
          _armFrameListener();
        }
      }
    });

    player.stream.track.listen((event) {
      if (mounted) setState(() {});
    });
    
    _startProgressTracking();
  }
  
  void _startProgressTracking() {
    if (widget.streamId == null || widget.streamType == null) return;
    
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isClosing) return;
      final position = player.state.position.inSeconds;
      final duration = player.state.duration.inSeconds;
      
      if (duration > 0 && position > 0) {
        final db = ref.read(databaseProvider);
        await db.playbackProgressDao.upsertProgress(
          PlaybackProgressItem(
            streamId: widget.streamId!,
            streamType: widget.streamType!,
            seriesId: widget.seriesId,
            title: widget.title,
            coverUrl: widget.coverUrl,
            position: position,
            duration: duration,
            updatedAt: DateTime.now(),
          ),
        );
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
    if (Platform.isAndroid || Platform.isIOS) {
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
    _restoreVolume();
    super.dispose();
  }

  void _handleMinimize() {
    if (_isClosing) return;
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
          : Stack(
              fit: StackFit.expand,
              children: [
                MaterialDesktopVideoControlsTheme(
                  normal: MaterialDesktopVideoControlsThemeData(
                    hideMouseOnControlsRemoval: true,
                    playAndPauseOnTap: false,
                    toggleFullscreenOnDoublePress: true,
                    keyboardShortcuts: {
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        if (ModalRoute.of(context)?.isCurrent != true) {
                          Navigator.of(context, rootNavigator: true).maybePop();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.space): () => player.playOrPause(),
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
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: () {
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
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.audiotrack, color: Colors.white),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: () {
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
                                          Navigator.pop(context);
                                        },
                                      );
                                    }).toList();
                                  }(),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.subtitles, color: Colors.white),
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
                        if (ModalRoute.of(context)?.isCurrent != true) {
                          Navigator.of(context, rootNavigator: true).maybePop();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.space): () => player.playOrPause(),
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
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: () {
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
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.audiotrack, color: Colors.white),
                      ),
                      MaterialDesktopCustomButton(
                        onPressed: () {
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
                                          Navigator.pop(context);
                                        },
                                      );
                                    }).toList();
                                  }(),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.subtitles, color: Colors.white),
                      ),
                      if (Platform.isAndroid || Platform.isIOS)
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
                    child: (Platform.isAndroid || Platform.isIOS)
                        ? MobileGestureDetector(
                            player: player,
                            enableSeek: false,
                            onDoubleTap: () => toggleFullscreen(context),
                            child: Video(
                              controller: controller,
                              fit: _fit,
                              controls: (state) => _VodControls(videoState: state),
                              subtitleViewConfiguration: const SubtitleViewConfiguration(
                                visible: true,
                                style: TextStyle(
                                  height: 1.3,
                                  fontSize: 28.0,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  backgroundColor: Color(0xb3000000),
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1.5),
                                      blurRadius: 3.0,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                padding: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 48.0),
                              ),
                            ),
                          )
                        : Video(
                            controller: controller,
                            fit: _fit,
                            controls: (state) => _VodControls(videoState: state),
                            subtitleViewConfiguration: const SubtitleViewConfiguration(
                              visible: true,
                              style: TextStyle(
                                height: 1.3,
                                fontSize: 28.0,
                                letterSpacing: 0.2,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                backgroundColor: Color(0xb3000000),
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1.5),
                                    blurRadius: 3.0,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              padding: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 48.0),
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
              ],
            ),
      ),
    );
  }
}

class _VodControls extends StatefulWidget {
  final VideoState videoState;

  const _VodControls({
    required this.videoState,
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
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  DateTime _lastTimerReset = DateTime.now();

  void _onPointerMove() {
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
    _onPointerMove();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _onPointerMove(),
      onEnter: (_) => _onPointerMove(),
      onExit: (_) => _onMouseExit(),
      child: Stack(
        children: [
          MaterialDesktopVideoControls(widget.videoState),
          Positioned.fill(
            child: Center(
              child: AnimatedOpacity(
                opacity: (_isControlsVisible || !_isPlaying) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: IgnorePointer(
                  ignoring: !(_isControlsVisible || !_isPlaying),
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
            ),
          ),
        ],
      ),
    );
  }
}

