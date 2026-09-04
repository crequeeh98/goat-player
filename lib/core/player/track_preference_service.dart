import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings/locale_controller.dart';

final trackPreferenceServiceProvider = Provider<TrackPreferenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TrackPreferenceService(prefs);
});

class TrackPreferenceService {
  final SharedPreferences _prefs;

  TrackPreferenceService(this._prefs);

  static const String _keyGlobalAudio = 'pref_global_audio_lang';
  static const String _keyGlobalSubtitle = 'pref_global_subtitle_lang';

  /// Returns global preferred audio language (default 'de')
  String getPreferredAudioLanguage() {
    return _prefs.getString(_keyGlobalAudio) ?? 'de';
  }

  Future<void> setPreferredAudioLanguage(String lang) async {
    await _prefs.setString(_keyGlobalAudio, lang);
  }

  /// Returns global preferred subtitle language (default 'off')
  String getPreferredSubtitleLanguage() {
    return _prefs.getString(_keyGlobalSubtitle) ?? 'off';
  }

  Future<void> setPreferredSubtitleLanguage(String lang) async {
    await _prefs.setString(_keyGlobalSubtitle, lang);
  }

  /// Returns remembered audio choice (title or language) for a specific series or movie
  String? getMediaAudioChoice(String mediaId) {
    return _prefs.getString('media_audio_$mediaId');
  }

  Future<void> setMediaAudioChoice(String mediaId, String choice) async {
    await _prefs.setString('media_audio_$mediaId', choice);
  }

  /// Returns remembered subtitle choice for a specific series or movie
  String? getMediaSubtitleChoice(String mediaId) {
    return _prefs.getString('media_sub_$mediaId');
  }

  Future<void> setMediaSubtitleChoice(String mediaId, String choice) async {
    await _prefs.setString('media_sub_$mediaId', choice);
  }
}
