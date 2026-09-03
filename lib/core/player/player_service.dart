import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/foundation.dart';

final playerServiceProvider = Provider.autoDispose<PlayerService>((ref) {
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

    // Apply low-latency mpv options if supported by platform
    try {
      final dynamic platform = player.platform;
      platform?.setProperty('demuxer-lavf-o', 'fflags=+nobuffer+discardcorrupt');
      platform?.setProperty('network-timeout', '5');
      platform?.setProperty('demuxer-readahead-secs', '2');
    } catch (_) {}
  }

  bool _isDisposed = false;

  Future<void> open(String url) async {
    if (_isDisposed) return;
    _lastOpenedUrl = url;
    try {
      await player.open(Media(url), play: true);
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
