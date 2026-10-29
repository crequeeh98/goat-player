

import 'package:flutter/foundation.dart';
import 'title_sanitizer.dart';

class EpgItem {
  final String channelId;
  final String title;
  final String? description;
  final String start;
  final String stop;

  EpgItem({
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.stop,
  });
}

class EpgIsolateParser {
  static Future<List<EpgItem>> parse(String xmlContent) async {
    if (xmlContent.isEmpty) return [];
    return compute(_parseEpgSync, xmlContent);
  }

  static List<EpgItem> _parseEpgSync(String content) {
    if (content.isEmpty) return [];

    final items = <EpgItem>[];
    print('EPG Parser: Starting parse of content length ${content.length}');

    // Using a regex-based approach for performance on massive files.
    // In a real production scenario, an event-based XML parser might be preferred.
    final programRegex = RegExp(r'<programme([^>]+)>([\s\S]*?)<\/programme>');
    final startRegex = RegExp(r'start="([^"]+)"');
    final stopRegex = RegExp(r'stop="([^"]+)"');
    final channelRegex = RegExp(r'channel="([^"]+)"');
    final titleRegex = RegExp(r'<title[^>]*>([^<]+)<\/title>');
    final descRegex = RegExp(r'<desc[^>]*>([^<]+)<\/desc>');

    for (final match in programRegex.allMatches(content)) {
      final attrs = match.group(1) ?? '';
      final innerContent = match.group(2) ?? '';

      final start = startRegex.firstMatch(attrs)?.group(1) ?? '';
      final stop = stopRegex.firstMatch(attrs)?.group(1) ?? '';
      final channelId = channelRegex.firstMatch(attrs)?.group(1) ?? '';

      final titleMatch = titleRegex.firstMatch(innerContent);
      final descMatch = descRegex.firstMatch(innerContent);

      final rawTitle = titleMatch?.group(1) ?? 'Unknown';
      final rawDesc = descMatch?.group(1);

      items.add(EpgItem(
        channelId: channelId,
        title: TitleSanitizer.unescapeHtml(rawTitle),
        description: rawDesc != null ? TitleSanitizer.unescapeHtml(rawDesc) : null,
        start: start,
        stop: stop,
      ));
    }
    
    print('EPG Parser: Found ${items.length} programme elements');

    return items;
  }

  static DateTime? parseXmltvDate(String dateString) {
    if (dateString.length < 14) return null;
    try {
      final year = dateString.substring(0, 4);
      final month = dateString.substring(4, 6);
      final day = dateString.substring(6, 8);
      final hour = dateString.substring(8, 10);
      final minute = dateString.substring(10, 12);
      final second = dateString.substring(12, 14);
      
      String isoString = '$year-$month-${day}T$hour:$minute:$second';
      
      if (dateString.length >= 19) {
        final tzPart = dateString.substring(14).trim();
        if (tzPart.length == 5 && (tzPart.startsWith('+') || tzPart.startsWith('-'))) {
          final tzHour = tzPart.substring(1, 3);
          final tzMin = tzPart.substring(3, 5);
          isoString += '${tzPart[0]}$tzHour:$tzMin';
        } else if (tzPart == 'Z') {
          isoString += 'Z';
        } else {
          isoString += 'Z';
        }
      } else {
        isoString += 'Z';
      }
      
      return DateTime.parse(isoString).toLocal();
    } catch (e) {
      return null;
    }
  }
}
