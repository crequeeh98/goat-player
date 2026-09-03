import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../epg_controller.dart';
import 'in_player_epg_drawer.dart';

class CustomLiveControls extends ConsumerStatefulWidget {
  final VideoState state;
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onSingleTap;
  final VoidCallback? onEnterFullWidth;
  final VoidCallback? onCycleFit;
  final BoxFit? currentFit;
  final VoidCallback? onCatchUpLive;

  // In-Stream EPG & Zapping parameters
  final List<StreamItem>? streams;
  final String? currentStreamId;
  final ValueChanged<StreamItem>? onSelectStream;
  final VoidCallback? onZapPrevious;
  final VoidCallback? onZapNext;
  final String? categoryName;

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
    this.streams,
    this.currentStreamId,
    this.onSelectStream,
    this.onZapPrevious,
    this.onZapNext,
    this.categoryName,
  });

  @override
  ConsumerState<CustomLiveControls> createState() => _CustomLiveControlsState();
}

class _CustomLiveControlsState extends ConsumerState<CustomLiveControls> {
  bool _showOverlay = true;
  Timer? _hideTimer;
  double _volume = 100.0;
  bool _isPlaying = true;

  // In-Player EPG Drawer & OSD Banner state
  bool _isDrawerOpen = false;
  bool _showOsdBanner = false;
  Timer? _osdBannerTimer;
  StreamSubscription? _volumeSub;
  StreamSubscription? _playingSub;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    final player = widget.state.widget.controller.player;
    _volume = player.state.volume;
    _isPlaying = player.state.playing;

