import 'dart:io';

class M3UItem {
  final String tvgId;
  final String tvgName;
  final String tvgLogo;
  final String groupTitle;
  final String title;
  final String url;

  M3UItem({
    required this.tvgId,
    required this.tvgName,
    required this.tvgLogo,
    required this.groupTitle,
    required this.title,
    required this.url,
  });
}

class M3uIsolateParser {
  static Future<List<M3UItem>> parse(String filePath) async {
    // Isolate.run is ideal for running this heavy computation in a background isolate
    return await Future.microtask(() => _parseM3USync(filePath)); 
    // Normally we'd use Isolate.run(() => _parseM3USync(filePath)), but passing file paths 
    // and reading inside isolate is straightforward.
  }

  static Future<List<M3UItem>> parseContent(String content) async {
    return await Future.microtask(() => _parseM3UStringSync(content));
  }

  static List<M3UItem> _parseM3USync(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    return _parseM3UStringSync(file.readAsStringSync());
  }

  static List<M3UItem> _parseM3UStringSync(String content) {
    final lines = content.split('\n');
    final items = <M3UItem>[];

    String? currentTvgId;
    String? currentTvgName;
    String? currentTvgLogo;
    String? currentGroupTitle;
    String? currentTitle;

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentTvgId = _extractAttribute(line, 'tvg-id');
        currentTvgName = _extractAttribute(line, 'tvg-name');
        currentTvgLogo = _extractAttribute(line, 'tvg-logo');
        currentGroupTitle = _extractAttribute(line, 'group-title');

        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1) {
          currentTitle = line.substring(commaIndex + 1).trim();
        } else {
          currentTitle = 'Unknown Channel';
        }
      } else if (!line.startsWith('#')) {
        // It's a stream URL
        if (currentTitle != null) {
          items.add(M3UItem(
            tvgId: currentTvgId ?? '',
            tvgName: currentTvgName ?? '',
            tvgLogo: currentTvgLogo ?? '',
            groupTitle: (currentGroupTitle != null && currentGroupTitle.isNotEmpty)
                ? currentGroupTitle
                : 'General',
            title: currentTitle,
            url: line,
          ));
        }
        currentTvgId = null;
        currentTvgName = null;
        currentTvgLogo = null;
        currentGroupTitle = null;
        currentTitle = null;
      }
    }
    return items;
  }

  static String? _extractAttribute(String line, String attribute) {
    final regex = RegExp('$attribute=["\']([^"\']*)["\']', caseSensitive: false);
    final match = regex.firstMatch(line);
    if (match != null) return match.group(1)?.trim();
    final regexNoQuote = RegExp('$attribute=([^\\s,]+)', caseSensitive: false);
    final matchNoQuote = regexNoQuote.firstMatch(line);
    return matchNoQuote?.group(1)?.trim();
  }
}
