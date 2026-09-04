import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/utils/vod_title_cleaner.dart';

void main() {
  group('VodTitleCleaner', () {
    test('does not duplicate series name when epTitle already contains full series name', () {
      final res = VodTitleCleaner.formatDisplayTitle(
        seriesName: 'A+ Ted Lasso (US)',
        season: '3',
        epNum: '2',
        epTitle: '4K-A+ - Ted Lasso (US) - S03E02 - (I Don\'t Want to Go to) Chelsea',
      );
      expect(res, '4K-A+ - Ted Lasso (US) - S03E02 - (I Don\'t Want to Go to) Chelsea');
    });

    test('prepends series name when epTitle only has season and episode tag', () {
      final res = VodTitleCleaner.formatDisplayTitle(
        seriesName: 'Ted Lasso',
        season: '3',
        epNum: '2',
        epTitle: 'S03E02 - (I Don\'t Want to Go to) Chelsea',
      );
      expect(res, 'Ted Lasso - S03E02 - (I Don\'t Want to Go to) Chelsea');
    });

    test('prepends series name and season/ep tags when epTitle is plain episode title', () {
      final res = VodTitleCleaner.formatDisplayTitle(
        seriesName: 'Ted Lasso',
        season: '3',
        epNum: '2',
        epTitle: '(I Don\'t Want to Go to) Chelsea',
      );
      expect(res, 'Ted Lasso - S03E02 - (I Don\'t Want to Go to) Chelsea');
    });

    test('strips duplicated prefix from malformed title', () {
      final res = VodTitleCleaner.cleanDuplicatePrefix(
        'A+ Ted Lasso (US) - 4K-A+ - Ted Lasso (US) - S03E02 - Chelsea',
      );
      expect(res, '4K-A+ - Ted Lasso (US) - S03E02 - Chelsea');
    });
  });
}
