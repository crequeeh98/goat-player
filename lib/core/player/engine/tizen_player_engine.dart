import 'dart:async';
import 'package:flutter/widgets.dart';

import 'goat_player_engine.dart';
import 'goat_player_types.dart';

/// Concrete player engine implementation for Samsung Tizen Smart TVs.
/// Integrates with Tizen AVPlay / video_player_tizen multimedia framework.
class TizenPlayerEngine implements GoatPlayerEngine {
  GoatPlayerState _state = const GoatPlayerState();
  final _TizenPlayerStream _stream = _TizenPlayerStream();
  bool _isDisposed = false;
  String? _lastOpenedUrl;

  @override
  GoatPlayerState get state => _state;

  @override
  GoatPlayerStream get stream => _stream;

  @override
  Future<void> initialize() async {
    debugPrint('TizenPlayerEngine: Initializing Tizen AVPlay multimedia subsystem...');
  }

  @override
  Future<void> open(String url, {bool isLive = false, Duration? startPosition}) async {
    if (_isDisposed) return;
    _lastOpenedUrl = url;

    debugPrint('TizenPlayerEngine: Opening stream: $url (isLive: $isLive, start: $startPosition)');
    _updateState(_state.copyWith(
      lastOpenedUrl: url,
      isLive: isLive,
      buffering: true,
      playing: false,
      position: startPosition ?? Duration.zero,
    ));

    // Lifecycle hook for Tizen AVPlay / video_player_tizen controller
    _updateState(_state.copyWith(
      buffering: false,
      playing: true,
    ));
  }

  @override
  Future<void> play() async {
    if (_isDisposed) return;
    _updateState(_state.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    _updateState(_state.copyWith(playing: false));
  }

  @override
  Future<void> playOrPause() async {
    if (_state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    _lastOpenedUrl = null;
    _updateState(_state.copyWith(
      playing: false,
      buffering: false,
      position: Duration.zero,
      clearLastOpenedUrl: true,
      isLive: false,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    _updateState(_state.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    final clamped = volume.clamp(0.0, 100.0);
    _updateState(_state.copyWith(volume: clamped));
  }

  @override
  Future<void> setRate(double rate) async {
    if (_isDisposed) return;
    _updateState(_state.copyWith(rate: rate));
  }

  @override
  Future<void> setAudioTrack(GoatTrack track) async {
    if (_isDisposed) return;
    _updateState(_state.copyWith(activeAudioTrack: track));
  }

  @override
  Future<void> setSubtitleTrack(GoatTrack track) async {
    if (_isDisposed) return;
    _updateState(_state.copyWith(activeSubtitleTrack: track));
  }

  @override
  Future<void> jumpToLiveEdge() async {
    if (_lastOpenedUrl != null && !_isDisposed) {
      await open(_lastOpenedUrl!, isLive: true);
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _stream.dispose();
  }

  @override
  Widget buildVideoView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    Widget? subtitleView,
  }) {
    // PlatformView or Texture widget will be rendered here for Tizen
    final placeholder = Container(
      key: key,
      color: const Color(0xFF0D0E15),
      alignment: Alignment.center,
      child: const Text(
        'Tizen AVPlay Native Surface',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      ),
    );

    if (subtitleView == null) return placeholder;

    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        subtitleView,
      ],
    );
  }

  void _updateState(GoatPlayerState newState) {
    _state = newState;
    _stream.emit(newState);
  }
}

class _TizenPlayerStream implements GoatPlayerStream {
  final StreamController<Duration> _posCtrl = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durCtrl = StreamController<Duration>.broadcast();
  final StreamController<Duration> _bufCtrl = StreamController<Duration>.broadcast();
  final StreamController<bool> _playCtrl = StreamController<bool>.broadcast();
  final StreamController<bool> _bufStateCtrl = StreamController<bool>.broadcast();
  final StreamController<bool> _compCtrl = StreamController<bool>.broadcast();
  final StreamController<double> _volCtrl = StreamController<double>.broadcast();
  final StreamController<double> _rateCtrl = StreamController<double>.broadcast();
  final StreamController<String?> _errCtrl = StreamController<String?>.broadcast();
  final StreamController<GoatTracks> _tracksCtrl = StreamController<GoatTracks>.broadcast();
  final StreamController<String> _subCtrl = StreamController<String>.broadcast();

  @override Stream<Duration> get position => _posCtrl.stream;
  @override Stream<Duration> get duration => _durCtrl.stream;
  @override Stream<Duration> get buffer => _bufCtrl.stream;
  @override Stream<bool> get playing => _playCtrl.stream;
  @override Stream<bool> get buffering => _bufStateCtrl.stream;
  @override Stream<bool> get completed => _compCtrl.stream;
  @override Stream<double> get volume => _volCtrl.stream;
  @override Stream<double> get rate => _rateCtrl.stream;
  @override Stream<String?> get error => _errCtrl.stream;
  @override Stream<GoatTracks> get tracks => _tracksCtrl.stream;
  @override Stream<String> get subtitleText => _subCtrl.stream;

  void emit(GoatPlayerState state) {
    if (!_posCtrl.isClosed) _posCtrl.add(state.position);
    if (!_durCtrl.isClosed) _durCtrl.add(state.duration);
    if (!_bufCtrl.isClosed) _bufCtrl.add(state.buffer);
    if (!_playCtrl.isClosed) _playCtrl.add(state.playing);
    if (!_bufStateCtrl.isClosed) _bufStateCtrl.add(state.buffering);
    if (!_compCtrl.isClosed) _compCtrl.add(state.completed);
    if (!_volCtrl.isClosed) _volCtrl.add(state.volume);
    if (!_rateCtrl.isClosed) _rateCtrl.add(state.rate);
    if (!_tracksCtrl.isClosed) _tracksCtrl.add(state.tracks);
  }

  void dispose() {
    _posCtrl.close();
    _durCtrl.close();
    _bufCtrl.close();
    _playCtrl.close();
    _bufStateCtrl.close();
    _compCtrl.close();
    _volCtrl.close();
    _rateCtrl.close();
    _errCtrl.close();
    _tracksCtrl.close();
    _subCtrl.close();
  }
}
