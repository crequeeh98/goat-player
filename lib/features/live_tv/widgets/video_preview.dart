import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/player/player_service.dart';
import 'epg_timeline.dart';
import 'custom_live_controls.dart';

class VideoPreview extends ConsumerStatefulWidget {
  final String streamUrl;
  final String? channelId;
  final String? channelName;
  final bool isFullWidth;
  final VoidCallback? onToggleFullWidth;
  final VoidCallback? onEnsureFullWidth;
  final VoidCallback? onExitToPreview;

  const VideoPreview({
    super.key,
    required this.streamUrl,
    this.channelId,
    this.channelName,
    this.isFullWidth = false,
    this.onToggleFullWidth,
    this.onEnsureFullWidth,
    this.onExitToPreview,
  });

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerServiceProvider).open(widget.streamUrl);
    });
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      ref.read(playerServiceProvider).open(widget.streamUrl);
    }
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

    return Container(
      color: Colors.black,
      child: Center(
        child: Video(
          controller: playerService.controller,
          controls: (state) => CustomLiveControls(
            state: state,
            title: displayTitle,
            showBackButton: widget.isFullWidth,
            onBack: widget.onExitToPreview ?? widget.onToggleFullWidth,
            onSingleTap: () {
              if (!widget.isFullWidth && widget.onToggleFullWidth != null) {
                widget.onToggleFullWidth!();
              }
            },
            onEnterFullWidth: widget.onEnsureFullWidth,
          ),
        ),
      ),
    );
  }
}
