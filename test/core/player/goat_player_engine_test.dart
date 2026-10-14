import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/player/engine/goat_player_engine.dart';
import 'package:goat_player/core/player/engine/goat_player_types.dart';
import 'package:goat_player/core/player/engine/player_engine_factory.dart';
import 'package:goat_player/core/player/player_service.dart';

class FakeGoatPlayerEngine implements GoatPlayerEngine {
  GoatPlayerState _state = const GoatPlayerState();
  final _FakePlayerStream _stream = _FakePlayerStream();
  bool _isDisposed = false;

  @override
  GoatPlayerState get state => _state;

  @override
  GoatPlayerStream get stream => _stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> open(String url, {bool isLive = false, Duration? startPosition}) async {
    if (_isDisposed) return;
    _state = _state.copyWith(
      lastOpenedUrl: url,
      isLive: isLive,
      playing: true,
      position: startPosition ?? Duration.zero,
    );
  }

  @override
  Future<void> play() async {
    _state = _state.copyWith(playing: true);
  }

  @override
  Future<void> pause() async {
    _state = _state.copyWith(playing: false);
  }

  @override
  Future<void> playOrPause() async {
    _state = _state.copyWith(playing: !_state.playing);
  }

  @override
  Future<void> stop() async {
    _state = _state.copyWith(playing: false, position: Duration.zero, clearLastOpenedUrl: true);
  }

  @override
  Future<void> seek(Duration position) async {
    _state = _state.copyWith(position: position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _state = _state.copyWith(volume: volume);
  }

  @override
  Future<void> setRate(double rate) async {
    _state = _state.copyWith(rate: rate);
  }

  @override
  Future<void> setAudioTrack(GoatTrack track) async {
    _state = _state.copyWith(activeAudioTrack: track);
  }

  @override
  Future<void> setSubtitleTrack(GoatTrack track) async {
    _state = _state.copyWith(activeSubtitleTrack: track);
  }

  @override
  Future<void> jumpToLiveEdge() async {}

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _stream.dispose();
  }

  @override
  Widget buildVideoView({Key? key, BoxFit fit = BoxFit.contain, Widget? subtitleView}) {
    return Container(key: key);
  }
}

class _FakePlayerStream implements GoatPlayerStream {
  final _playingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _volumeCtrl = StreamController<double>.broadcast();
  final _rateCtrl = StreamController<double>.broadcast();
  final _tracksCtrl = StreamController<GoatTracks>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _bufferCtrl = StreamController<Duration>.broadcast();
  final _subtitleTextCtrl = StreamController<String>.broadcast();

  @override Stream<bool> get playing => _playingCtrl.stream;
  @override Stream<bool> get completed => _completedCtrl.stream;
  @override Stream<bool> get buffering => _bufferingCtrl.stream;
  @override Stream<Duration> get position => _positionCtrl.stream;
  @override Stream<Duration> get duration => _durationCtrl.stream;
  @override Stream<double> get volume => _volumeCtrl.stream;
  @override Stream<double> get rate => _rateCtrl.stream;
  @override Stream<GoatTracks> get tracks => _tracksCtrl.stream;
  @override Stream<String> get error => _errorCtrl.stream;
  @override Stream<Duration> get buffer => _bufferCtrl.stream;
  @override Stream<String> get subtitleText => _subtitleTextCtrl.stream;

  Future<void> dispose() async {
    await _playingCtrl.close();
    await _completedCtrl.close();
    await _bufferingCtrl.close();
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _volumeCtrl.close();
    await _rateCtrl.close();
    await _tracksCtrl.close();
    await _errorCtrl.close();
    await _bufferCtrl.close();
    await _subtitleTextCtrl.close();
  }
}

void main() {
  group('GoatPlayerEngine Abstraction Layer', () {
    test('FakeGoatPlayerEngine opens, plays, pauses, seeks, and updates state correctly', () async {
      final engine = FakeGoatPlayerEngine();
      expect(engine.state.playing, isFalse);
      expect(engine.state.isLive, isFalse);

      await engine.open('http://iptv.example/live/123.ts', isLive: true);
      expect(engine.state.lastOpenedUrl, 'http://iptv.example/live/123.ts');
      expect(engine.state.isLive, isTrue);
      expect(engine.state.playing, isTrue);

      await engine.pause();
      expect(engine.state.playing, isFalse);

      await engine.play();
      expect(engine.state.playing, isTrue);

      await engine.seek(const Duration(seconds: 45));
      expect(engine.state.position, const Duration(seconds: 45));

      await engine.setVolume(75.0);
      expect(engine.state.volume, 75.0);

      await engine.stop();
      expect(engine.state.playing, isFalse);
      expect(engine.state.position, Duration.zero);
      expect(engine.state.lastOpenedUrl, isNull);

      await engine.dispose();
    });

    test('PlayerEngineFactory supports mock engine injection', () {
      final mock = FakeGoatPlayerEngine();
      PlayerEngineFactory.setMockEngine(mock);

      final engine = PlayerEngineFactory.create();
      expect(identical(engine, mock), isTrue);

      PlayerEngineFactory.setMockEngine(null);
    });

    test('PlayerService operates transparently over GoatPlayerEngine', () async {
      final mock = FakeGoatPlayerEngine();
      final service = PlayerService(customEngine: mock);

      await service.open('http://iptv.example/series/789.mkv', isLive: false);
      expect(service.lastOpenedUrl, 'http://iptv.example/series/789.mkv');
      expect(service.engine.state.playing, isTrue);

      await service.pause();
      expect(service.engine.state.playing, isFalse);

      await service.play();
      expect(service.engine.state.playing, isTrue);

      await service.setVolume(80.0);
      expect(service.engine.state.volume, 80.0);

      await service.stop();
      expect(service.engine.state.playing, isFalse);

      await service.disposeAsync();
    });
  });
}
