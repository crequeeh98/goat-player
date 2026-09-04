import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:goat_player/core/player/track_language_matcher.dart';

void main() {
  group('TrackLanguageMatcher', () {
    test('normalizes German and English language variations', () {
      expect(TrackLanguageMatcher.normalizeLanguageCode('de'), 'de');
      expect(TrackLanguageMatcher.normalizeLanguageCode('ger'), 'de');
      expect(TrackLanguageMatcher.normalizeLanguageCode('deu'), 'de');
      expect(TrackLanguageMatcher.normalizeLanguageCode('deutsch'), 'de');
      expect(TrackLanguageMatcher.normalizeLanguageCode('German'), 'de');

      expect(TrackLanguageMatcher.normalizeLanguageCode('en'), 'en');
      expect(TrackLanguageMatcher.normalizeLanguageCode('eng'), 'en');
      expect(TrackLanguageMatcher.normalizeLanguageCode('english'), 'en');
      expect(TrackLanguageMatcher.normalizeLanguageCode('Englisch'), 'en');
    });

    test('matches language from track language code or title tokens', () {
      expect(TrackLanguageMatcher.matchesLanguage('ger', 'Stereo', 'de'), isTrue);
      expect(TrackLanguageMatcher.matchesLanguage(null, 'German (AC3 5.1)', 'de'), isTrue);
      expect(TrackLanguageMatcher.matchesLanguage(null, 'Deutsch Dolby Surround', 'de'), isTrue);
      expect(TrackLanguageMatcher.matchesLanguage('deu', null, 'de'), isTrue);
      expect(TrackLanguageMatcher.matchesLanguage('eng', 'English [Original]', 'en'), isTrue);
      expect(TrackLanguageMatcher.matchesLanguage('fra', 'French', 'de'), isFalse);
    });

    test('detects forced, commentary, and surround audio tags', () {
      expect(TrackLanguageMatcher.isForced('German [Forced]'), isTrue);
      expect(TrackLanguageMatcher.isForced('Deutsch erzwungen'), isTrue);
      expect(TrackLanguageMatcher.isForced('German Full'), isFalse);

      expect(TrackLanguageMatcher.isCommentary('Director Commentary'), isTrue);
      expect(TrackLanguageMatcher.isCommentary('Audiokommentar'), isTrue);
      expect(TrackLanguageMatcher.isCommentary('German AC3'), isFalse);

      expect(TrackLanguageMatcher.isSurround('German Dolby Digital 5.1'), isTrue);
      expect(TrackLanguageMatcher.isSurround('English 7.1 Atmos'), isTrue);
      expect(TrackLanguageMatcher.isSurround('Stereo'), isFalse);
    });

    test('selects surround German audio over stereo German audio', () {
      final stereo = AudioTrack('1', 'German Stereo', 'de');
      final surround = AudioTrack('2', 'German AC3 5.1', 'ger');
      final english = AudioTrack('3', 'English 5.1', 'eng');

      final best = TrackLanguageMatcher.findBestAudioTrack([stereo, surround, english], 'de');
      expect(best?.id, '2');
    });

    test('selects forced German subtitle when audio is German', () {
      final germanFull = SubtitleTrack('1', 'German Full', 'de');
      final germanForced = SubtitleTrack('2', 'German [Forced]', 'ger');
      final englishFull = SubtitleTrack('3', 'English', 'eng');

      final best = TrackLanguageMatcher.findBestSubtitleTrack(
        [germanFull, germanForced, englishFull],
        'de',
        isAudioSameLanguage: true,
      );
      expect(best?.id, '2');
    });

    test('selects full German subtitle when audio is English', () {
      final germanFull = SubtitleTrack('1', 'German Full', 'de');
      final germanForced = SubtitleTrack('2', 'German [Forced]', 'ger');

      final best = TrackLanguageMatcher.findBestSubtitleTrack(
        [germanFull, germanForced],
        'de',
        isAudioSameLanguage: false,
      );
      expect(best?.id, '1');
    });

    test('selects full German subtitle when audio is German and no forced track exists', () {
      final germanFull = SubtitleTrack('1', 'German Full', 'de');
      final englishFull = SubtitleTrack('2', 'English', 'eng');

      final best = TrackLanguageMatcher.findBestSubtitleTrack(
        [germanFull, englishFull],
        'de',
        isAudioSameLanguage: true,
      );
      expect(best?.id, '1');
    });
  });
}
