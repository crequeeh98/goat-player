import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomLiveControls extends StatefulWidget {
  final VideoState state;
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onSingleTap;
  final VoidCallback? onEnterFullWidth;

  const CustomLiveControls({
    super.key,
    required this.state,
    required this.title,
    this.showBackButton = false,
    this.onBack,
    this.onSingleTap,
    this.onEnterFullWidth,
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
    widget.state.widget.controller.player.playOrPause();
    _startHideTimer();
  }

  void _toggleFullscreen(BuildContext context) {
    if (isFullscreen(context)) {
      if (widget.onEnterFullWidth != null) {
        widget.onEnterFullWidth!();
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
                              toggleFullscreen(context);
                            }
                            if (widget.onBack != null) {
                              widget.onBack!();
                            }
                          },
                        ),
                      ),
                      
                    // TOP RIGHT: Volume
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _volume == 0 ? Icons.volume_off : (_volume < 50 ? Icons.volume_down : Icons.volume_up),
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (_volume > 0) {
                                widget.state.widget.controller.player.setVolume(0);
                              } else {
                                widget.state.widget.controller.player.setVolume(100);
                              }
                              _startHideTimer();
                            },
                          ),
                          SizedBox(
                            width: 100,
                            child: Slider(
                              value: _volume,
                              min: 0,
                              max: 100,
                              activeColor: Theme.of(context).colorScheme.primary,
                              inactiveColor: Colors.white38,
                              onChanged: (v) {
                                widget.state.widget.controller.player.setVolume(v);
                                _startHideTimer();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CENTER: Pause/Play Button
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
                      left: 100,
                      right: 100,
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // BOTTOM RIGHT: Fullscreen Toggle
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: IconButton(
                        icon: Icon(isFull ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 40),
                        onPressed: () => _toggleFullscreen(context),
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