    _volumeSub = player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
    _playingSub = player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _osdBannerTimer?.cancel();
    _volumeSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  void _triggerOsdBanner() {
    _osdBannerTimer?.cancel();
    setState(() => _showOsdBanner = true);
    _osdBannerTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _showOsdBanner = false);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isPlaying && !_isDrawerOpen) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isPlaying && !_isDrawerOpen) {
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

  void _zapPrevious() {
    if (widget.onZapPrevious != null) {
      widget.onZapPrevious!();
      _triggerOsdBanner();
      _startHideTimer();
    }
  }

  void _zapNext() {
    if (widget.onZapNext != null) {
      widget.onZapNext!();
      _triggerOsdBanner();
      _startHideTimer();
    }
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
      if (_isDrawerOpen) {
        _showOverlay = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFull = isFullscreen(context);

    // Look up active stream item and EPG data for OSD Banner
    StreamItem? currentStreamItem;
    int channelIndex = 1;
    if (widget.streams != null && widget.streams!.isNotEmpty && widget.currentStreamId != null) {
      final idx = widget.streams!.indexWhere(
        (s) => s.streamId == widget.currentStreamId || s.epgChannelId == widget.currentStreamId,
      );
      if (idx != -1) {
        currentStreamItem = widget.streams![idx];
        channelIndex = idx + 1;
      }
    }

    final currentPrograms = ref.watch(currentProgramsMapProvider).asData?.value ?? const {};
    final epgId = currentStreamItem?.epgChannelId != null && currentStreamItem!.epgChannelId!.isNotEmpty
        ? currentStreamItem.epgChannelId
        : currentStreamItem?.streamId;
    final currentProgram = epgId != null ? currentPrograms[epgId] : null;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Escape closes drawer if open, otherwise toggles fullscreen
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_isDrawerOpen) {
              setState(() => _isDrawerOpen = false);
              _startHideTimer();
              return KeyEventResult.handled;
            } else if (isFullscreen(context)) {
              toggleFullscreen(context);
              if (widget.onEnterFullWidth != null) {
                widget.onEnterFullWidth!();
              }
              return KeyEventResult.handled;
            }
          }

          // Channel Up: Next Channel
          if (event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.pageUp) {
            _zapNext();
            return KeyEventResult.handled;
          }

          // Channel Down: Previous Channel
          if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.pageDown) {
            _zapPrevious();
            return KeyEventResult.handled;
          }

          // E or L or Enter: Toggle EPG Drawer
          if (event.logicalKey == LogicalKeyboardKey.keyE ||
              event.logicalKey == LogicalKeyboardKey.keyL ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (widget.streams != null && widget.streams!.isNotEmpty) {
              _toggleDrawer();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: (_showOverlay || _isDrawerOpen) ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: _onPointerEvent,
        onEnter: _onPointerEvent,
        onExit: (_) {
          if (_isPlaying && !_isDrawerOpen) {
            setState(() => _showOverlay = false);
          }
        },
        child: Listener(
          onPointerHover: _onPointerEvent,
          onPointerMove: _onPointerEvent,
          onPointerDown: _onPointerEvent,
          child: GestureDetector(
            onTap: () {
              if (_isDrawerOpen) {
                setState(() => _isDrawerOpen = false);
                _startHideTimer();
                return;
              }
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
                // 1. Dark gradient overlay
                AnimatedOpacity(
                  opacity: (_showOverlay || !_isPlaying || _isDrawerOpen) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
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
                        stops: [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                // 2. Player Controls Overlay
                AnimatedOpacity(
                  opacity: (_showOverlay || !_isPlaying) && !_isDrawerOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: (!_showOverlay && _isPlaying) || _isDrawerOpen,
                    child: Stack(
                      children: [
                        // TOP LEFT: Back Button
                        if (widget.showBackButton || isFull)
                          Positioned(
                            top: 20,
                            left: 20,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                              tooltip: l10n?.close ?? 'Back',
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

                        // CENTER: Zapping Buttons (CH-) + Play/Pause + (CH+)
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onZapPrevious != null) ...[
                                IconButton(
                                  iconSize: 48,
                                  color: Colors.white70,
                                  icon: const Icon(Icons.skip_previous),
                                  tooltip: l10n?.previousChannel ?? 'Previous Channel (CH -)',
                                  onPressed: _zapPrevious,
                                ),
                                const SizedBox(width: 20),
                              ],
                              IconButton(
                                iconSize: 80,
                                color: Colors.white,
                                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                onPressed: _togglePlayPause,
                              ),
                              if (widget.onZapNext != null) ...[
                                const SizedBox(width: 20),
                                IconButton(
                                  iconSize: 48,
                                  color: Colors.white70,
                                  icon: const Icon(Icons.skip_next),
                                  tooltip: l10n?.nextChannel ?? 'Next Channel (CH +)',
                                  onPressed: _zapNext,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // BOTTOM LEFT: In-Player EPG Drawer Button
                        if (widget.streams != null && widget.streams!.isNotEmpty)
                          Positioned(
                            bottom: 20,
                            left: 20,
                            child: IconButton(
                              icon: const Icon(Icons.format_list_bulleted, color: Colors.white, size: 28),
                              tooltip: l10n?.epgDrawer ?? 'Channel List & EPG',
                              onPressed: _toggleDrawer,
                            ),
                          ),

                        // BOTTOM CENTER: Title & Current Show
                        Positioned(
                          bottom: 24,
                          left: 90,
                          right: 90,
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
                ),

                // 3. Floating OSD Banner (Appears on Zap / Channel Change)
                if (_showOsdBanner && currentStreamItem != null)
                  Positioned(
                    bottom: 84,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: InPlayerOsdBanner(
                        stream: currentStreamItem,
                        currentProgram: currentProgram,
                        channelNumber: channelIndex,
                      ),
                    ),
                  ),

                // 4. In-Player Slide-Out EPG & Channel List Drawer (Frosted Sidebar)
                if (widget.streams != null && widget.streams!.isNotEmpty)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _isDrawerOpen ? 0 : -360,
                    top: 0,
                    bottom: 0,
                    child: InPlayerEpgDrawer(
                      streams: widget.streams!,
                      currentStreamId: widget.currentStreamId,
                      categoryName: widget.categoryName,
                      onSelectStream: (stream) {
                        widget.onSelectStream?.call(stream);
                        _triggerOsdBanner();
                      },
                      onClose: () {
                        setState(() => _isDrawerOpen = false);
                        _startHideTimer();
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
