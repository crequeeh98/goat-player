import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/core/utils/platform_utils.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../player/playback_controller.dart';
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

  static bool _isExitDialogOpen = false;

  static Future<bool> showTvExitDialog(BuildContext context) async {
    if (_isExitDialogOpen) return false;
    _isExitDialogOpen = true;
    try {
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
                Expanded(
                  child: Text(
                    l10n?.exitApp ?? 'Exit GOATPlayer',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              l10n?.localeName == 'de'
                  ? 'Möchtest du GOATPlayer wirklich beenden?'
                  : 'Are you sure you want to exit GOATPlayer?',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TvFocusable(
                      autofocus: true,
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Center(
                        child: Text(
                          l10n?.cancel ?? (l10n?.localeName == 'de' ? 'Abbrechen' : 'Cancel'),
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
    } finally {
      _isExitDialogOpen = false;
    }
  }

  static Future<void> performExit() async {
    if (GoatPlatform.isDesktop) {
      exit(0);
    } else {
      await SystemNavigator.pop(animated: true);
      Future.delayed(const Duration(milliseconds: 250), () => exit(0));
    }
  }

  @override
  ConsumerState<TvRemoteScope> createState() => _TvRemoteScopeState();
}

class _TvRemoteScopeState extends ConsumerState<TvRemoteScope> {
  int _lastBackTriggerTime = 0;

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
    if (event is KeyDownEvent || event is KeyUpEvent) {
      print('[GOAT_KEY] ${event.runtimeType}: ${event.logicalKey.keyLabel} (id: ${event.logicalKey.keyId})');
    }
    if ((event is! KeyDownEvent && event is! KeyUpEvent) || !mounted) return false;

    final key = event.logicalKey;

    // Directional TV Keys: Auto-recover focus if focus is currently null or lost
    final isArrowKey = key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    if (event is KeyDownEvent && isArrowKey) {
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary.context == null || primary == FocusScope.of(context)) {
        final currentScope = FocusScope.of(context);
        final target = currentScope.focusedChild ?? currentScope.traversalDescendants.firstOrNull;
        if (target != null && target.canRequestFocus) {
          target.requestFocus();
          return true;
        }
      }
    }

    // Media Keys: Play / Pause toggle
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyDownEvent) {
        ref.read(playbackControllerProvider.notifier).togglePlayPause();
      }
      return true;
    }

    // Smart TV / Desktop Back key: Escape or Android/TV goBack
    if (widget.isRoot &&
        (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack)) {
      // Debounce back key to prevent double trigger if TV sends both KeyDown and KeyUp
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastBackTriggerTime < 350) {
        return true;
      }
      _lastBackTriggerTime = now;

      // If HomeDashboard is NOT the current active route (e.g. VodPlayerScreen or a modal route is open above it),
      // do not intercept here! Let the active route handle its own back key / escape.
      if (ModalRoute.of(context)?.isCurrent != true) {
        return false;
      }

      // If a root back callback is supplied (e.g. restoring Live TV 3-column view, closing search, etc.)
      if (widget.onBackAtRoot != null) {
        widget.onBackAtRoot!();
        return true;
      }

      // Root Level Exit Confirmation
      _promptExit();
      return true;
    }

    return false;
  }

  void _promptExit() async {
    final shouldExit = await TvRemoteScope.showTvExitDialog(context);
    if (shouldExit && mounted) {
      await TvRemoteScope.performExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
