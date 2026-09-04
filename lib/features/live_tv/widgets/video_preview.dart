import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/database/app_database.dart';
import '../../../core/player/player_service.dart';
import 'epg_timeline.dart';
import 'custom_live_controls.dart';
import '../../../core/player/widgets/mobile_gesture_detector.dart';

class VideoPreview extends ConsumerStatefulWidget {
  final String streamUrl;
  final String? streamId;
  final String? channelId;
  final String? channelName;
  final bool isFullWidth;
  final VoidCallback? onToggleFullWidth;
  final VoidCallback? onEnsureFullWidth;
  final VoidCallback? onExitToPreview;

  // In-stream EPG Drawer & Zapping
  final List<StreamItem>? streams;
  final ValueChanged<StreamItem>? onSelectStream;
  final VoidCallback? onZapPrevious;
  final VoidCallback? onZapNext;
  final String? categoryName;

  const VideoPreview({
    super.key,
    required this.streamUrl,
    this.streamId,
    this.channelId,
    this.channelName,
    this.isFullWidth = false,
    this.onToggleFullWidth,
    this.onEnsureFullWidth,
    this.onExitToPreview,
    this.streams,
    this.onSelectStream,
    this.onZapPrevious,
    this.onZapNext,
    this.categoryName,
  });

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  BoxFit _fit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(playerServiceProvider).player;
      final currentUri = player.state.playlist.medias.firstOrNull?.uri;
      if (currentUri != widget.streamUrl) {
        ref.read(playerServiceProvider).open(widget.streamUrl, isLive: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      final player = ref.read(playerServiceProvider).player;
      final currentUri = player.state.playlist.medias.firstOrNull?.uri;
      if (currentUri != widget.streamUrl) {
        ref.read(playerServiceProvider).open(widget.streamUrl, isLive: true);
      }
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(playerServiceProvider);
    
    // Compute Title from EPG
    String displayTitle = widget.channelName ?? 'Live TV';
    if (widget.channelId != null) {
      final epgList = ref.watch(channelProgramsProvider(widget.channelId!));
      final now = DateTime.now();
      
      final currentShow = epgList.asData?.value.where((p) {
        return now.isAfter(p.startTime) && now.isBefore(p.stopTime);
      }).firstOrNull;

      if (currentShow != null && currentShow.title.isNotEmpty) {
        displayTitle = '${widget.channelName} - ${currentShow.title}';
      }
    }

    final video = Video(
      controller: playerService.controller,
      fit: _fit,
      controls: (state) => CustomLiveControls(
        state: state,
        title: displayTitle,
        showBackButton: widget.isFullWidth,
        isFullWidth: widget.isFullWidth,
        onBack: widget.onExitToPreview ?? widget.onToggleFullWidth,
        onCycleFit: _cycleFit,
        currentFit: _fit,
        onSingleTap: () {
          if (!widget.isFullWidth && widget.onToggleFullWidth != null) {
            widget.onToggleFullWidth!();
          }
        },
        onEnterFullWidth: widget.onEnsureFullWidth,
        onCatchUpLive: () {
          playerService.jumpToLiveEdge();
        },
        streams: widget.streams,
        streamId: widget.streamId,
        currentStreamId: widget.streamId ?? widget.channelId,
        onSelectStream: widget.onSelectStream,
        onZapPrevious: widget.onZapPrevious,
        onZapNext: widget.onZapNext,
        categoryName: widget.categoryName,
      ),
    );

    return Container(
      color: Colors.black,
      child: Center(
        child: (Platform.isAndroid || Platform.isIOS)
            ? MobileGestureDetector(
                player: playerService.player,
                enableSeek: false,
                child: video,
              )
            : video,
      ),
    );
  }
}
