import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'dart:io' show Platform;

class CustomLiveControls extends StatefulWidget {
  final VideoState state;
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onSingleTap;
  final VoidCallback? onEnterFullWidth;
  final VoidCallback? onCycleFit;
  final BoxFit? currentFit;
  final VoidCallback? onCatchUpLive;

  const CustomLiveControls({
    super.key,
    required this.state,
    required this.title,
    this.showBackButton = false,
    this.onBack,
    this.onSingleTap,
    this.onEnterFullWidth,
    this.onCycleFit,
    this.currentFit,
    this.onCatchUpLive,
  });

  @override
  State<CustomLiveControls> createState() => _CustomLiveControlsState();
}

class _CustomLiveControlsState extends State<CustomLiveControls> {
  bool _showOverlay = true;
  Timer? _hideTimer;
  double _volume = 100.0;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _volume = widget.state.widget.controller.player.state.volume;
    _isPlaying = widget.state.widget.controller.player.state.playing;

    widget.state.widget.controller.player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
    widget.state.widget.controller.player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showOverlay = false);
        }
      });
    }
  }

  void _onPointerEvent(PointerEvent event) {
    if (!_showOverlay) {
      setState(() => _showOverlay = true);
    }
    _startHideTimer();
  }

  void _togglePlayPause() {
    final player = widget.state.widget.controller.player;
    if (_isPlaying) {
      player.pause();
    } else {
      // Reconnect/flush to real-time live edge
      if (widget.onCatchUpLive != null) {
        widget.onCatchUpLive!();
      } else {
        player.play();
      }
    }
    _startHideTimer();
  }

  void _toggleFullscreen(BuildContext context) {
    final currentlyFull = isFullscreen(context);
    if (currentlyFull) {
      if (widget.onEnterFullWidth != null) {
        widget.onEnterFullWidth!();
      }
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
    toggleFullscreen(context);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we are currently in fullscreen
    final isFull = isFullscreen(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          if (isFullscreen(context)) {
            toggleFullscreen(context);
            if (widget.onEnterFullWidth != null) {
              widget.onEnterFullWidth!();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: _showOverlay ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: _onPointerEvent,
        onEnter: _onPointerEvent,
        onExit: (_) {
          if (_isPlaying) {
            setState(() => _showOverlay = false);
          }
        },
      child: Listener(
        onPointerHover: _onPointerEvent,
        onPointerMove: _onPointerEvent,
        onPointerDown: _onPointerEvent,
        child: GestureDetector(
          onTap: () {
            if (!_showOverlay) {
              setState(() => _showOverlay = true);
              _startHideTimer();
            }
            if (widget.onSingleTap != null) {
              widget.onSingleTap!();
            }
          },
          onDoubleTap: () => _toggleFullscreen(context),
          child: Stack(
            children: [
              // Dark gradient background for visibility
              AnimatedOpacity(
                opacity: _showOverlay || !_isPlaying ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black54,
                      ],
                      stops: [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
              
              AnimatedOpacity(
                opacity: _showOverlay || !_isPlaying ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Stack(
                  children: [
                    // TOP LEFT: Back Button
                    if (widget.showBackButton || isFull)
                      Positioned(
                        top: 20,
                        left: 20,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                          onPressed: () {
                            if (isFull) {
                              _toggleFullscreen(context);
                            }
                            if (widget.onBack != null) {
                              widget.onBack!();
                            }
                          },
                        ),
                      ),
                      
                    // TOP RIGHT: Volume & Aspect Ratio
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Row(
                        children: [
                          if (widget.onCycleFit != null && (Platform.isAndroid || Platform.isIOS))
                            IconButton(
                              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                              tooltip: 'Aspect Ratio',
                              onPressed: () {
                                widget.onCycleFit!();
                                _startHideTimer();
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _volume == 0 ? Icons.volume_off : (_volume < 50 ? Icons.volume_down : Icons.volume_up),
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (_volume > 0) {
                                setState(() => _volume = 0);
                                widget.state.widget.controller.player.setVolume(0);
                              } else {
                                setState(() => _volume = 100);
                                widget.state.widget.controller.player.setVolume(100);
                              }
                              _startHideTimer();
                            },
                          ),
                          Listener(
                            onPointerSignal: (pointerSignal) {
                              if (pointerSignal is PointerScrollEvent) {
                                final delta = pointerSignal.scrollDelta.dy;
                                final newVol = (_volume - (delta > 0 ? 5 : -5)).clamp(0.0, 100.0);
                                setState(() => _volume = newVol);
                                widget.state.widget.controller.player.setVolume(newVol);
                                _startHideTimer();
                              }
                            },
                            child: SizedBox(
                              width: 95,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withValues(alpha: 0.15),
                                  trackHeight: 3.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                ),
                                child: Slider(
                                  value: _volume.clamp(0.0, 100.0),
                                  min: 0.0,
                                  max: 100.0,
                                  onChanged: (v) {
                                    setState(() => _volume = v);
                                    widget.state.widget.controller.player.setVolume(v);
                                    _startHideTimer();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CENTER: Pause/Play Button (unpausing automatically catches up to live edge)
                    Center(
                      child: IconButton(
                        iconSize: 80,
                        color: Colors.white,
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        onPressed: _togglePlayPause,
                      ),
                    ),

                    // BOTTOM CENTER: Title
                    Positioned(
                      bottom: 40,
                      left: 80,
                      right: 80,
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // BOTTOM RIGHT: Volume & Fullscreen Toggle
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _volume == 0 ? Icons.volume_off : (_volume < 50 ? Icons.volume_down : Icons.volume_up),
                              color: Colors.white,
                              size: 26,
                            ),
                            tooltip: _volume == 0 ? 'Unmute' : 'Mute',
                            onPressed: () {
                              if (_volume > 0) {
                                setState(() => _volume = 0);
                                widget.state.widget.controller.player.setVolume(0);
                              } else {
                                setState(() => _volume = 100);
                                widget.state.widget.controller.player.setVolume(100);
                              }
                              _startHideTimer();
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(isFull ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 36),
                            onPressed: () => _toggleFullscreen(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
