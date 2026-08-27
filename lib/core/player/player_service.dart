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

  PlayerService() {
    player = Player(
      configuration: const PlayerConfiguration(),
    );
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
  }

  bool _isDisposed = false;

  Future<void> open(String url) async {
    if (_isDisposed) return;
    try {
      await player.open(Media(url), play: true);
      if (!_isDisposed) {
        await player.play(); // Force play in case auto-play fails
      }
    } catch (e) {
      debugPrint('PlayerService open error: $e');
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
