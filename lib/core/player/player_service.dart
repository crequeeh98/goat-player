import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/foundation.dart';

final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

class PlayerService {
  late final Player player;
  late final VideoController controller;

  String? _lastOpenedUrl;

  PlayerService() {
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 8 * 1024 * 1024, // 8MB buffer for snappy startup
      ),
    );
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _applyMpvOptimizations();
  }

  void _applyMpvOptimizations({bool isLive = false}) {
    try {
      final dynamic platform = player.platform;
      // Hardware accelerated video decoding (D3D11VA/DXVA2 on Windows)
      platform?.setProperty('hwdec', 'auto-safe');
      // Synchronize video to audio clock to eliminate startup frame drops & stuttering
      platform?.setProperty('video-sync', 'audio');

      if (isLive) {
        // Snappy stream startup for Live TS/HLS streams (reduces demuxer probe time from 5s down to 1s)
        platform?.setProperty('demuxer-lavf-analyzeduration', '1.0');
        platform?.setProperty('demuxer-lavf-probesize', '1048576');
      } else {
        // Generous probe & pre-buffer for VOD movies / series to completely eliminate startup stuttering
        platform?.setProperty('demuxer-lavf-analyzeduration', '3.0');
        platform?.setProperty('demuxer-lavf-probesize', '6291456'); // 6MB probe
        platform?.setProperty('demuxer-max-bytes', '33554432'); // 32MB cache buffer
        platform?.setProperty('demuxer-readahead-secs', '10');
      }

      platform?.setProperty('keep-open', 'yes');
      platform?.setProperty('force-window', 'no');
      platform?.setProperty('ytdl', 'no');
      // Prevent secondary/crude native subtitles (let Flutter SubtitleView render cleanly)
      platform?.setProperty('secondary-sid', 'no');
      platform?.setProperty('secondary-sub-visibility', 'no');
      platform?.setProperty('sub-visibility', 'no');
    } catch (e) {
      debugPrint('PlayerService mpv optimizations error: $e');
    }
  }

  bool _isDisposed = false;

  Future<void> open(String url, {bool isLive = false, Duration? startPosition}) async {
    if (_isDisposed) return;
    _lastOpenedUrl = url;
    try {
      _applyMpvOptimizations(isLive: isLive);

      await player.open(
        Media(
          url,
          start: startPosition,
        ),
        play: true,
      );
      if (!_isDisposed) {
        await player.play(); // Force play in case auto-play fails
      }
    } catch (e) {
      debugPrint('PlayerService open error: $e');
    }
  }

  /// Reloads/flushes the live stream to snap directly to the live broadcast edge
  Future<void> jumpToLiveEdge() async {
    if (_lastOpenedUrl != null && !_isDisposed) {
      await open(_lastOpenedUrl!);
    } else {
      await player.play();
    }
  }

  Future<void> play() async => player.play();
  
  Future<void> pause() async => player.pause();
  
  Future<void> stop() async => player.stop();

  Future<void> setAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    try {
      final dynamic platform = player.platform;
      platform?.setProperty('secondary-sid', 'no');
      platform?.setProperty('secondary-sub-visibility', 'no');
      platform?.setProperty('sub-visibility', 'no');
    } catch (_) {}
    await player.setSubtitleTrack(track);
  }

  Future<void> disposeAsync() async {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      await player.stop();
      await player.dispose();
    } catch (e) {
      debugPrint('PlayerService dispose error: $e');
    }
  }

  void dispose() {
    disposeAsync(); // Fire and forget for simple synchronous dispose
  }
}
