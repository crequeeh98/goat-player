import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:goat_player/core/database/app_database.dart';
import 'package:goat_player/main.dart';

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
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    player = Player(configuration: const PlayerConfiguration());
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: true),
    );
    
    // Auto-play the media
    player.open(Media(widget.streamUrl), play: true);
    
    // Listen for the first time duration is loaded to jump to startPosition
    if (widget.startPosition != null && widget.startPosition! > 0) {
      StreamSubscription? sub;
      sub = player.stream.duration.listen((duration) {
        if (duration.inSeconds > 0) {
          player.seek(Duration(seconds: widget.startPosition!));
          sub?.cancel();
        }
      });
    }

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

  @override
  void dispose() {
    _progressTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_isClosing) return;
    
    setState(() {
      _isClosing = true;
      _canPop = true;
    });
    
    player.stop();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isClosing 
          ? const SizedBox.expand() 
          : Stack(
              children: [
                MaterialDesktopVideoControlsTheme(
                  normal: MaterialDesktopVideoControlsThemeData(
                    playAndPauseOnTap: true,
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
                        onPressed: _handleBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
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
                    playAndPauseOnTap: true,
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
                        onPressed: _handleBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
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
                  child: Video(
                    controller: controller,
                    controls: MaterialDesktopVideoControls,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

