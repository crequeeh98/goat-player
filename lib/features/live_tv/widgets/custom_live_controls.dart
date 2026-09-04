import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/player/playback_controller.dart';
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
  });

  @override
  ConsumerState<CustomLiveControls> createState() => _CustomLiveControlsState();
}

class _CustomLiveControlsState extends ConsumerState<CustomLiveControls> {
  bool _showOverlay = true;
  Timer? _hideTimer;
  double _volume = 100.0;
  bool _isPlaying = true;
  String? _optimisticStreamId;

  // In-Player EPG Drawer & OSD Banner state
  bool _isDrawerOpen = false;
  bool _showOsdBanner = false;
  Timer? _osdBannerTimer;
  StreamSubscription? _volumeSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _drawerChannelChangeSub;
  String? _channelChangingToStreamId;

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
    _drawerChannelChangeSub?.cancel();
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

  DateTime _lastLiveTimerReset = DateTime.now();

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
    final canShowDrawer = (isFull || widget.isFullWidth) && (widget.streams != null && widget.streams!.isNotEmpty);
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
    final canShowDrawer = (isFull || widget.isFullWidth) && (widget.streams != null && widget.streams!.isNotEmpty);

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
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.pageUp ||
              event.logicalKey == LogicalKeyboardKey.channelUp) {
            _zapNext();
            return KeyEventResult.handled;
          }

          // Channel Down: Previous Channel
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.channelDown) {
            _zapPrevious();
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
        onHover: _onPointerEvent,
        onEnter: _onPointerEvent,
        onExit: (_) {
          if (_isPlaying && !_isDrawerOpen) {
            setState(() => _showOverlay = false);
          }
        },
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

                        // BOTTOM LEFT: In-Player EPG Drawer Button (Only in Full-Width or Fullscreen)
                        if (canShowDrawer)
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
                            displayTitle,
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

                        // BOTTOM RIGHT: Fullscreen Toggle
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: IconButton(
                            icon: Icon(
                              isFull ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () => _toggleFullscreen(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. In-Player OSD Channel Info Banner (Appears on zap)
                if (_showOsdBanner && currentStreamItem != null)
                  Positioned(
                    top: 40,
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
