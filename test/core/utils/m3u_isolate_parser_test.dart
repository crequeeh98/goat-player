import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/utils/m3u_isolate_parser.dart';

void main() {
  group('M3uIsolateParser', () {
    test('correctly parses standard M3U content with EXTINF attributes', () async {
      const sample = '''
#EXTM3U x-tvg-url="https://epg.example.com/epg.xml"
#EXTINF:-1 tvg-id="AlphaTV.gr@SD" tvg-name="Alpha TV" tvg-logo="https://example.com/alpha.png" group-title="General",Alpha TV (1080p)
https://alphatvlive.example.com/live/playlist.m3u8
#EXTINF:-1 tvg-id="Action24.gr@SD" tvg-logo="https://example.com/action.png" group-title="Movies",Action 24 [1080p]
http://actionlive.example.com/playlist.m3u8
''';

      final items = await M3uIsolateParser.parseContent(sample);

      expect(items.length, 2);

      expect(items[0].tvgId, 'AlphaTV.gr@SD');
      expect(items[0].tvgName, 'Alpha TV');
      expect(items[0].tvgLogo, 'https://example.com/alpha.png');
      expect(items[0].groupTitle, 'General');
      expect(items[0].title, 'Alpha TV (1080p)');
      expect(items[0].url, 'https://alphatvlive.example.com/live/playlist.m3u8');

      expect(items[1].tvgId, 'Action24.gr@SD');
      expect(items[1].groupTitle, 'Movies');
      expect(items[1].title, 'Action 24 [1080p]');
      expect(items[1].url, 'http://actionlive.example.com/playlist.m3u8');
    });

    test('handles missing group-title by defaulting to General', () async {
      const sample = '''
#EXTM3U
#EXTINF:-1,Test Channel
https://stream.example.com/live.m3u8
''';

      final items = await M3uIsolateParser.parseContent(sample);

      expect(items.length, 1);
      expect(items[0].title, 'Test Channel');
      expect(items[0].groupTitle, 'General');
      expect(items[0].url, 'https://stream.example.com/live.m3u8');
    });
  });
}
