import 'package:flutter/widgets.dart';
import 'goat_player_types.dart';

/// Universal video player engine contract across desktop, mobile, and Smart TVs.
abstract class GoatPlayerEngine {
  /// Current playback state snapshot
  GoatPlayerState get state;

  /// Reactive playback event streams
  GoatPlayerStream get stream;

  /// Initialize engine resources
  Future<void> initialize();

  /// Open media stream (Live TV or VOD)
  Future<void> open(String url, {bool isLive = false, Duration? startPosition});

  /// Resume playback
  Future<void> play();

  /// Pause playback
  Future<void> pause();

  /// Toggle play/pause state
  Future<void> playOrPause();

  /// Stop current playback
  Future<void> stop();

  /// Seek to position
  Future<void> seek(Duration position);

  /// Set audio volume (0.0 to 100.0)
  Future<void> setVolume(double volume);

  /// Set playback rate (1.0 = normal)
  Future<void> setRate(double rate);

  /// Select active audio track
  Future<void> setAudioTrack(GoatTrack track);

  /// Select active subtitle track
  Future<void> setSubtitleTrack(GoatTrack track);

  /// Reloads/flushes live stream buffer to snap to the latest live edge
  Future<void> jumpToLiveEdge();

  /// Free all player and native engine resources
  Future<void> dispose();

  /// Build the platform-specific video rendering widget
  Widget buildVideoView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    Widget? subtitleView,
  });
}
