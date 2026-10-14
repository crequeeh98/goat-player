import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/utils/channel_name_cleaner.dart';
import 'package:goat_player/core/utils/title_sanitizer.dart';

void main() {
  group('ChannelNameCleaner & TitleSanitizer', () {
    test('cleans single bracketed prefix', () {
      expect(ChannelNameCleaner.clean('[DE] Sky Cinema Action'), 'Sky Cinema Action');
      expect(TitleSanitizer.sanitizeLiveTvChannel('[DE] Sky Cinema Action'), 'Sky Cinema Action');
    });

    test('cleans multiple chained prefixes and pipe tags', () {
      expect(ChannelNameCleaner.clean('|UK| EN: BBC One HD'), 'BBC One HD');
      expect(TitleSanitizer.sanitizeLiveTvChannel('|UK| EN: BBC One HD'), 'BBC One HD');
    });

    test('cleans colon and hyphen prefixes', () {
      expect(ChannelNameCleaner.clean('DE: Das Erste HD'), 'Das Erste HD');
      expect(ChannelNameCleaner.clean('UK - ITV 1'), 'ITV 1');
    });

    test('returns untouched name when already clean', () {
      expect(ChannelNameCleaner.clean('ZDF HD'), 'ZDF HD');
      expect(ChannelNameCleaner.clean('Discovery Channel'), 'Discovery Channel');
    });

    test('serves repeated lookups from cache', () {
      final first = ChannelNameCleaner.clean('[US] CNN News');
      final second = ChannelNameCleaner.clean('[US] CNN News');
      expect(first, 'CNN News');
      expect(identical(first, second), isTrue);
    });
  });
}
