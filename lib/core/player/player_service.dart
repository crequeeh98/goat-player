import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'engine/goat_player_engine.dart';
import 'engine/goat_player_types.dart';
import 'engine/media_kit_player_engine.dart';
import 'engine/player_engine_factory.dart';

final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

class PlayerService {
  /// The underlying universal cross-platform playback engine
  late final GoatPlayerEngine engine;

  /// Backward-compatibility getter for desktop & Android widgets that interact with media_kit Player
  Player get player {
    if (engine is MediaKitPlayerEngine) {
      return (engine as MediaKitPlayerEngine).rawPlayer;
    }
    throw UnsupportedError('Direct Player access is only available on desktop & Android (media_kit). Use PlayerService.engine on Smart TVs.');
  }

  /// Backward-compatibility getter for desktop & Android widgets that interact with media_kit VideoController
  VideoController get controller {
    if (engine is MediaKitPlayerEngine) {
      return (engine as MediaKitPlayerEngine).rawController;
    }
    throw UnsupportedError('Direct VideoController access is only available on desktop & Android (media_kit). Use PlayerService.engine on Smart TVs.');
  }

  String? get lastOpenedUrl => engine.state.lastOpenedUrl;
  bool _isLive = false;
  bool _isOpening = false;
  bool _isDisposed = false;

  StreamSubscription? _completedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _playingSub;
  Timer? _reconnectTimer;
  Timer? _bufferingWatchdogTimer;
  int _reconnectAttempts = 0;

  PlayerService({GoatPlayerEngine? customEngine}) {
    engine = customEngine ?? PlayerEngineFactory.create();
    _setupAutoReconnect();
  }

  void _setupAutoReconnect() {
    // When playback actually starts and is no longer buffering, reset attempt counter
    _playingSub = engine.stream.playing.listen((isPlaying) {
      if (isPlaying && !engine.state.buffering) {
        _reconnectAttempts = 0;
      }
    });

    // When live stream reaches premature EOF or server drops connection
    _completedSub = engine.stream.completed.listen((completed) {
      if (completed && _isLive && !_isDisposed && !_isOpening && lastOpenedUrl != null) {
        debugPrint('PlayerService: Live stream disconnected or completed. Auto-reconnecting...');
        _scheduleLiveReconnect();
      }
    });

    // When live stream encounters socket or demuxer read error
    _errorSub = engine.stream.error.listen((error) {
      if (_isLive && !_isDisposed && !_isOpening && lastOpenedUrl != null) {
        debugPrint('PlayerService: Live stream error ($error). Auto-reconnecting...');
        _scheduleLiveReconnect();
      }
    });

    // Watchdog: If live stream stays stuck buffering for >= 12 seconds while playing
    _bufferingSub = engine.stream.buffering.listen((isBuffering) {
      _bufferingWatchdogTimer?.cancel();
      if (isBuffering && _isLive && !_isDisposed && !_isOpening && lastOpenedUrl != null && engine.state.playing) {
        _bufferingWatchdogTimer = Timer(const Duration(seconds: 12), () {
          if (_isLive && !_isDisposed && !_isOpening && lastOpenedUrl != null && engine.state.buffering && engine.state.playing) {
            debugPrint('PlayerService: Live stream stuck buffering for 12s. Auto-reconnecting...');
            _scheduleLiveReconnect();
          }
        });
      }
    });
  }

  void _scheduleLiveReconnect() {
    if (!_isLive || _isDisposed || lastOpenedUrl == null) return;
    if (_reconnectAttempts >= 3) {
      debugPrint('PlayerService: Max live reconnect attempts reached (3). Stream is unavailable or offline.');
      return;
    }
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    final delayMs = (_reconnectAttempts == 0) ? 1000 : 3000;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!_isLive || _isDisposed || lastOpenedUrl == null) return;
      _reconnectAttempts++;
      debugPrint('PlayerService: Auto-reconnecting live stream (attempt $_reconnectAttempts/3) to $lastOpenedUrl');
      await open(lastOpenedUrl!, isLive: true, isReconnect: true);
    });
  }

  Future<void> open(String url, {bool isLive = false, Duration? startPosition, bool isReconnect = false}) async {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _isLive = isLive;
    _isOpening = true;
    if (!isReconnect) {
      _reconnectAttempts = 0;
    }

    try {
      await engine.open(url, isLive: isLive, startPosition: startPosition);
    } catch (e) {
      debugPrint('PlayerService open error: $e');
      if (isLive) {
        _scheduleLiveReconnect();
      }
    } finally {
      _isOpening = false;
    }
  }

  /// Reloads/flushes the live stream to snap directly to the live broadcast edge
  Future<void> jumpToLiveEdge() async {
    if (_isDisposed) return;
    await engine.jumpToLiveEdge();
  }

  Future<void> play() async {
    if (_isLive) {
      await jumpToLiveEdge();
    } else {
      await engine.play();
    }
  }

  Future<void> pause() async => engine.pause();

  Future<void> playOrPause() async {
    if (_isLive) {
      if (player.state.playing) {
        await engine.pause();
      } else {
        await jumpToLiveEdge();
      }
    } else {
      await engine.playOrPause();
    }
  }

  Future<void> seek(Duration position) async => engine.seek(position);

  Future<void> setVolume(double volume) async => engine.setVolume(volume);

  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _isLive = false;
    _reconnectAttempts = 0;
    await engine.stop();
  }

  Future<void> setAudioTrack(dynamic track) async {
    if (_isDisposed) return;
    if (track is GoatTrack) {
      await engine.setAudioTrack(track);
    } else if (track is AudioTrack && engine is MediaKitPlayerEngine) {
      await (engine as MediaKitPlayerEngine).player.setAudioTrack(track);
    }
  }

  Future<void> setSubtitleTrack(dynamic track) async {
    if (_isDisposed) return;
    if (track is GoatTrack) {
      await engine.setSubtitleTrack(track);
    } else if (track is SubtitleTrack && engine is MediaKitPlayerEngine) {
      await (engine as MediaKitPlayerEngine).setSubtitleTrack(
        GoatTrack(id: track.id, type: GoatTrackType.subtitle, raw: track),
      );
    }
  }

  /// Universal video rendering widget
  Widget buildVideoWidget({
    Key? key,
    BoxFit fit = BoxFit.contain,
    Widget? subtitleView,
  }) {
    return engine.buildVideoView(
      key: key,
      fit: fit,
      subtitleView: subtitleView,
    );
  }

  Future<void> disposeAsync() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    _playingSub?.cancel();
    try {
      await engine.stop();
      await engine.dispose();
    } catch (e) {
      debugPrint('PlayerService dispose error: $e');
    }
  }

  void dispose() {
    disposeAsync();
  }
}
