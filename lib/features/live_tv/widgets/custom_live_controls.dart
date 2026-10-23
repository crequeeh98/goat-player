import 'dart:async';
import '../../../core/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/player/playback_controller.dart';
import '../../../core/player/widgets/stream_quality_badge.dart';
import '../../../core/utils/channel_name_cleaner.dart';
import '../../../core/utils/live_stream_matcher.dart';
import '../epg_controller.dart';
import '../live_tv_controller.dart';
import 'in_player_epg_drawer.dart';

class CustomLiveControls extends ConsumerStatefulWidget {
  final VideoState state;
  final String title;
  final bool showBackButton;
  final bool isFullWidth;
  final VoidCallback? onBack;
  final VoidCallback? onSingleTap;
  final VoidCallback? onEnterFullWidth;
  final VoidCallback? onCycleFit;
  final BoxFit? currentFit;
  final VoidCallback? onCatchUpLive;

  // In-Stream EPG & Zapping parameters
  final List<StreamItem>? streams;
  final String? streamId;
  final String? currentStreamId;
  final ValueChanged<StreamItem>? onSelectStream;
  final VoidCallback? onZapPrevious;
  final VoidCallback? onZapNext;
  final String? categoryName;
  final VoidCallback? onPullDown;

  const CustomLiveControls({
    super.key,
    required this.state,
    required this.title,
    this.showBackButton = false,
    this.isFullWidth = false,
    this.onBack,
    this.onSingleTap,
    this.onEnterFullWidth,
    this.onCycleFit,
    this.currentFit,
    this.onCatchUpLive,
    this.streams,
    this.streamId,
    this.currentStreamId,
    this.onSelectStream,
    this.onZapPrevious,
    this.onZapNext,
    this.categoryName,
    this.onPullDown,
  });

  @override
  ConsumerState<CustomLiveControls> createState() => _CustomLiveControlsState();
}

class _CustomLiveControlsState extends ConsumerState<CustomLiveControls> {
  final FocusNode _focusNode = FocusNode();
  bool _showOverlay = true;
  Timer? _hideTimer;
  double _volume = 100.0;
  bool _isPlaying = true;
  bool _isBuffering = false;
  String? _optimisticStreamId;

  // In-Player EPG Drawer & OSD Banner state
  bool _isDrawerOpen = false;
  bool _showOsdBanner = false;
  Timer? _osdBannerTimer;
  StreamSubscription? _volumeSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _drawerChannelChangeSub;
  String? _channelChangingToStreamId;
  double _verticalDragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    final player = widget.state.widget.controller.player;
    _volume = player.state.volume;
    _isPlaying = player.state.playing;
    _isBuffering = player.state.buffering;

    _volumeSub = player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
    _playingSub = player.stream.playing.listen((p) {
      if (mounted) {
        setState(() => _isPlaying = p);
        if (p && !_isBuffering) {
          _startHideTimer();
        }
      }
    });
    _bufferingSub = player.stream.buffering.listen((b) {
      if (mounted) {
        setState(() => _isBuffering = b);
        if (!b && _isPlaying) {
          _startHideTimer();
        }
      }
    });

