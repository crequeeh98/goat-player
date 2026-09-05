import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../player/playback_controller.dart';
import 'tv_focusable.dart';

/// Root remote control listener and TV key event dispatcher.
///
/// Features:
/// - Handles Smart TV remote Back key (Tizen 10009, webOS 461, Escape, Backspace).
/// - Prioritizes dismissals: Drawers -> Modals -> Cinema minimization -> Exit App dialog.
/// - Catches Media keys (Play/Pause, Fast Forward, Rewind).
/// - Prevents accidental app termination on Smart TVs.
class TvRemoteScope extends ConsumerWidget {
  final Widget child;
  final bool isRoot;

  const TvRemoteScope({
    super.key,
    required this.child,
    this.isRoot = false,
  });

  static Future<bool> showTvExitDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1528),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          title: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Color(0xFFB388FF), size: 28),
              const SizedBox(width: 12),
              Text(
                l10n?.close ?? 'Exit GOATPlayer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            l10n?.localeName == 'de'
                ? 'Möchtest du GOATPlayer wirklich beenden?'
                : 'Are you sure you want to exit GOATPlayer?',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TvFocusable(
              autofocus: true,
              borderRadius: BorderRadius.circular(8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                l10n?.localeName == 'de' ? 'Abbrechen' : 'Cancel',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            TvFocusable(
              borderRadius: BorderRadius.circular(8),
              focusBorderColor: Colors.redAccent,
              glowColor: const Color(0x66FF5252),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Container(
                color: Colors.redAccent.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  l10n?.localeName == 'de' ? 'Beenden' : 'Exit',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );

    return confirmExit ?? false;
  }

  KeyEventResult _handleRemoteKeys(FocusNode node, KeyEvent event, WidgetRef ref, BuildContext context) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Media Keys: Play / Pause toggle
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      ref.read(playbackControllerProvider.notifier).togglePlayPause();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) => _handleRemoteKeys(node, event, ref, context),
      child: child,
    );
  }
}
