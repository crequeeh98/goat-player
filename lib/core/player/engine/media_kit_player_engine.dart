import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../utils/platform_utils.dart';
import 'goat_player_engine.dart';
import 'goat_player_types.dart';

/// Concrete player engine implementation for Windows Desktop & Android using media_kit and libmpv.
class MediaKitPlayerEngine implements GoatPlayerEngine {
  late final Player player;
  late final VideoController controller;

  late final _MediaKitPlayerStream _stream;
  bool _isDisposed = false;
  bool _isLive = false;
  String? _lastOpenedUrl;

  /// Direct access to the underlying media_kit Player for backward compatibility
  Player get rawPlayer => player;

  /// Direct access to the underlying media_kit VideoController for backward compatibility
  VideoController get rawController => controller;

  MediaKitPlayerEngine() {
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024, // 32MB buffer
      ),
    );
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        vo: GoatPlatform.isTv ? 'gpu' : null,
        hwdec: GoatPlatform.isTv ? 'mediacodec-copy' : null,
      ),
    );
    _stream = _MediaKitPlayerStream(player);
    player.stream.videoParams.listen((vp) {
      debugPrint('[GOAT_PLAY] mpv videoParams received: ${vp.w}x${vp.h}');
    });
    player.stream.buffering.listen((b) {
      debugPrint('[GOAT_PLAY] mpv buffering: $b');
    });
    _applyMpvOptimizations(isLive: false);
  }

  @override
  GoatPlayerState get state {
    final s = player.state;
    return GoatPlayerState(
      position: s.position,
      duration: s.duration,
      buffer: s.buffer,
      playing: s.playing,
      buffering: s.buffering,
      completed: s.completed,
      volume: s.volume,
      rate: s.rate,
      tracks: _convertTracks(s.tracks),
      activeAudioTrack: _convertAudioTrack(s.track.audio, isSelected: true),
      activeSubtitleTrack: _convertSubtitleTrack(s.track.subtitle, isSelected: true),
      lastOpenedUrl: _lastOpenedUrl,
      isLive: _isLive,
    );
  }

  @override
  GoatPlayerStream get stream => _stream;

  @override
  Future<void> initialize() async {
    // MediaKit.ensureInitialized is called in main.dart
  }

  bool? _lastAppliedIsLive;

  void _applyMpvOptimizations({bool isLive = false}) {
    if (_lastAppliedIsLive == isLive) return;
    _lastAppliedIsLive = isLive;
    try {
      final dynamic platform = player.platform;
      if (GoatPlatform.isTv) {
        platform?.setProperty('hwdec', 'mediacodec-copy');
        platform?.setProperty('force-window', 'yes');
      } else {
        platform?.setProperty('hwdec', 'auto-safe');
        platform?.setProperty('force-window', 'no');
      }
      platform?.setProperty('video-sync', 'audio');

      if (isLive) {
        platform?.setProperty('demuxer-lavf-analyzeduration', '1.5');
        platform?.setProperty('demuxer-lavf-probesize', '2097152');
        platform?.setProperty('demuxer-readahead-secs', '6');
        platform?.setProperty('demuxer-max-bytes', '16777216');
        platform?.setProperty('cache', 'yes');
        platform?.setProperty('cache-pause', 'no');
        platform?.setProperty('network-timeout', '8');
      } else {
        platform?.setProperty('demuxer-lavf-analyzeduration', '3.0');
        platform?.setProperty('demuxer-lavf-probesize', '6291456');
        platform?.setProperty('demuxer-max-bytes', '33554432');
        platform?.setProperty('demuxer-readahead-secs', '10');
        platform?.setProperty('cache', 'yes');
        platform?.setProperty('cache-pause', 'yes');
        platform?.setProperty('network-timeout', '15');
      }

      platform?.setProperty('keep-open', 'yes');
      platform?.setProperty('ytdl', 'no');
      platform?.setProperty('secondary-sid', 'no');
      platform?.setProperty('sub-visibility', 'no');
    } catch (e) {
      debugPrint('MediaKitPlayerEngine mpv optimizations error: $e');
    }
  }

  @override
  Future<void> open(String url, {bool isLive = false, Duration? startPosition}) async {
    if (_isDisposed) return;
    debugPrint('[GOAT_PLAY] MediaKitPlayerEngine.open: url="$url", isLive=$isLive');
    _isLive = isLive;
    _lastOpenedUrl = url;
    _applyMpvOptimizations(isLive: isLive);

    try {
      await player.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'IPTVSmartersPlayer',
          },
          start: startPosition,
        ),
        play: true,
      ).timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('[GOAT_PLAY] player.open TIMED OUT after 6s for: $url');
        },
      );
      debugPrint('[GOAT_PLAY] player.open RESOLVED successfully for: $url');
    } catch (e, st) {
      debugPrint('[GOAT_PLAY] player.open CAUGHT EXCEPTION: $e\n$st');
    }
  }

  @override
  Future<void> play() async {
    if (!_isDisposed) await player.play();
  }

  @override
  Future<void> pause() async {
    if (!_isDisposed) await player.pause();
  }

  @override
  Future<void> playOrPause() async {
    if (!_isDisposed) await player.playOrPause();
  }

  @override
  Future<void> stop() async {
    if (!_isDisposed) {
      _lastOpenedUrl = null;
      _isLive = false;
      try {
        await player.stop().timeout(const Duration(milliseconds: 500), onTimeout: () {});
      } catch (_) {}
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_isDisposed) await player.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!_isDisposed) await player.setVolume(volume.clamp(0.0, 100.0));
  }

  @override
  Future<void> setRate(double rate) async {
    if (!_isDisposed) await player.setRate(rate);
  }

  @override
  Future<void> setAudioTrack(GoatTrack track) async {
    if (_isDisposed) return;
    if (track.raw is AudioTrack) {
      await player.setAudioTrack(track.raw as AudioTrack);
      return;
    }
    final target = player.state.tracks.audio.firstWhere(
      (t) => t.id == track.id,
      orElse: () => AudioTrack.auto(),
    );
    await player.setAudioTrack(target);
  }

  @override
  Future<void> setSubtitleTrack(GoatTrack track) async {
    if (_isDisposed) return;
    try {
      final dynamic platform = player.platform;
      platform?.setProperty('secondary-sid', 'no');
      platform?.setProperty('sub-visibility', 'no');
    } catch (_) {}

    if (track.raw is SubtitleTrack) {
      await player.setSubtitleTrack(track.raw as SubtitleTrack);
      return;
    }
    final target = player.state.tracks.subtitle.firstWhere(
      (t) => t.id == track.id,
      orElse: () => SubtitleTrack.no(),
    );
    await player.setSubtitleTrack(target);
  }

  @override
  Future<void> jumpToLiveEdge() async {
    if (_isDisposed) return;
    try {
      if (player.state.duration > const Duration(seconds: 5)) {
        await player.seek(player.state.duration - const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('MediaKitPlayerEngine jumpToLiveEdge error: $e');
    }
    await player.play();
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _stream.dispose();
    await player.stop();
    await player.dispose();
  }

  @override
  Widget buildVideoView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    Widget? subtitleView,
  }) {
    final video = Video(
      key: key,
      controller: controller,
      controls: NoVideoControls,
      fit: fit,
    );

    if (subtitleView == null) return video;

    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        subtitleView,
      ],
    );
  }

  static GoatTrack _convertAudioTrack(AudioTrack track, {bool isSelected = false}) {
    return GoatTrack(
      id: track.id,
      title: track.title,
      language: track.language,
      channels: track.channels?.toString(),
      type: GoatTrackType.audio,
      isSelected: isSelected,
      raw: track,
    );
  }

  static GoatTrack _convertSubtitleTrack(SubtitleTrack track, {bool isSelected = false}) {
    return GoatTrack(
      id: track.id,
      title: track.title,
      language: track.language,
      type: GoatTrackType.subtitle,
      isSelected: isSelected,
      raw: track,
    );
  }

  static GoatTracks _convertTracks(Tracks tracks) {
    return GoatTracks(
      audio: tracks.audio.map((t) => _convertAudioTrack(t)).toList(),
      subtitle: tracks.subtitle.map((t) => _convertSubtitleTrack(t)).toList(),
      video: tracks.video.map((t) => GoatTrack(
        id: t.id,
        title: t.title,
        language: t.language,
        type: GoatTrackType.video,
        raw: t,
      )).toList(),
    );
  }
}

class _MediaKitPlayerStream implements GoatPlayerStream {
  final Player _player;
  final StreamController<GoatTracks> _tracksController = StreamController<GoatTracks>.broadcast();
  StreamSubscription? _tracksSub;

  _MediaKitPlayerStream(this._player) {
    _tracksSub = _player.stream.tracks.listen((tracks) {
      if (!_tracksController.isClosed) {
        _tracksController.add(MediaKitPlayerEngine._convertTracks(tracks));
      }
    });
  }

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<Duration> get buffer => _player.stream.buffer;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<double> get volume => _player.stream.volume;

  @override
  Stream<double> get rate => _player.stream.rate;

  @override
  Stream<String?> get error => _player.stream.error;

  @override
  Stream<GoatTracks> get tracks => _tracksController.stream;

  @override
  Stream<String> get subtitleText => _player.stream.subtitle.map((lines) => lines.join('\n'));

  void dispose() {
    _tracksSub?.cancel();
    _tracksController.close();
  }
}
