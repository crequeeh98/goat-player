import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/core/player/track_preference_service.dart';
import 'package:goat_player/l10n/app_localizations.dart';

class PlaybackSettingsDialog extends ConsumerStatefulWidget {
  const PlaybackSettingsDialog({super.key});

  @override
  ConsumerState<PlaybackSettingsDialog> createState() => _PlaybackSettingsDialogState();
}

class _PlaybackSettingsDialogState extends ConsumerState<PlaybackSettingsDialog> {
  late String _preferredAudio;
  late String _preferredSubtitle;

  static const List<String> _audioCodes = [
    'de', 'en', 'fr', 'es', 'it', 'tr', 'ru', 'ar', 'default',
  ];

  static const List<String> _subtitleCodes = [
    'off', 'de', 'en', 'fr', 'es', 'it', 'tr', 'ru', 'ar',
  ];

  String _getLanguageLabel(String code, AppLocalizations? l10n) {
    switch (code) {
      case 'de':
        return l10n?.langGerman ?? 'Deutsch';
      case 'en':
        return l10n?.langEnglish ?? 'English';
      case 'fr':
        return l10n?.langFrench ?? 'Français';
      case 'es':
        return l10n?.langSpanish ?? 'Español';
      case 'it':
        return l10n?.langItalian ?? 'Italiano';
      case 'tr':
        return l10n?.langTurkish ?? 'Türkçe';
      case 'ru':
        return l10n?.langRussian ?? 'Русский';
      case 'ar':
        return l10n?.langArabic ?? 'العربية';
      case 'default':
        return l10n?.langDefault ?? 'Original / Default';
      case 'off':
        return l10n?.subtitlesOff ?? 'Off';
      default:
        return code.toUpperCase();
    }
  }

  @override
  void initState() {
    super.initState();
    final prefService = ref.read(trackPreferenceServiceProvider);
    _preferredAudio = prefService.getPreferredAudioLanguage();
    _preferredSubtitle = prefService.getPreferredSubtitleLanguage();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.tune, size: 22),
          const SizedBox(width: 10),
          Text(l10n?.playbackPreferences ?? 'Playback Preferences'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio preference
            Text(
              l10n?.preferredAudioLanguage ?? 'Preferred Audio Language',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _audioCodes.contains(_preferredAudio) ? _preferredAudio : 'de',
                  items: _audioCodes.map((code) {
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(_getLanguageLabel(code, l10n)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _preferredAudio = val);
                      ref.read(trackPreferenceServiceProvider).setPreferredAudioLanguage(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Subtitle preference
            Text(
              l10n?.preferredSubtitleLanguage ?? 'Preferred Subtitles',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _subtitleCodes.contains(_preferredSubtitle) ? _preferredSubtitle : 'off',
                  items: _subtitleCodes.map((code) {
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(_getLanguageLabel(code, l10n)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _preferredSubtitle = val);
                      ref.read(trackPreferenceServiceProvider).setPreferredSubtitleLanguage(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n?.playbackPreferencesHint ??
                  'Automatically applied to movies and series when available. Manual track adjustments during playback are remembered per title.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
