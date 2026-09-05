import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/core/utils/platform_utils.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../player/playback_controller.dart';
import '../../features/live_tv/live_tv_controller.dart';
import 'tv_focusable.dart';

/// Root remote control listener and TV key event dispatcher.
///
/// Features:
/// - Handles Smart TV remote Back key (Tizen 10009, webOS 461, Escape, Backspace).
/// - Prioritizes dismissals: Drawers -> Modals -> Cinema minimization -> Exit App dialog.
/// - Catches Media keys (Play/Pause, Fast Forward, Rewind).
/// - Prevents accidental app termination on Smart TVs and provides confirmation dialog.
class TvRemoteScope extends ConsumerStatefulWidget {
  final Widget child;
  final bool isRoot;
  final VoidCallback? onBackAtRoot;

  const TvRemoteScope({
    super.key,
    required this.child,
    this.isRoot = false,
    this.onBackAtRoot,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 125,
                  child: TvFocusable(
                    autofocus: true,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Center(
                      child: Text(
                        l10n?.localeName == 'de' ? 'Abbrechen' : 'Cancel',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 125,
                  child: TvFocusable(
                    borderRadius: BorderRadius.circular(8),
                    focusBorderColor: Colors.redAccent,
                    glowColor: const Color(0x33FF5252),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Center(
                      child: Text(
                        l10n?.localeName == 'de' ? 'Beenden' : 'Exit',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    return confirmExit ?? false;
  }

  @override
  ConsumerState<TvRemoteScope> createState() => _TvRemoteScopeState();
}

class _TvRemoteScopeState extends ConsumerState<TvRemoteScope> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    super.dispose();
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;

    final key = event.logicalKey;

    // Media Keys: Play / Pause toggle
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      ref.read(playbackControllerProvider.notifier).togglePlayPause();
      return true;
    }

    // Smart TV / Desktop Back key: Escape or Android/TV goBack
    if (widget.isRoot &&
        (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack)) {
      // 1. If any modal dialog or secondary route is open, let the navigator pop it
      final nav = Navigator.maybeOf(context);
      if (nav != null && nav.canPop()) {
        final activePlayback = ref.read(playbackControllerProvider);
        if (activePlayback?.streamType == StreamType.live || ref.read(selectedLiveStreamProvider) != null) {
          ref.read(isLiveFullWidthProvider.notifier).set(true);
        }
        nav.pop();
        return true;
      }

      // 2. If a root back callback is supplied (e.g. closing search or minimizing player)
      if (widget.onBackAtRoot != null) {
        widget.onBackAtRoot!();
        return true;
      }

      // 3. Root Level Exit Confirmation
      _promptExit();
      return true;
    }

    return false;
  }

  void _promptExit() async {
    final shouldExit = await TvRemoteScope.showTvExitDialog(context);
    if (shouldExit && mounted) {
      if (GoatPlatform.isDesktop) {
        exit(0);
      } else {
        SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
