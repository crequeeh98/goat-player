import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
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
  static final _programmeRegex = RegExp(r'<programme([^>]+)>([\s\S]*?)<\/programme>');
  static final _startAttrRegex = RegExp(r'start="([^"]+)"');
  static final _stopAttrRegex = RegExp(r'stop="([^"]+)"');
  static final _channelAttrRegex = RegExp(r'channel="([^"]+)"');
  static final _titleTagRegex = RegExp(r'<title[^>]*>([^<]+)<\/title>');
  static final _descTagRegex = RegExp(r'<desc[^>]*>([^<]+)<\/desc>');

  /// Liest eine XMLTV-Datei in 64KB-UTF8-Chunks, trennt an `</programme>`-Grenzen
  /// und verwirft bereits abgelaufene Sendungen (> 2h in der Vergangenheit) sofort im Isolate.
  static Future<List<EpgProgramsCompanion>> parseXmlTvFile(String filePath, int accountId) async {
    final file = File(filePath);
    if (!await file.exists()) return const [];

    final companions = <EpgProgramsCompanion>[];
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));
    var carry = '';
    const closeTag = '</programme>';

    await for (final chunk in file.openRead().transform(const Utf8Decoder(allowMalformed: true))) {
      final combined = carry.isEmpty ? chunk : (carry + chunk);
      final lastClose = combined.lastIndexOf(closeTag);
      if (lastClose == -1) {
        carry = combined;
        if (carry.length > 512 * 1024) {
          carry = '';
        }
        continue;
      }

      final completeEnd = lastClose + closeTag.length;
      final processable = combined.substring(0, completeEnd);
      carry = combined.substring(completeEnd);

      _extractProgrammesFromChunk(processable, accountId, cutoff, companions);
    }

    if (carry.isNotEmpty) {
      _extractProgrammesFromChunk(carry, accountId, cutoff, companions);
    }

    return companions;
  }

  static void _extractProgrammesFromChunk(
    String xmlChunk,
    int accountId,
    DateTime cutoff,
    List<EpgProgramsCompanion> out,
  ) {
    final matches = _programmeRegex.allMatches(xmlChunk);
    for (final match in matches) {
      final attrs = match.group(1) ?? '';
      final innerXml = match.group(2) ?? '';

      final channelId = _channelAttrRegex.firstMatch(attrs)?.group(1);
      final startStr = _startAttrRegex.firstMatch(attrs)?.group(1);
      final stopStr = _stopAttrRegex.firstMatch(attrs)?.group(1);
      if (channelId == null || startStr == null || stopStr == null) continue;

      final stopTime = parseXmltvDate(stopStr);
      if (stopTime == null || stopTime.isBefore(cutoff)) continue;

      final startTime = parseXmltvDate(startStr);
      if (startTime == null) continue;

      final rawTitle = _titleTagRegex.firstMatch(innerXml)?.group(1)?.trim() ?? 'No Title';
      final rawDesc = _descTagRegex.firstMatch(innerXml)?.group(1)?.trim();

      final title = TitleSanitizer.unescapeHtml(rawTitle).trim();
      final desc = rawDesc != null ? TitleSanitizer.unescapeHtml(rawDesc).trim() : null;

      out.add(
        EpgProgramsCompanion.insert(
          accountId: accountId,
          channelId: channelId,
          title: title.isEmpty ? 'No Title' : title,
          description: desc != null && desc.isNotEmpty ? Value(desc) : const Value.absent(),
          startTime: startTime,
          stopTime: stopTime,
        ),
      );
    }
  }

  static Future<List<EpgItem>> parse(String xmlContent) async {
    if (xmlContent.isEmpty) return [];
    return compute(_parseEpgSync, xmlContent);
  }

  static List<EpgItem> _parseEpgSync(String content) {
    if (content.isEmpty) return [];

    final items = <EpgItem>[];
    print('EPG Parser: Starting parse of content length ${content.length}');

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
