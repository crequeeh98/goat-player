class ChannelNameCleaner {
  static final RegExp _prefixRegex = RegExp(
    r'^(?:\[.*?\]|\{.*?\}|\(.*?\)|\|.*?\||[A-Z0-9]{2,4}:)\s*-?\s*',
    caseSensitive: false,
  );

  static String clean(String originalName) {
    String cleaned = originalName.trim();
    // Keep removing prefixes if there are multiple e.g. "|UK| EN:"
    while (_prefixRegex.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(_prefixRegex, '').trim();
    }
    return cleaned.isNotEmpty ? cleaned : originalName;
  }
}
