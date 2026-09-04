import 'dart:async';
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
  String? get lastOpenedUrl => _lastOpenedUrl;
  bool _isLive = false;
  bool _isOpening = false;
  bool _isDisposed = false;

  StreamSubscription? _completedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;
  Timer? _reconnectTimer;
  Timer? _bufferingWatchdogTimer;
  int _reconnectAttempts = 0;

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
    _setupAutoReconnect();
  }

  void _setupAutoReconnect() {
    // When live stream reaches premature EOF or server drops connection
    _completedSub = player.stream.completed.listen((completed) {
      if (completed && _isLive && !_isDisposed && !_isOpening && _lastOpenedUrl != null) {
        final currentUri = player.state.playlist.medias.firstOrNull?.uri;
        if (currentUri == _lastOpenedUrl) {
          debugPrint('PlayerService: Live stream disconnected or completed. Auto-reconnecting...');
          _scheduleLiveReconnect();
        }
      }
    });

    // When live stream encounters socket or demuxer read error
    _errorSub = player.stream.error.listen((error) {
      if (_isLive && !_isDisposed && !_isOpening && _lastOpenedUrl != null) {
        debugPrint('PlayerService: Live stream error ($error). Auto-reconnecting...');
        _scheduleLiveReconnect();
      }
    });

    // Watchdog: If live stream stays stuck buffering for >= 12 seconds while playing
    _bufferingSub = player.stream.buffering.listen((isBuffering) {
      _bufferingWatchdogTimer?.cancel();
      if (isBuffering && _isLive && !_isDisposed && !_isOpening && _lastOpenedUrl != null && player.state.playing) {
        _bufferingWatchdogTimer = Timer(const Duration(seconds: 12), () {
          if (_isLive && !_isDisposed && !_isOpening && _lastOpenedUrl != null && player.state.buffering && player.state.playing) {
            debugPrint('PlayerService: Live stream stuck buffering for 12s. Auto-reconnecting...');
            _scheduleLiveReconnect();
          }
        });
      }
    });
  }

  void _scheduleLiveReconnect() {
    if (!_isLive || _isDisposed || _lastOpenedUrl == null) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    final delayMs = (_reconnectAttempts == 0) ? 600 : 1500;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!_isLive || _isDisposed || _lastOpenedUrl == null) return;
      _reconnectAttempts++;
      debugPrint('PlayerService: Auto-reconnecting live stream (attempt $_reconnectAttempts) to $_lastOpenedUrl');
      await open(_lastOpenedUrl!, isLive: true);
    });
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
        platform?.setProperty('demuxer-readahead-secs', '2');
        platform?.setProperty('demuxer-max-bytes', '4194304'); // 4MB cache
        platform?.setProperty('cache', 'yes');
        platform?.setProperty('cache-pause', 'no'); // Prevent live stream from permanently freezing on cache underrun
        platform?.setProperty('network-timeout', '10');
        // Auto-reconnect at libavformat level on TCP/HTTP drops or premature EOF
        platform?.setProperty('demuxer-lavf-o', 'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5');
        platform?.setProperty('stream-lavf-o', 'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5');
      } else {
        // Generous probe & pre-buffer for VOD movies / series to completely eliminate startup stuttering
        platform?.setProperty('demuxer-lavf-analyzeduration', '3.0');
        platform?.setProperty('demuxer-lavf-probesize', '6291456'); // 6MB probe
        platform?.setProperty('demuxer-max-bytes', '33554432'); // 32MB cache buffer
        platform?.setProperty('demuxer-readahead-secs', '10');
        platform?.setProperty('cache', 'yes');
        platform?.setProperty('cache-pause', 'yes');
        platform?.setProperty('network-timeout', '15');
      }

      platform?.setProperty('keep-open', 'yes');
      platform?.setProperty('force-window', 'no');
      platform?.setProperty('ytdl', 'no');
      platform?.setProperty('secondary-sid', 'no');
      platform?.setProperty('sub-visibility', 'no');
    } catch (e) {
      debugPrint('PlayerService mpv optimizations error: $e');
    }
  }

  Future<void> open(String url, {bool isLive = false, Duration? startPosition}) async {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _isLive = isLive;
    _lastOpenedUrl = url;
    _isOpening = true;
    try {
      _applyMpvOptimizations(isLive: isLive);

      await player.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'IPTVSmartersPlayer',
          },
          start: startPosition,
        ),
        play: true,
      );
      if (!_isDisposed) {
        await player.play(); // Force play in case auto-play fails
        _reconnectAttempts = 0;
      }
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
    if (_lastOpenedUrl != null && !_isDisposed) {
      await open(_lastOpenedUrl!, isLive: true);
    } else {
      await player.play();
    }
  }

  Future<void> play() async => player.play();
  
  Future<void> pause() async => player.pause();
  
  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _isLive = false;
    _lastOpenedUrl = null;
    _reconnectAttempts = 0;
    await player.stop();
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    try {
      final dynamic platform = player.platform;
      platform?.setProperty('secondary-sid', 'no');
      platform?.setProperty('sub-visibility', 'no');
    } catch (_) {}
    await player.setSubtitleTrack(track);
  }

  Future<void> disposeAsync() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _bufferingWatchdogTimer?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
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
