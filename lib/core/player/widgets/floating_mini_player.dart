import 'dart:async';
import '../../utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import '../playback_controller.dart';
import '../player_service.dart';
import '../../../features/vod_movies/vod_player_screen.dart';
import '../../../features/live_tv/mobile_live_view.dart';

class FloatingMiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback? onExpandLiveDesktop;

  const FloatingMiniPlayer({
    super.key,
    this.onExpandLiveDesktop,
  });

  @override
  ConsumerState<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends ConsumerState<FloatingMiniPlayer> {
  bool _isHovered = false;
  bool _isExpanding = false;
  Offset _desktopPosition = const Offset(24, 24); // distance from right, bottom
  double _cardWidth = 340.0;

  double get _cardHeight => _cardWidth * 9 / 16;

  void _cycleSize() {
    setState(() {
      if (_cardWidth < 320) {
        _cardWidth = 420.0;
      } else if (_cardWidth < 460) {
        _cardWidth = 560.0;
      } else {
        _cardWidth = 280.0;
      }
    });
  }

  Future<void> _expand(ActivePlayback active) async {
    if (_isExpanding) return;

    setState(() {
      _isExpanding = true;
    });

    ref.read(playbackControllerProvider.notifier).expand();

    // Allow mini-player Video widget to cleanly unmount before launching full route
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      if (active.streamType == StreamType.movie || active.streamType == StreamType.series) {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, _, __) => VodPlayerScreen(
              streamUrl: active.streamUrl,
              title: active.title,
              streamId: active.streamId,
              streamType: active.streamType == StreamType.movie ? 'movie' : 'series',
              seriesId: active.seriesId,
              coverUrl: active.coverUrl,
              startPosition: null,
              seasonsWithEpisodes: active.seasonsWithEpisodes,
              currentSeason: active.currentSeason,
              episodeNum: active.episodeNum,
              seriesName: active.seriesName,
              episodeTitle: active.episodeTitle,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else if (active.streamType == StreamType.live) {
        if (GoatPlatform.isMobile) {
          await Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, _, __) => MobilePlayerScreen(
                channelName: active.title,
                streamUrl: active.streamUrl,
                channelId: active.channelId,
                streamId: active.streamId,
                categoryId: active.categoryId,
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else {
          widget.onExpandLiveDesktop?.call();
        }
      }
    } finally {
      if (mounted) setState(() => _isExpanding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(playbackControllerProvider);
    if (_isExpanding || active == null || !active.isMinimized) {
      return const SizedBox.shrink();
    }

    final playerService = ref.watch(playerServiceProvider);
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width > 800;

    if (isDesktop) {
      return _buildDesktopCard(active, playerService);
    } else {
      return _buildMobileBar(active, playerService);
    }
  }

  Widget _buildDesktopCard(ActivePlayback active, PlayerService playerService) {
    final l10n = AppLocalizations.of(context);
    final closeLabel = l10n?.close ?? 'Close';
    final expandLabel = l10n?.fullScreen ?? 'Fullscreen';

    return Positioned(
      right: _desktopPosition.dx,
      bottom: _desktopPosition.dy,
      width: _cardWidth,
      height: _cardHeight,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? Colors.white.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. RepaintBoundary isolates Video texture surface from parent UI repaints
                RepaintBoundary(
                  child: Video(
                    controller: playerService.controller,
                    controls: NoVideoControls,
                  ),
                ),

                // 2. Base Surface: Click anywhere to expand, drag anywhere to move
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _expand(active),
                    onPanUpdate: (details) {
                      setState(() {
                        _desktopPosition = Offset(
                          (_desktopPosition.dx - details.delta.dx).clamp(16.0, MediaQuery.sizeOf(context).width - _cardWidth - 16.0),
                          (_desktopPosition.dy - details.delta.dy).clamp(16.0, MediaQuery.sizeOf(context).height - _cardHeight - 16.0),
                        );
                      });
                    },
                  ),
                ),

                // 3. Hover Overlay Controls
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: IgnorePointer(
                      ignoring: !_isHovered,
                      child: Stack(
                        children: [
                          // Overlay background gradient (click to expand, drag to move)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _expand(active),
                              onPanUpdate: (details) {
                                setState(() {
                                  _desktopPosition = Offset(
                                    (_desktopPosition.dx - details.delta.dx).clamp(16.0, MediaQuery.sizeOf(context).width - _cardWidth - 16.0),
                                    (_desktopPosition.dy - details.delta.dy).clamp(16.0, MediaQuery.sizeOf(context).height - _cardHeight - 16.0),
                                  );
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.85),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Top bar: Title on left, Close button on right
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.only(left: 28, right: 6, top: 4),
                              child: Row(
                                children: [
                                  // Title (tap to expand)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _expand(active),
                                      child: Text(
                                        active.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Close button
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.white),
                                    tooltip: closeLabel,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      ref.read(playbackControllerProvider.notifier).stop();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Center: Play/Pause Button
                          Center(
                            child: _PlayPauseButton(
                              player: playerService.player,
                              onPlayPause: () => playerService.playOrPause(),
                            ),
                          ),

                          // Bottom Controls Section
                          Positioned(
                            bottom: 2,
                            left: 8,
                            right: 8,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // If VOD: Interactive Progress Seek Bar & Runtime Display
                                if (active.streamType != StreamType.live)
                                  _MiniPlayerVodControls(player: playerService.player),

                                // Controls Row: Badge, Volume, Fullscreen
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        active.streamType == StreamType.live ? 'LIVE' : 'VOD',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Volume Control (Icon + Slider)
                                        _MiniPlayerVolumeControl(player: playerService.player),
                                        const SizedBox(width: 4),

                                        // Fullscreen / Expand
                                        IconButton(
                                          icon: const Icon(Icons.fullscreen, size: 24, color: Colors.white),
                                          tooltip: expandLabel,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _expand(active),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Native OS-Style Border Resize Zones (Top-Left corner, Left edge, Top edge)
                Positioned(
                  top: 0,
                  left: 0,
                  width: 26,
                  height: 26,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _cycleSize,
                      onPanUpdate: (details) {
                        setState(() {
                          _cardWidth = (_cardWidth - details.delta.dx).clamp(240.0, 620.0);
                        });
                      },
                      child: CustomPaint(
                        painter: _ResizeCornerPainter(isHovered: _isHovered),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 26,
                  left: 0,
                  bottom: 0,
                  width: 8,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _cycleSize,
                      onPanUpdate: (details) {
                        setState(() {
                          _cardWidth = (_cardWidth - details.delta.dx).clamp(240.0, 620.0);
                        });
                      },
                    ),
                  ),
                ),

                Positioned(
                  top: 0,
                  left: 26,
                  right: 48,
                  height: 8,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUp,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _cycleSize,
                      onPanUpdate: (details) {
                        setState(() {
                          _cardWidth = (_cardWidth - (details.delta.dy * 16 / 9)).clamp(240.0, 620.0);
                        });
                      },
                    ),
                  ),
                ),

                // 5. Slim VOD progress bar at bottom when NOT hovered
                if (active.streamType != StreamType.live && !_isHovered)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _MiniPlayerProgressBar(player: playerService.player),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBar(ActivePlayback active, PlayerService playerService) {
    final l10n = AppLocalizations.of(context);
    final closeLabel = l10n?.close ?? 'Close';
    final streamTypeLabel = active.streamType == StreamType.live
        ? (l10n?.liveTv ?? 'Live TV')
        : (l10n?.vodPlayback ?? 'VOD Playback');
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 8,
      right: 8,
      bottom: 8 + bottomPadding,
      height: 62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _expand(active),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Video thumbnail
                      SizedBox(
                        width: 96,
                        height: 62,
                        child: RepaintBoundary(
                          child: Video(
                            controller: playerService.controller,
                            controls: NoVideoControls,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Title & Stream Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              streamTypeLabel,
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),

                      // Play / Pause
                      _PlayPauseButton(
                        player: playerService.player,
                        iconSize: 28,
                        onPlayPause: () => playerService.playOrPause(),
                      ),

                      // Close
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                        tooltip: closeLabel,
                        onPressed: () {
                          ref.read(playbackControllerProvider.notifier).stop();
                        },
                      ),
                    ],
                  ),

                  // Slim VOD progress bar at bottom
                  if (active.streamType != StreamType.live)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MiniPlayerProgressBar(player: playerService.player),
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

/// Subtle diagonal resize grip lines in the top-left corner
class _ResizeCornerPainter extends CustomPainter {
  final bool isHovered;

  const _ResizeCornerPainter({required this.isHovered});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isHovered) return;
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 3 sleek diagonal grip lines at top-left
    canvas.drawLine(const Offset(4, 11), const Offset(11, 4), paint);
    canvas.drawLine(const Offset(4, 16), const Offset(16, 4), paint);
    canvas.drawLine(const Offset(4, 21), const Offset(21, 4), paint);
  }

  @override
  bool shouldRepaint(_ResizeCornerPainter oldDelegate) => oldDelegate.isHovered != isHovered;
}

/// Isolated Play/Pause button that only rebuilds itself when playing state changes
class _PlayPauseButton extends StatefulWidget {
  final dynamic player;
  final double iconSize;
  final VoidCallback? onPlayPause;

  const _PlayPauseButton({
    required this.player,
    this.iconSize = 46,
    this.onPlayPause,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isPlaying = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.state.playing;
    _sub = widget.player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.iconSize,
      color: Colors.white,
      icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
      onPressed: () {
        if (widget.onPlayPause != null) {
          widget.onPlayPause!();
        } else {
          widget.player.playOrPause();
        }
      },
    );
  }
}

/// Interactive VOD scrubber with real-time runtime display
class _MiniPlayerVodControls extends StatefulWidget {
  final dynamic player;

  const _MiniPlayerVodControls({required this.player});

  @override
  State<_MiniPlayerVodControls> createState() => _MiniPlayerVodControlsState();
}

class _MiniPlayerVodControlsState extends State<_MiniPlayerVodControls> {
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0.0;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _pos = widget.player.state.position;
    _dur = widget.player.state.duration;

    _posSub = widget.player.stream.position.listen((p) {
      if (mounted && !_isDragging) {
        setState(() => _pos = p);
      }
    });
    _durSub = widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_dur.inSeconds <= 0) return const SizedBox.shrink();

    final currentPos = _isDragging ? Duration(seconds: (_dragValue * _dur.inSeconds).toInt()) : _pos;
    final progress = (_dur.inSeconds > 0) ? (currentPos.inSeconds / _dur.inSeconds).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Runtime text (e.g. 14:20 / 1:35:00)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(currentPos),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatTime(_dur),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        // Interactive Seek Slider
        SizedBox(
          height: 16,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
              activeTrackColor: Colors.redAccent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.redAccent,
            ),
            child: Slider(
              value: progress,
              onChangeStart: (val) {
                setState(() {
                  _isDragging = true;
                  _dragValue = val;
                });
              },
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                final targetSec = (val * _dur.inSeconds).toInt();
                widget.player.seek(Duration(seconds: targetSec));
                setState(() {
                  _isDragging = false;
                  _pos = Duration(seconds: targetSec);
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Mini Player Volume Control with icon + expandable volume slider
class _MiniPlayerVolumeControl extends StatefulWidget {
  final dynamic player;

  const _MiniPlayerVolumeControl({required this.player});

  @override
  State<_MiniPlayerVolumeControl> createState() => _MiniPlayerVolumeControlState();
}

class _MiniPlayerVolumeControlState extends State<_MiniPlayerVolumeControl> {
  double _volume = 100.0;
  bool _isExpanded = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _volume = widget.player.state.volume;
    _sub = widget.player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  IconData get _icon {
    if (_volume <= 0) return Icons.volume_off;
    if (_volume < 50) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_icon, size: 18, color: Colors.white),
            tooltip: _volume == 0 ? 'Unmute' : 'Mute',
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(),
            onPressed: () {
              if (_volume > 0) {
                widget.player.setVolume(0);
              } else {
                widget.player.setVolume(100);
              }
            },
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isExpanded ? 60.0 : 0.0,
            child: _isExpanded
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _volume.clamp(0.0, 100.0),
                      min: 0.0,
                      max: 100.0,
                      onChanged: (v) {
                        widget.player.setVolume(v);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Isolated real-time progress bar for bottom of card when not hovered
class _MiniPlayerProgressBar extends StatefulWidget {
  final dynamic player;

  const _MiniPlayerProgressBar({required this.player});

  @override
  State<_MiniPlayerProgressBar> createState() => _MiniPlayerProgressBarState();
}

class _MiniPlayerProgressBarState extends State<_MiniPlayerProgressBar> {
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _pos = widget.player.state.position;
    _dur = widget.player.state.duration;
    _sub = widget.player.stream.position.listen((p) {
      if (mounted) {
        setState(() {
          _pos = p;
          _dur = widget.player.state.duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dur.inSeconds <= 0) return const SizedBox.shrink();
    final frac = (_pos.inSeconds / _dur.inSeconds).clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: frac,
      minHeight: 2.5,
      backgroundColor: Colors.white24,
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
    );
  }
}
