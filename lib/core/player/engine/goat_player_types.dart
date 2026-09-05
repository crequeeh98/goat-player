import 'dart:async';

/// Supported track types
enum GoatTrackType {
  audio,
  subtitle,
  video,
}

/// Generic track representation across any media engine (MediaKit, Tizen AVPlay, webOS MSE).
class GoatTrack {
  final String id;
  final String? title;
  final String? language;
  final String? channels;
  final GoatTrackType type;
  final bool isSelected;
  final dynamic raw;

  const GoatTrack({
    required this.id,
    this.title,
    this.language,
    this.channels,
    required this.type,
    this.isSelected = false,
    this.raw,
  });

  GoatTrack copyWith({
    String? id,
    String? title,
    String? language,
    String? channels,
    GoatTrackType? type,
    bool? isSelected,
    dynamic raw,
  }) {
    return GoatTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      language: language ?? this.language,
      channels: channels ?? this.channels,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
      raw: raw ?? this.raw,
    );
  }

  @override
  String toString() => 'GoatTrack(id: $id, title: $title, lang: $language, type: $type, selected: $isSelected)';
}

/// Collection of tracks available in the current media stream
class GoatTracks {
  final List<GoatTrack> audio;
  final List<GoatTrack> subtitle;
  final List<GoatTrack> video;

  const GoatTracks({
    this.audio = const [],
    this.subtitle = const [],
    this.video = const [],
  });

  static const empty = GoatTracks();

  @override
  String toString() => 'GoatTracks(audio: ${audio.length}, subtitle: ${subtitle.length}, video: ${video.length})';
}

/// Snapshot of the active playback state
class GoatPlayerState {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool playing;
  final bool buffering;
  final bool completed;
  final double volume;
  final double rate;
  final GoatTracks tracks;
  final GoatTrack? activeAudioTrack;
  final GoatTrack? activeSubtitleTrack;
  final String? lastOpenedUrl;
  final bool isLive;

  const GoatPlayerState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.volume = 100.0,
    this.rate = 1.0,
    this.tracks = GoatTracks.empty,
    this.activeAudioTrack,
    this.activeSubtitleTrack,
    this.lastOpenedUrl,
    this.isLive = false,
  });

  GoatPlayerState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? playing,
    bool? buffering,
    bool? completed,
    double? volume,
    double? rate,
    GoatTracks? tracks,
    GoatTrack? activeAudioTrack,
    GoatTrack? activeSubtitleTrack,
    String? lastOpenedUrl,
    bool? isLive,
    bool clearLastOpenedUrl = false,
  }) {
    return GoatPlayerState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      completed: completed ?? this.completed,
      volume: volume ?? this.volume,
      rate: rate ?? this.rate,
      tracks: tracks ?? this.tracks,
      activeAudioTrack: activeAudioTrack ?? this.activeAudioTrack,
      activeSubtitleTrack: activeSubtitleTrack ?? this.activeSubtitleTrack,
      lastOpenedUrl: clearLastOpenedUrl ? null : (lastOpenedUrl ?? this.lastOpenedUrl),
      isLive: isLive ?? this.isLive,
    );
  }
}

/// Stream interface for reactive playback updates
abstract class GoatPlayerStream {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;
  Stream<double> get volume;
  Stream<double> get rate;
  Stream<String?> get error;
  Stream<GoatTracks> get tracks;
  Stream<String> get subtitleText;
}
