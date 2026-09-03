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
  bool _isPlaying = true;
  bool _isControlsVisible = true;
  bool _isVolumeMutedForSync = false;
  double _initialVolume = 100.0;
  Timer? _controlsTimer;
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

  void _onPointerMove() {
    if (!_isControlsVisible) {
      setState(() => _isControlsVisible = true);
    }
    _controlsTimer?.cancel();
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _isControlsVisible = false);
        }
      });
    }
  }

  void _toggleCenterPlayPause() {
    player.playOrPause();
    _onPointerMove();
  }

  @override
  void initState() {
    super.initState();
    final playerService = ref.read(playerServiceProvider);
    player = playerService.player;
    controller = playerService.controller;

    _isPlaying = player.state.playing;
    _wasPlayingBeforeMinimize = player.state.playing;
    _playingSub = player.stream.playing.listen((p) {
      if (!_isClosing && mounted) {
        setState(() {
          _isPlaying = p;
          _wasPlayingBeforeMinimize = p;
          if (!p) {
            _isControlsVisible = true;
          } else {
            _onPointerMove();
          }
        });
      }
    });

    final currentUri = player.state.playlist.medias.firstOrNull?.uri;
    if (currentUri == widget.streamUrl && player.state.position > Duration.zero) {
      _isStreamReady = true;
    } else {
      // Hold audio completely silent until video picture is actually rendered on screen
      _initialVolume = player.state.volume > 0 ? player.state.volume : 100.0;
      _isVolumeMutedForSync = true;
      player.setVolume(0);

      Duration? firstPos;
      _frameSub = player.stream.position.listen((pos) {
        final uri = player.state.playlist.medias.firstOrNull?.uri;
        final hasVideo = player.state.videoParams.w != null && player.state.videoParams.w! > 0;
        if (!_isStreamReady && uri == widget.streamUrl && hasVideo) {
          firstPos ??= pos;
          // When the video decoder has rendered multiple frames on GPU, unmute and reveal together in 100% sync
          if ((pos - firstPos!).inMilliseconds >= 250) {
            _restoreVolume();
            if (mounted) setState(() => _isStreamReady = true);
            _frameSub?.cancel();
          }
        }
      });
      Future.delayed(const Duration(milliseconds: 6000), () {
        if (!_isStreamReady && mounted) {
          _restoreVolume();
          setState(() => _isStreamReady = true);
          _frameSub?.cancel();
        }
      });
    }
    
    // Auto-lock to landscape on mobile devices for cinema experience
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPlayback = ref.read(playbackControllerProvider);
      if (currentPlayback == null || currentPlayback.streamUrl != widget.streamUrl) {
        ref.read(playbackControllerProvider.notifier).playVod(
          title: widget.title,
          url: widget.streamUrl,
          streamType: widget.streamType == 'series' ? StreamType.series : StreamType.movie,
          streamId: widget.streamId,
          seriesId: widget.seriesId,
          coverUrl: widget.coverUrl,
          startPosition: widget.startPosition,
        );
      } else {
        // Returning from mini-player: continue from current playback without rewinding
        ref.read(playbackControllerProvider.notifier).expand();
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
    _controlsTimer?.cancel();
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
          : MouseRegion(
              onHover: (_) => _onPointerMove(),
              onEnter: (_) => _onPointerMove(),
              child: Stack(
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
                                  children: player.state.tracks.subtitle.map((t) {
                                    return ListTile(
                                      title: Text(t.title ?? t.language ?? t.id),
                                      selected: player.state.track.subtitle == t,
                                      onTap: () {
                                        player.setSubtitleTrack(t);
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
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
                                  children: player.state.tracks.subtitle.map((t) {
                                    return ListTile(
                                      title: Text(t.title ?? t.language ?? t.id),
                                      selected: player.state.track.subtitle == t,
                                      onTap: () {
                                        player.setSubtitleTrack(t);
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (Platform.isAndroid || Platform.isIOS)
                          ? MobileGestureDetector(
                              player: player,
                              enableSeek: false,
                              onDoubleTap: () => toggleFullscreen(context),
                              child: Video(
                                controller: controller,
                                fit: _fit,
                                controls: MaterialDesktopVideoControls,
                              ),
                            )
                          : Video(
                              controller: controller,
                              fit: _fit,
                              controls: MaterialDesktopVideoControls,
                            ),

                      // Center Play/Pause Button (same as Live TV)
                      Positioned.fill(
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: (_isControlsVisible || !_isPlaying) ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
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
                                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                  onPressed: _toggleCenterPlayPause,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Poster shield
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: _isStreamReady,
                          child: AnimatedOpacity(
                            opacity: _isStreamReady ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOut,
                            child: Container(
                              color: Colors.black,
                              child: Center(
                                child: widget.coverUrl != null
                                    ? Image.network(
                                        widget.coverUrl!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const CircularProgressIndicator(color: Colors.white70),
                                      )
                                    : const CircularProgressIndicator(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

