import '../database/app_database.dart';

class LiveStreamMatcher {
  /// Finds the index of the currently active stream within [streams] with strict priority:
  /// 1. Exact match on unique [streamId]
  /// 2. Match [channelId] against [stream.streamId] (if channelId held a streamId)
  /// 3. Match via [streamUrl] containing '/{streamId}.ts'
  /// 4. Strict fallback: Match on [stream.epgChannelId] == [channelId] ONLY when no streamId matched
  static int indexOf(
    List<StreamItem> streams, {
    String? streamId,
    String? channelId,
    String? streamUrl,
  }) {
    if (streams.isEmpty) return -1;

    // 1. Resolve streamId from streamUrl if not explicitly passed
    String? resolvedStreamId = streamId;
    if ((resolvedStreamId == null || resolvedStreamId.isEmpty) && streamUrl != null) {
      final match = RegExp(r'/live/[^/]+/[^/]+/(\d+)\.(?:ts|m3u8)').firstMatch(streamUrl);
      if (match != null) {
        resolvedStreamId = match.group(1);
      }
    }

    // Priority 1: Exact match on unique streamId
    if (resolvedStreamId != null && resolvedStreamId.isNotEmpty) {
      final idx = streams.indexWhere((s) => s.streamId == resolvedStreamId);
      if (idx != -1) return idx;
    }

    // Priority 2: channelId matches streamId (some callers supply streamId as channelId)
    if (channelId != null && channelId.isNotEmpty) {
      final idx = streams.indexWhere((s) => s.streamId == channelId);
      if (idx != -1) return idx;
    }

    // Priority 3: Match via streamUrl containing the streamId
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final idx = streams.indexWhere((s) =>
          streamUrl.contains('/${s.streamId}.ts') || streamUrl.contains('/${s.streamId}.m3u8'));
      if (idx != -1) return idx;
    }

    // Priority 4 (Strict Fallback): Match on epgChannelId ONLY if no streamId match was found
    if (channelId != null && channelId.isNotEmpty) {
      final idx = streams.indexWhere(
        (s) => s.epgChannelId != null && s.epgChannelId!.isNotEmpty && s.epgChannelId == channelId,
      );
      if (idx != -1) return idx;
    }

    return -1;
  }
}
