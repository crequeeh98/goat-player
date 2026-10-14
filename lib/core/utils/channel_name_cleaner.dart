class ChannelNameCleaner {
  static final RegExp _prefixRegex = RegExp(
    r'^(?:\[.*?\]|\{.*?\}|\(.*?\)|\|.*?\||[A-Z0-9]{2,4}\s*[:-]\s*)\s*-?\s*',
    caseSensitive: false,
  );

  static final Map<String, String> _cache = {};
  static const int _maxCacheSize = 2000;

  static String clean(String originalName) {
    if (originalName.isEmpty) return originalName;

    final cached = _cache[originalName];
    if (cached != null) return cached;

    final trimmed = originalName.trim();
    if (trimmed.isEmpty) return originalName;

    // Fast-path check: avoid regex overhead if string has no prefix indicators
    final firstChar = trimmed.codeUnitAt(0);
    final hasOpeningMarker = firstChar == 91 || // [
                             firstChar == 123 || // {
                             firstChar == 40 ||  // (
                             firstChar == 124;   // |

    bool mightHavePrefix = hasOpeningMarker;
    if (!mightHavePrefix) {
      final checkLen = trimmed.length < 8 ? trimmed.length : 8;
      for (int i = 0; i < checkLen; i++) {
        final c = trimmed.codeUnitAt(i);
        if (c == 58 || c == 45) { // ':' or '-'
          mightHavePrefix = true;
          break;
        }
      }
    }

    String result = trimmed;
    if (mightHavePrefix) {
      while (_prefixRegex.hasMatch(result)) {
        result = result.replaceFirst(_prefixRegex, '').trim();
      }
      if (result.isEmpty) {
        result = originalName;
      }
    }

    if (_cache.length >= _maxCacheSize) {
      _cache.clear();
    }
    _cache[originalName] = result;
    return result;
  }
}
