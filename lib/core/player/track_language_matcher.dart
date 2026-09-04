import 'package:media_kit/media_kit.dart';

class TrackLanguageMatcher {
  static const Map<String, List<String>> _languageAliases = {
    'de': [
      'de', 'ger', 'deu', 'deutsch', 'german', 'allemand', 'tedesco', 
      'deutsche', 'ger-de', 'de-de'
    ],
    'en': [
      'en', 'eng', 'english', 'englisch', 'anglais', 'ingles', 'inglés', 
      'en-us', 'en-gb', 'orig', 'original'
    ],
    'es': [
      'es', 'spa', 'spanish', 'spanisch', 'espanol', 'español', 'castellano', 'es-es', 'es-la'
    ],
    'fr': [
      'fr', 'fre', 'fra', 'french', 'französisch', 'francais', 'français', 'fr-fr'
    ],
    'it': [
      'it', 'ita', 'italian', 'italienisch', 'italiano', 'it-it'
    ],
    'tr': [
      'tr', 'tur', 'turkish', 'türkisch', 'turkce', 'türkçe', 'tr-tr'
    ],
    'ru': [
      'ru', 'rus', 'russian', 'russisch', 'ru-ru'
    ],
    'ar': [
      'ar', 'ara', 'arabic', 'arabisch', 'ar-sa'
    ],
    'pt': [
      'pt', 'por', 'portuguese', 'portugiesisch', 'português', 'pt-br', 'pt-pt'
    ],
    'nl': [
      'nl', 'dut', 'nla', 'dutch', 'niederländisch', 'nederlands'
    ],
    'pl': [
      'pl', 'pol', 'polish', 'polnisch', 'polski'
    ],
  };

  /// Normalizes any language code or alias to its primary 2-letter key (e.g. 'deutsch' -> 'de')
  static String? normalizeLanguageCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final cleaned = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final entry in _languageAliases.entries) {
      if (entry.key == cleaned || entry.value.contains(cleaned)) {
        return entry.key;
      }
    }
    return cleaned.length <= 3 ? cleaned : null;
  }

  /// Checks whether a track (language code or title) matches the target language
  static bool matchesLanguage(String? trackLang, String? trackTitle, String targetLang) {
    final targetNormalized = normalizeLanguageCode(targetLang);
    if (targetNormalized == null || targetNormalized.isEmpty) return false;

    // Check language code first
    final langNormalized = normalizeLanguageCode(trackLang);
    if (langNormalized != null && langNormalized == targetNormalized) {
      return true;
    }

    // Check title if present
    if (trackTitle != null && trackTitle.trim().isNotEmpty) {
      final titleTokens = _tokenize(trackTitle);
      final aliases = _languageAliases[targetNormalized] ?? [targetNormalized];
      for (final alias in aliases) {
        if (titleTokens.contains(alias.toLowerCase())) {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if a title or string indicates forced subtitles
  static bool isForced(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('forced') || lower.contains('erzwungen');
  }

  /// Checks if a track title indicates a director commentary
  static bool isCommentary(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('commentary') || lower.contains('kommentar') || lower.contains('director');
  }

  /// Checks if audio title represents multichannel surround (5.1, 7.1, etc.)
  static bool isSurround(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('5.1') || lower.contains('7.1') || lower.contains('surround') || lower.contains('atmos');
  }

  /// Best-match selection for AudioTrack
  static AudioTrack? findBestAudioTrack(
    List<AudioTrack> tracks,
    String? preferredLanguage, {
    String? targetTitle,
  }) {
    if (tracks.isEmpty) return null;
    if (tracks.length == 1) return tracks.first;

    // 1. If an exact title match was remembered, check for it
    if (targetTitle != null && targetTitle.isNotEmpty) {
      for (final t in tracks) {
        if (t.title?.toLowerCase() == targetTitle.toLowerCase()) {
          return t;
        }
      }
    }

    if (preferredLanguage == null || preferredLanguage.isEmpty || preferredLanguage == 'default') {
      return null; // Keep player default
    }

    final matching = tracks.where((t) {
      if (isCommentary(t.title)) return false;
      return matchesLanguage(t.language, t.title, preferredLanguage);
    }).toList();

    if (matching.isEmpty) return null;
    if (matching.length == 1) return matching.first;

    // Prefer surround sound (5.1) over stereo
    final surroundTrack = matching.firstWhere(
      (t) => isSurround(t.title) || (t.channels != null && (int.tryParse(t.channels.toString()) ?? 0) > 2),
      orElse: () => matching.first,
    );
    return surroundTrack;
  }

  /// Best-match selection for SubtitleTrack
  static SubtitleTrack? findBestSubtitleTrack(
    List<SubtitleTrack> tracks,
    String? preferredLanguage, {
    bool isAudioSameLanguage = false,
    String? targetTitle,
  }) {
    if (tracks.isEmpty) return null;

    if (preferredLanguage == null || preferredLanguage.toLowerCase() == 'off' || preferredLanguage.toLowerCase() == 'no') {
      return tracks.firstWhere((t) => t.id == 'no', orElse: () => SubtitleTrack.no());
    }

    if (preferredLanguage.toLowerCase() == 'auto') {
      return tracks.firstWhere((t) => t.id == 'auto', orElse: () => SubtitleTrack.auto());
    }

    // 1. If an exact title match was remembered
    if (targetTitle != null && targetTitle.isNotEmpty) {
      for (final t in tracks) {
        if (t.title?.toLowerCase() == targetTitle.toLowerCase()) {
          return t;
        }
      }
    }

    final matching = tracks.where((t) {
      if (t.id == 'no' || t.id == 'auto') return false;
      return matchesLanguage(t.language, t.title, preferredLanguage);
    }).toList();

    if (matching.isEmpty) return null;

    // If current audio is in the same language as user preferred language (e.g. Audio is German):
    // Prioritize forced subtitles if available, otherwise select the full matching subtitles
    if (isAudioSameLanguage) {
      final forced = matching.where((t) => isForced(t.title)).toList();
      if (forced.isNotEmpty) return forced.first;
    }

    // Otherwise, prefer non-forced full subtitles
    final regular = matching.where((t) => !isForced(t.title)).toList();
    if (regular.isNotEmpty) return regular.first;

    return matching.first;
  }

  static Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9äöüÄÖÜßáéíóúÁÉÍÓÚ]'))
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}
