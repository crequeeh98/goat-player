import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/core/player/track_preference_service.dart';
import 'package:goat_player/core/utils/platform_utils.dart';
import 'package:goat_player/core/widgets/tv_focusable.dart';
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

  Widget _buildTvGrid({
    required List<String> codes,
    required String selectedCode,
    required AppLocalizations? l10n,
    required ValueChanged<String> onSelect,
    bool autofocusSelected = false,
  }) {
    final rows = <Widget>[];
    for (int i = 0; i < codes.length; i += 3) {
      final rowItems = <Widget>[];
      for (int j = 0; j < 3; j++) {
        if (i + j < codes.length) {
          final code = codes[i + j];
          final isSelected = code == selectedCode;
          rowItems.add(
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: j == 0 ? 0 : 8),
                child: TvFocusable(
                  autofocus: autofocusSelected && isSelected,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => onSelect(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                          : const Color(0xFF161124),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFB388FF) : Colors.white12,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_circle, size: 15, color: Color(0xFFB388FF)),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            _getLanguageLabel(code, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          rowItems.add(const Expanded(child: SizedBox()));
        }
      }
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(Row(children: rowItems));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (GoatPlatform.isTv) {
      final activeAudio = _audioCodes.contains(_preferredAudio) ? _preferredAudio : 'de';
      final activeSub = _subtitleCodes.contains(_preferredSubtitle) ? _preferredSubtitle : 'off';

      return Dialog(
        backgroundColor: const Color(0xFF1E1730),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.tune, size: 22, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n?.playbackPreferences ?? 'Playback Settings',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🔊 ${l10n?.preferredAudioLanguage ?? 'Preferred Audio Language'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  _buildTvGrid(
                    codes: _audioCodes,
                    selectedCode: activeAudio,
                    l10n: l10n,
                    autofocusSelected: true,
                    onSelect: (val) {
                      setState(() => _preferredAudio = val);
                      ref.read(trackPreferenceServiceProvider).setPreferredAudioLanguage(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '💬 ${l10n?.preferredSubtitleLanguage ?? 'Preferred Subtitles'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  _buildTvGrid(
                    codes: _subtitleCodes,
                    selectedCode: activeSub,
                    l10n: l10n,
                    onSelect: (val) {
                      setState(() => _preferredSubtitle = val);
                      ref.read(trackPreferenceServiceProvider).setPreferredSubtitleLanguage(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.playbackPreferencesHint ??
                        'Automatically applied to movies and series when available. Manual track adjustments during playback are remembered per title.',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white54, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TvFocusable(
                      borderRadius: BorderRadius.circular(10),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '✓ ${l10n?.done ?? 'OK'}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n?.playbackPreferences ?? 'Playback Settings',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              softWrap: true,
            ),
          ),
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
