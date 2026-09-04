import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player_service.dart';

enum StreamType {
  live,
  movie,
  series,
}

class ActivePlayback {
  final String title;
  final String streamUrl;
  final StreamType streamType;
  final String? streamId;
  final String? seriesId;
  final String? coverUrl;
  final int? startPosition;
  final String? channelId;
  final String? categoryId;
  final bool isMinimized;
  final String? seriesName;
  final String? episodeTitle;
  final String? currentSeason;
  final String? episodeNum;
  final Map<String, List<dynamic>>? seasonsWithEpisodes;

  const ActivePlayback({
    required this.title,
    required this.streamUrl,
    required this.streamType,
    this.streamId,
    this.seriesId,
    this.coverUrl,
    this.startPosition,
    this.channelId,
    this.categoryId,
    this.isMinimized = false,
    this.seriesName,
    this.episodeTitle,
    this.currentSeason,
    this.episodeNum,
    this.seasonsWithEpisodes,
  });

  ActivePlayback copyWith({
    String? title,
    String? streamUrl,
    StreamType? streamType,
    String? streamId,
    String? seriesId,
    String? coverUrl,
    int? startPosition,
    String? channelId,
    String? categoryId,
    bool? isMinimized,
    String? seriesName,
    String? episodeTitle,
    String? currentSeason,
    String? episodeNum,
    Map<String, List<dynamic>>? seasonsWithEpisodes,
  }) {
    return ActivePlayback(
      title: title ?? this.title,
      streamUrl: streamUrl ?? this.streamUrl,
      streamType: streamType ?? this.streamType,
      streamId: streamId ?? this.streamId,
      seriesId: seriesId ?? this.seriesId,
      coverUrl: coverUrl ?? this.coverUrl,
      startPosition: startPosition ?? this.startPosition,
      channelId: channelId ?? this.channelId,
      categoryId: categoryId ?? this.categoryId,
      isMinimized: isMinimized ?? this.isMinimized,
      seriesName: seriesName ?? this.seriesName,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      currentSeason: currentSeason ?? this.currentSeason,
      episodeNum: episodeNum ?? this.episodeNum,
      seasonsWithEpisodes: seasonsWithEpisodes ?? this.seasonsWithEpisodes,
    );
  }
}

class PlaybackController extends Notifier<ActivePlayback?> {
  @override
  ActivePlayback? build() => null;

  Future<void> playLive({
    required String title,
    required String url,
    String? channelId,
    String? streamId,
    String? categoryId,
  }) async {
    final playerService = ref.read(playerServiceProvider);
    state = ActivePlayback(
      title: title,
      streamUrl: url,
      streamType: StreamType.live,
      channelId: channelId,
      streamId: streamId ?? channelId,
      categoryId: categoryId,
      isMinimized: false,
    );
    await playerService.stop();
    await playerService.open(url, isLive: true);
  }

  Future<void> playVod({
    required String title,
    required String url,
    required StreamType streamType,
    String? streamId,
    String? seriesId,
    String? coverUrl,
    int? startPosition,
    String? seriesName,
    String? episodeTitle,
    String? currentSeason,
    String? episodeNum,
    Map<String, List<dynamic>>? seasonsWithEpisodes,
  }) async {
    final playerService = ref.read(playerServiceProvider);
    state = ActivePlayback(
      title: title,
      streamUrl: url,
      streamType: streamType,
      streamId: streamId,
      seriesId: seriesId,
      coverUrl: coverUrl,
      startPosition: startPosition,
      isMinimized: false,
      seriesName: seriesName,
      episodeTitle: episodeTitle,
      currentSeason: currentSeason,
      episodeNum: episodeNum,
      seasonsWithEpisodes: seasonsWithEpisodes,
    );
    await playerService.stop();
    final startDuration = (startPosition != null && startPosition > 0)
        ? Duration(seconds: startPosition)
        : null;
    await playerService.open(url, isLive: false, startPosition: startDuration);
  }

  void minimize() {
    if (state != null) {
      state = state!.copyWith(isMinimized: true);
    }
  }

  void expand() {
    if (state != null) {
      state = state!.copyWith(isMinimized: false);
    }
  }

  Future<void> togglePlayPause() async {
    final playerService = ref.read(playerServiceProvider);
    await playerService.player.playOrPause();
  }

  Future<void> stop() async {
    final playerService = ref.read(playerServiceProvider);
    await playerService.stop();
    state = null;
  }
}

final playbackControllerProvider = NotifierProvider<PlaybackController, ActivePlayback?>(
  PlaybackController.new,
);
