class VodTitleCleaner {
  static const Set<String> _ignoreTokens = {
    '4k', 'uhd', 'fhd', 'hd', 'sd', '1080p', '720p', '2160p', 'hevc', 'x265', 'h264',
    'de', 'en', 'us', 'uk', 'fr', 'es', 'it', 'tr', 'ru', 'ar', 'a+', 'd+', 'atv',
    'series', 'staffel', 'season',
  };

  /// Cleans duplicate prefixes such as "X - X - ..." or "X - 4K-X - ..."
  static String cleanDuplicatePrefix(String text) {
    var t = text.trim();
    final separatorIdx = t.indexOf(' - ');
    if (separatorIdx != -1) {
      final firstPart = t.substring(0, separatorIdx).trim().toLowerCase();
      final remainder = t.substring(separatorIdx + 3).trim();
      final remainderLower = remainder.toLowerCase();

      // If remainder starts with firstPart
      if (remainderLower.startsWith(firstPart)) {
        return remainder;
      }

      // If remainder contains the core words of firstPart right at the beginning
      final firstWords = firstPart
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3 && !_ignoreTokens.contains(w))
          .toList();
      if (firstWords.isNotEmpty) {
        final remainderStart = remainderLower.length > 50 ? remainderLower.substring(0, 50) : remainderLower;
        if (firstWords.every((w) => remainderStart.contains(w))) {
          return remainder;
        }
      }
    }
    return t;
  }

  /// Builds a clean display title combining seriesName and epTitle without duplicates
  static String formatDisplayTitle({
    required String seriesName,
    required String season,
    required String epNum,
    required String epTitle,
  }) {
    var title = cleanDuplicatePrefix(epTitle.trim());
    if (title.isEmpty) {
      final s = season.padLeft(2, '0');
      final e = epNum.padLeft(2, '0');
      return seriesName.isNotEmpty ? '$seriesName - S${s}E$e' : 'S${s}E$e';
    }

    // Extract significant core words from seriesName (ignoring tags like 4k, uhd, fhd, de, a+, etc.)
    final seriesWords = seriesName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_ignoreTokens.contains(w))
        .toList();

    final titleLower = title.toLowerCase();

    // Check if title already contains significant words of the series name
    bool alreadyHasSeriesName = false;
    if (seriesWords.isNotEmpty) {
      final matchCount = seriesWords.where((w) => titleLower.contains(w)).length;
      if (matchCount >= (seriesWords.length >= 2 ? 2 : 1)) {
        alreadyHasSeriesName = true;
      }
    } else if (seriesName.isNotEmpty && titleLower.contains(seriesName.toLowerCase())) {
      alreadyHasSeriesName = true;
    }

    if (alreadyHasSeriesName) {
      return title;
    }

    final hasSeasonEpTag = RegExp(r'S\d+.*E\d+', caseSensitive: false).hasMatch(title);
    if (hasSeasonEpTag) {
      return seriesName.isNotEmpty ? '$seriesName - $title' : title;
    }

    final s = season.padLeft(2, '0');
    final e = epNum.padLeft(2, '0');
    return seriesName.isNotEmpty ? '$seriesName - S${s}E$e - $title' : 'S${s}E$e - $title';
  }
}
