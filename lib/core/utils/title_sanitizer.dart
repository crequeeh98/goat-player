class TitleSanitizer {
  static String sanitize(String rawTitle) {
    String title = rawTitle;

    // Remove tags like [DE], (2024), {Action}
    title = title.replaceAll(RegExp(r'\[.*?\]'), '');
    title = title.replaceAll(RegExp(r'\{.*?\}'), '');
    
    // Remove resolution/quality artifacts
    final artifacts = [
      '1080p', '720p', '4k', '2160p', 'fhd', 'hd', 'uhd',
      'x264', 'h264', 'x265', 'h265', 'hevc', 'bluray',
      'webrip', 'webdl', 'web-dl', 'brrip', 'bdrip',
    ];

    for (var artifact in artifacts) {
      // Case insensitive whole word match
      title = title.replaceAll(RegExp(r'\b' + artifact + r'\b', caseSensitive: false), '');
    }

    // Extract year if present (e.g., Movie Name 2024) to a separate logic, 
    // but for TMDB search, removing it or keeping it separate is good.
    // Let's remove years in parentheses first, then trailing 4-digit years.
    title = title.replaceAll(RegExp(r'\(\d{4}\)'), '');
    
    // Remove trailing years like " 2024" or " 1999"
    title = title.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '');

    // Cleanup extra spaces and special chars used as separators
    title = title.replaceAll(RegExp(r'[\.\-\_]'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    return title;
  }

  static String sanitizeLiveTvChannel(String rawTitle) {
    String title = rawTitle;
    
    // Remove common IPTV country prefixes like "DE:", "|DE|", "[US]", "UK - "
    // Also covers spaces like "DE : " or "UK- "
    title = title.replaceAll(RegExp(r'^\[[A-Z]{2,4}\]\s*|^\|[A-Z]{2,4}\|\s*|^[A-Z]{2,4}\s*[:-]\s*', caseSensitive: false), '');
    
    // Remove trailing country tags or artifacts if needed
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return title;
  }
}