    if (widget.isFullWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(CustomLiveControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFullWidth && !oldWidget.isFullWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _drawerChannelChangeSub?.cancel();
    _hideTimer?.cancel();
    _osdBannerTimer?.cancel();
    _volumeSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    super.dispose();
  }

  void _triggerOsdBanner() {
    _osdBannerTimer?.cancel();
    setState(() => _showOsdBanner = true);
    _osdBannerTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _showOsdBanner = false);
    });
  }

  DateTime _lastLiveTimerReset = DateTime.now();

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isPlaying && !_isBuffering && !_isDrawerOpen) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isPlaying && !_isBuffering && !_isDrawerOpen) {
          setState(() => _showOverlay = false);
        }
      });
    }
  }

  void _onPointerEvent(PointerEvent event) {
    if (!_showOverlay) {
      setState(() => _showOverlay = true);
    }
    final now = DateTime.now();
    if (now.difference(_lastLiveTimerReset).inMilliseconds > 250) {
      _lastLiveTimerReset = now;
      _startHideTimer();
    }
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

  void _toggleFullscreen(BuildContext context) async {
    final currentlyFull = isFullscreen(context);
    if (widget.onEnterFullWidth != null) {
      widget.onEnterFullWidth!();
    }
    if (currentlyFull) {
      if (GoatPlatform.isPhone) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } else {
      if (GoatPlatform.isPhone) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
    await toggleFullscreen(context);
    if (mounted && widget.onEnterFullWidth != null) {
      widget.onEnterFullWidth!();
    }
    _startHideTimer();
  }

  void _zapPrevious() {
    final activePlayback = ref.read(playbackControllerProvider);
    final categoryId = activePlayback?.categoryId ?? ref.read(selectedLiveCategoryProvider);
    final fallbackStreams = categoryId != null ? ref.read(liveStreamsProvider(categoryId)).asData?.value : null;
    final streams = (widget.streams != null && widget.streams!.isNotEmpty)
        ? widget.streams!
        : (fallbackStreams ?? const <StreamItem>[]);

    if (streams.isNotEmpty) {
      final currentIdx = LiveStreamMatcher.indexOf(
        streams,
        streamId: _optimisticStreamId ?? activePlayback?.streamId ?? widget.streamId,
        channelId: activePlayback?.channelId ?? widget.currentStreamId,
        streamUrl: activePlayback?.streamUrl,
      );
      final prevIdx = (currentIdx != -1) ? (currentIdx - 1 + streams.length) % streams.length : streams.length - 1;
      final prevStream = streams[prevIdx];
      _optimisticStreamId = prevStream.streamId;
      widget.onSelectStream?.call(prevStream);
      _triggerOsdBanner();
      _startHideTimer();
      return;
    }
    if (widget.onZapPrevious != null) {
      widget.onZapPrevious!();
      _triggerOsdBanner();
      _startHideTimer();
    }
  }

  void _zapNext() {
    final activePlayback = ref.read(playbackControllerProvider);
    final categoryId = activePlayback?.categoryId ?? ref.read(selectedLiveCategoryProvider);
    final fallbackStreams = categoryId != null ? ref.read(liveStreamsProvider(categoryId)).asData?.value : null;
    final streams = (widget.streams != null && widget.streams!.isNotEmpty)
        ? widget.streams!
        : (fallbackStreams ?? const <StreamItem>[]);

    if (streams.isNotEmpty) {
      final currentIdx = LiveStreamMatcher.indexOf(
        streams,
        streamId: _optimisticStreamId ?? activePlayback?.streamId ?? widget.streamId,
        channelId: activePlayback?.channelId ?? widget.currentStreamId,
        streamUrl: activePlayback?.streamUrl,
      );
      final nextIdx = (currentIdx != -1) ? (currentIdx + 1) % streams.length : 0;
      final nextStream = streams[nextIdx];
      _optimisticStreamId = nextStream.streamId;
      widget.onSelectStream?.call(nextStream);
      _triggerOsdBanner();
      _startHideTimer();
      return;
    }
    if (widget.onZapNext != null) {
      widget.onZapNext!();
      _triggerOsdBanner();
      _startHideTimer();
    }
  }

  void _toggleDrawer() {
    final isFull = isFullscreen(context);
    final activePlayback = ref.read(playbackControllerProvider);
    final categoryId = activePlayback?.categoryId ?? ref.read(selectedLiveCategoryProvider);
    final fallbackStreams = categoryId != null ? ref.read(liveStreamsProvider(categoryId)).asData?.value : null;
    final availableStreams = (widget.streams != null && widget.streams!.isNotEmpty)
        ? widget.streams!
        : (fallbackStreams ?? const <StreamItem>[]);
    final canShowDrawer = (isFull || widget.isFullWidth) && availableStreams.isNotEmpty;
    if (!canShowDrawer) return;

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

    // Dynamically watch active playback state so fullscreen mode immediately updates
    // on channel zap without relying on frozen constructor parameters
    final activePlayback = ref.watch(playbackControllerProvider);
    if (_optimisticStreamId != null && activePlayback?.streamId == _optimisticStreamId) {
      _optimisticStreamId = null;
    }
    final activeStreamId = _optimisticStreamId ?? activePlayback?.streamId ?? widget.streamId;
    final activeChannelId = activePlayback?.channelId ?? widget.currentStreamId;
    final activeTitle = (activePlayback != null && activePlayback.streamType == StreamType.live)
        ? activePlayback.title
        : widget.title;

    final categoryId = activePlayback?.categoryId ?? ref.watch(selectedLiveCategoryProvider);
    final fallbackStreams = categoryId != null ? ref.watch(liveStreamsProvider(categoryId)).asData?.value : null;
    final availableStreams = (widget.streams != null && widget.streams!.isNotEmpty)
        ? widget.streams!
        : (fallbackStreams ?? const <StreamItem>[]);
    final canShowDrawer = (isFull || widget.isFullWidth) && availableStreams.isNotEmpty;

    // Look up active stream item and real-time EPG data for OSD Banner & title display
    StreamItem? currentStreamItem;
    int channelIndex = 1;
    if (availableStreams.isNotEmpty) {
      final idx = LiveStreamMatcher.indexOf(
        availableStreams,
        streamId: activeStreamId,
        channelId: activeChannelId,
        streamUrl: activePlayback?.streamUrl,
      );
      if (idx != -1) {
        currentStreamItem = availableStreams[idx];
        channelIndex = idx + 1;
      }
    }

    final currentPrograms = ref.watch(currentProgramsMapProvider).asData?.value ?? const {};
    final epgId = currentStreamItem?.epgChannelId != null && currentStreamItem!.epgChannelId!.isNotEmpty
        ? currentStreamItem.epgChannelId
        : currentStreamItem?.streamId;
    final currentProgram = epgId != null ? currentPrograms[epgId] : null;

    final displayTitle = (currentProgram != null && currentProgram.title.isNotEmpty)
        ? '$activeTitle - ${currentProgram.title}'
        : (currentStreamItem != null ? ChannelNameCleaner.clean(currentStreamItem.name) : activeTitle);

    final isFullOrFullWidth = widget.isFullWidth || isFullscreen(context);

    return Focus(
      focusNode: _focusNode,
      autofocus: isFullOrFullWidth,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Any remote interaction resets hide timer
          _startHideTimer();

          // Escape closes drawer if open, otherwise toggles fullscreen, otherwise exits full-width
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            if (_isDrawerOpen) {
              setState(() => _isDrawerOpen = false);
              _startHideTimer();
              return KeyEventResult.handled;
            } else if (isFullscreen(context)) {
              if (widget.onEnterFullWidth != null) {
                widget.onEnterFullWidth!();
              }
              toggleFullscreen(context);
              if (widget.onEnterFullWidth != null) {
                widget.onEnterFullWidth!();
              }
              return KeyEventResult.handled;
            } else if (widget.isFullWidth) {
              if (widget.onBack != null) {
                widget.onBack!();
              }
              return KeyEventResult.handled;
            }
          }

          // Channel Up: Next Channel or Toggle Overlay (ONLY in full-width or fullscreen, or dedicated TV CH+ key)
          if (event.logicalKey == LogicalKeyboardKey.pageUp ||
              event.logicalKey == LogicalKeyboardKey.channelUp ||
              (isFullOrFullWidth && event.logicalKey == LogicalKeyboardKey.arrowUp)) {
            if (widget.streams != null && widget.streams!.length > 1) {
              _zapNext();
            } else {
              setState(() => _showOverlay = !_showOverlay);
              if (_showOverlay) _startHideTimer();
            }
            return KeyEventResult.handled;
          }

          // Channel Down: Previous Channel or Toggle Overlay (ONLY in full-width or fullscreen, or dedicated TV CH- key)
          if (event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.channelDown ||
              (isFullOrFullWidth && event.logicalKey == LogicalKeyboardKey.arrowDown)) {
            if (widget.streams != null && widget.streams!.length > 1) {
              _zapPrevious();
            } else {
              setState(() => _showOverlay = !_showOverlay);
              if (_showOverlay) _startHideTimer();
            }
            return KeyEventResult.handled;
          }

          // Space: Play / Pause (or catch up to live)
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          }

          // E or L or Enter: Toggle EPG Drawer (only in full-width or fullscreen)
          if (event.logicalKey == LogicalKeyboardKey.keyE ||
              event.logicalKey == LogicalKeyboardKey.keyL ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (canShowDrawer) {
              _toggleDrawer();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: (_showOverlay || _isDrawerOpen) ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: (e) {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
          _onPointerEvent(e);
        },
        onEnter: (e) {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
          _onPointerEvent(e);
        },
        onExit: (_) {
          if (_isPlaying && !_isDrawerOpen) {
            _startHideTimer();
          }
        },
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
              if (_isDrawerOpen) {
                setState(() => _isDrawerOpen = false);
                _startHideTimer();
                return;
              }
              setState(() => _showOverlay = !_showOverlay);
              if (_showOverlay) {
                _startHideTimer();
              } else {
                _hideTimer?.cancel();
              }
              if (widget.onSingleTap != null) {
                widget.onSingleTap!();
              }
            },
            onDoubleTap: () => _toggleFullscreen(context),
            onVerticalDragStart: (d) {
              _verticalDragDistance = 0.0;
            },
            onVerticalDragUpdate: (d) {
              _verticalDragDistance += d.primaryDelta ?? 0.0;
            },
            onVerticalDragEnd: (d) {
              final velocity = d.primaryVelocity ?? 0.0;
              if (_verticalDragDistance > 40 || velocity > 250) {
                widget.onPullDown?.call();
              }
              _verticalDragDistance = 0.0;
            },
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

                // Buffering spinner when controls overlay is hidden
                if (_isBuffering && !_showOverlay)
                  const Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB388FF)),
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

                        // TOP RIGHT: Controls (Aspect Ratio & Desktop Volume)
                        Positioned(
                          top: (GoatPlatform.isMobile && !isFull)
                              ? 8
                              : (!isFull && !widget.isFullWidth)
                                  ? 12
                                  : 20,
                          right: (GoatPlatform.isMobile && !isFull)
                              ? 8
                              : (!isFull && !widget.isFullWidth)
                                  ? 12
                                  : 20,
                          child: Row(
                            children: [
                              // Aspect Ratio only in fullscreen mode
                              if (widget.onCycleFit != null && GoatPlatform.isMobile && isFull)
                                IconButton(
                                  icon: const Icon(Icons.aspect_ratio, color: Colors.white, size: 22),
                                  tooltip: 'Aspect Ratio',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    widget.onCycleFit!();
                                    _startHideTimer();
                                  },
                                ),
                              // Volume control on desktop (Preview, Theatre & Fullscreen)
                              if (!GoatPlatform.isMobile) ...[
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _volume == 0 ? Icons.volume_off : (_volume < 50 ? Icons.volume_down : Icons.volume_up),
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        visualDensity: VisualDensity.standard,
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
                                      SizedBox(
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
                                    ],
                                  ),
                                ),
                              ],
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
                                  iconSize: (GoatPlatform.isMobile && !isFull) ? 36 : 48,
                                  color: Colors.white70,
                                  icon: const Icon(Icons.skip_previous),
                                  tooltip: l10n?.previousChannel ?? 'Previous Channel (CH -)',
                                  onPressed: _zapPrevious,
                                ),
                                const SizedBox(width: 16),
                              ],
                              IconButton(
                                iconSize: (GoatPlatform.isMobile && !isFull) ? 56 : 76,
                                color: Colors.white,
                                icon: _isBuffering
                                    ? const SizedBox(
                                        width: 38,
                                        height: 38,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB388FF)),
                                        ),
                                      )
                                    : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                onPressed: _togglePlayPause,
                              ),
                              if (widget.onZapNext != null) ...[
                                const SizedBox(width: 16),
                                IconButton(
                                  iconSize: (GoatPlatform.isMobile && !isFull) ? 36 : 48,
                                  color: Colors.white70,
                                  icon: const Icon(Icons.skip_next),
                                  tooltip: l10n?.nextChannel ?? 'Next Channel (CH +)',
                                  onPressed: _zapNext,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // BOTTOM LEFT: In-Player EPG Drawer Button (Only in Full-Width or Fullscreen)
                        if (canShowDrawer)
                          Positioned(
                            bottom: (GoatPlatform.isMobile && !isFull) ? 8 : 20,
                            left: (GoatPlatform.isMobile && !isFull) ? 8 : 20,
                            child: IconButton(
                              icon: const Icon(Icons.format_list_bulleted, color: Colors.white, size: 28),
                              tooltip: l10n?.epgDrawer ?? 'Channel List & EPG',
                              onPressed: _toggleDrawer,
                            ),
                          ),

                        // BOTTOM CENTER: Title & Current Show (Only in Fullscreen or Desktop, not mobile portrait where AppBar already has it)
                        if (isFullOrFullWidth || !GoatPlatform.isMobile)
                          Positioned(
                            bottom: 18,
                            left: 90,
                            right: 90,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                StreamQualityBadges(
                                  player: widget.state.widget.controller.player,
                                  streamTitle: widget.title,
                                  isCompact: true,
                                ),
                              ],
                            ),
                          ),

                        // BOTTOM RIGHT: Fullscreen Toggle
                        Positioned(
                          bottom: (GoatPlatform.isMobile && !isFull) ? 8 : 20,
                          right: (GoatPlatform.isMobile && !isFull) ? 8 : 20,
                          child: IconButton(
                            icon: Icon(
                              isFull ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: Colors.white,
                              size: (GoatPlatform.isMobile && !isFull) ? 26 : 32,
                            ),
                            visualDensity: (GoatPlatform.isMobile && !isFull) ? VisualDensity.compact : VisualDensity.standard,
                            onPressed: () => _toggleFullscreen(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. In-Player OSD Channel Info Banner (Appears on zap, only in fullscreen)
                if (_showOsdBanner && currentStreamItem != null && isFull)
                  Positioned(
                    top: (!isFull || (GoatPlatform.isMobile && MediaQuery.sizeOf(context).width <= 800)) ? 8 : 40,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: InPlayerOsdBanner(
                        stream: currentStreamItem,
                        currentProgram: currentProgram,
                        channelNumber: channelIndex,
                        isCompact: (!isFull || (GoatPlatform.isMobile && MediaQuery.sizeOf(context).width <= 800)),
                        player: widget.state.widget.controller.player,
                      ),
                    ),
                  ),

                // 4. In-Player Slide-Out EPG & Channel List Drawer (Only in Full-Width or Fullscreen)
                if (canShowDrawer && availableStreams.isNotEmpty)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _isDrawerOpen ? 0 : -360,
                    top: 0,
                    bottom: 0,
                    child: InPlayerEpgDrawer(
                      streams: availableStreams,
                      currentStreamId: activeStreamId ?? activeChannelId,
                      categoryName: widget.categoryName,
                      isOpen: _isDrawerOpen,
                      onSelectStream: (stream) {
                        _optimisticStreamId = stream.streamId;
                        _channelChangingToStreamId = stream.streamId;
                        setState(() {}); // Rebuild so the drawer highlight updates to the new channel immediately!

                        widget.onSelectStream?.call(stream);
                        _triggerOsdBanner();

                        _hideTimer?.cancel();
                        _drawerChannelChangeSub?.cancel();

                        // Keep the drawer open with the channel highlighted until the stream is loaded and playing!
                        final player = widget.state.widget.controller.player;
                        int ticks = 0;
                        _drawerChannelChangeSub = player.stream.position.listen((pos) {
                          final uri = player.state.playlist.medias.firstOrNull?.uri;
                          final hasVideo = player.state.videoParams.w != null && player.state.videoParams.w! > 0;
                          final targetId = stream.streamId;
                          if (uri != null && uri.contains('/$targetId.') && hasVideo) {
                            ticks++;
                            if (ticks >= 2) {
                              _drawerChannelChangeSub?.cancel();
                              _drawerChannelChangeSub = null;
                              if (mounted && _isDrawerOpen && _channelChangingToStreamId == stream.streamId) {
                                // Short 300ms pause so the user clearly sees the channel confirmed before closing
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  if (mounted && _isDrawerOpen && _channelChangingToStreamId == stream.streamId) {
                                    setState(() {
                                      _isDrawerOpen = false;
                                      _channelChangingToStreamId = null;
                                    });
                                    _startHideTimer();
                                  }
                                });
                              }
                            }
                          }
                        });

                        // Fallback: close drawer after 4 seconds if stream takes unusually long
                        Future.delayed(const Duration(seconds: 4), () {
                          if (mounted && _isDrawerOpen && _channelChangingToStreamId == stream.streamId) {
                            setState(() {
                              _isDrawerOpen = false;
                              _channelChangingToStreamId = null;
                            });
                            _startHideTimer();
                          }
                        });
                      },
                      onClose: () {
                        _drawerChannelChangeSub?.cancel();
                        _drawerChannelChangeSub = null;
                        _channelChangingToStreamId = null;
                        setState(() => _isDrawerOpen = false);
                        _startHideTimer();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }
}
