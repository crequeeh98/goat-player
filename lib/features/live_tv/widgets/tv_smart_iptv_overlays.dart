import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/database/app_database.dart';
import '../../../core/player/widgets/stream_quality_badge.dart';
import '../../../core/utils/channel_name_cleaner.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../dashboard/favorites_provider.dart';
import '../epg_controller.dart';
import 'channel_icon.dart';
import 'epg_timeline.dart';

enum TvLiveColorAction {
  toggleFavorite,
  openEpg,
  openCategories,
}

/// Compact D-Pad Color Action Picker triggered by Long-Press OK on Fire TV / Android TV.
/// Simulates Yellow (Favorite), Green (EPG), Blue (Categories/Groups), and Red (Remove).
class TvColorActionPicker extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<TvColorActionItem> items;

  const TvColorActionPicker({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
  });

  static Future<TvLiveColorAction?> showLiveActions({
    required BuildContext context,
    required String channelName,
    required bool isFavorite,
    required bool isDe,
  }) {
    return showDialog<TvLiveColorAction>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => TvColorActionPicker(
        title: channelName,
        subtitle: isDe ? 'Aktion wählen (Farbtasten)' : 'Choose Action (Color Keys)',
        items: [
          TvColorActionItem(
            dotColor: const Color(0xFFFACC15), // Yellow
            icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            label: isFavorite
                ? (isDe ? 'Aus Favoriten entfernen' : 'Remove from Favorites')
                : (isDe ? 'Zu Favoriten hinzufügen' : 'Add to Favorites'),
            onSelect: () => Navigator.of(ctx).pop(TvLiveColorAction.toggleFavorite),
          ),
          TvColorActionItem(
            dotColor: const Color(0xFF4ADE80), // Green
            icon: Icons.event_note_rounded,
            label: isDe ? 'Sender-EPG (TV-Programm)' : 'Channel EPG (Schedule)',
            onSelect: () => Navigator.of(ctx).pop(TvLiveColorAction.openEpg),
          ),
          TvColorActionItem(
            dotColor: const Color(0xFF60A5FA), // Blue
            icon: Icons.folder_special_rounded,
            label: isDe ? 'Gruppen / Kategorien wechseln' : 'Switch Group / Category',
            onSelect: () => Navigator.of(ctx).pop(TvLiveColorAction.openCategories),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showRemoveContinueWatching({
    required BuildContext context,
    required String itemTitle,
    required bool isDe,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => TvColorActionPicker(
        title: itemTitle,
        subtitle: isDe ? 'Weiter schauen' : 'Continue Watching',
        items: [
          TvColorActionItem(
            dotColor: const Color(0xFFF87171), // Red
            icon: Icons.delete_outline_rounded,
            label: isDe ? 'Aus „Weiter schauen“ entfernen' : 'Remove from Continue Watching',
            onSelect: () => Navigator.of(ctx).pop(true),
          ),
          TvColorActionItem(
            dotColor: Colors.white38,
            icon: Icons.close_rounded,
            label: isDe ? 'Abbrechen' : 'Cancel',
            onSelect: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xF5161124),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFB388FF).withValues(alpha: 0.4), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                TvFocusable(
                  autofocus: i == 0,
                  borderRadius: BorderRadius.circular(10),
                  focusBorderColor: items[i].dotColor,
                  onPressed: items[i].onSelect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF211A36),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: items[i].dotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: items[i].dotColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(items[i].icon, size: 19, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            items[i].label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TvColorActionItem {
  final Color dotColor;
  final IconData icon;
  final String label;
  final VoidCallback onSelect;

  const TvColorActionItem({
    required this.dotColor,
    required this.icon,
    required this.label,
    required this.onSelect,
  });
}

/// Smart-IPTV style Bottom Infobar shown in Fullscreen Live TV on Fire TV.
class TvLiveInfobar extends ConsumerWidget {
  final StreamItem stream;
  final int channelNumber;
  final Player player;

  const TvLiveInfobar({
    super.key,
    required this.stream,
    required this.channelNumber,
    required this.player,
  });

  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final cleanName = ChannelNameCleaner.clean(stream.name);
    final favoriteIds = ref.watch(favoriteStreamIdsProvider('live')).value ?? const <String>{};
    final isFavorite = favoriteIds.contains(stream.streamId);

    final epgId = (stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty)
        ? stream.epgChannelId!
        : stream.streamId;
    final programsAsync = ref.watch(channelProgramsProvider(epgId));
    final programs = programsAsync.asData?.value ?? const <EpgProgram>[];

    final now = DateTime.now();
    EpgProgram? currentProg;
    EpgProgram? nextProg;
    for (int i = 0; i < programs.length; i++) {
      final p = programs[i];
      if (now.isAfter(p.startTime) && now.isBefore(p.stopTime)) {
        currentProg = p;
        if (i + 1 < programs.length) {
          nextProg = programs[i + 1];
        }
        break;
      } else if (p.startTime.isAfter(now)) {
        nextProg ??= p;
        break;
      }
    }

    double progress = 0.0;
    String remainingText = '';
    if (currentProg != null) {
      final totalSecs = currentProg.stopTime.difference(currentProg.startTime).inSeconds;
      final elapsedSecs = now.difference(currentProg.startTime).inSeconds;
      if (totalSecs > 0) {
        progress = (elapsedSecs / totalSecs).clamp(0.0, 1.0);
      }
      final remMins = currentProg.stopTime.difference(now).inMinutes.clamp(0, 999);
      remainingText = '+$remMins min';
    }

    String nextDurationText = '';
    if (nextProg != null) {
      final durMins = nextProg.stopTime.difference(nextProg.startTime).inMinutes.clamp(1, 999);
      nextDurationText = '(${durMins}m)';
    }

    final clockStr = _fmtTime(now);

    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 20),
      decoration: BoxDecoration(
        color: const Color(0xEB100C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB388FF).withValues(alpha: 0.35), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top EPG Progress Bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 3.5,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB388FF)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Channel Number + Logo + Name
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$channelNumber',
                      style: const TextStyle(
                        color: Color(0xFFB388FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 14),
                    ChannelIcon(
                      iconUrl: stream.streamIcon,
                      channelName: cleanName,
                      size: 42,
                    ),
                    const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  cleanName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isFavorite) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDe ? 'OK: Kanalliste · Halten: 🟡🟢🔵' : 'OK: Channels · Hold: 🟡🟢🔵',
                            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: Colors.white12,
                ),
                // Center: Current & Next EPG Program
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Current Program
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              currentProg != null
                                  ? '${_fmtTime(currentProg.startTime)} - ${_fmtTime(currentProg.stopTime)}'
                                  : (isDe ? 'JETZT' : 'NOW'),
                              style: const TextStyle(
                                color: Color(0xFFD8B4FE),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentProg?.title ?? (isDe ? 'Keine Programminformationen' : 'No Program Information'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (remainingText.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              remainingText,
                              style: const TextStyle(
                                color: Color(0xFFB388FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: Next Program
                      Row(
                        children: [
                          Text(
                            isDe ? 'DANACH' : 'NEXT',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (nextProg != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _fmtTime(nextProg.startTime),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nextProg?.title ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (nextDurationText.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              nextDurationText,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right: Clock + LIVE + Quality Badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 7, color: Colors.redAccent),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          clockStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StreamQualityBadges(
                      player: player,
                      streamTitle: stream.name,
                      isCompact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Smart-IPTV style Centered Paginated Channel Menu (10 channels per page).
/// Up/Down navigates channels, Left/Right flips pages, OK selects channel, Long-Press OK opens Color Actions.
class TvLiveChannelMenu extends ConsumerStatefulWidget {
  final List<StreamItem> streams;
  final String? activeStreamId;
  final String categoryName;
  final ValueChanged<StreamItem> onSelectStream;
  final ValueChanged<StreamItem> onToggleFavorite;
  final ValueChanged<StreamItem> onOpenEpg;
  final VoidCallback onOpenCategories;
  final VoidCallback onClose;

  const TvLiveChannelMenu({
    super.key,
    required this.streams,
    required this.activeStreamId,
    required this.categoryName,
    required this.onSelectStream,
    required this.onToggleFavorite,
    required this.onOpenEpg,
    required this.onOpenCategories,
    required this.onClose,
  });

  @override
  ConsumerState<TvLiveChannelMenu> createState() => _TvLiveChannelMenuState();
}

class _TvLiveChannelMenuState extends ConsumerState<TvLiveChannelMenu> {
  static const int _pageSize = 7;
  final FocusNode _menuFocusNode = FocusNode(debugLabel: 'tv_live_channel_menu');
  int _focusedIndex = 0;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _keyDownHandled = false;

  @override
  void initState() {
    super.initState();
    final activeIdx = (widget.activeStreamId != null)
        ? widget.streams.indexWhere((s) => s.streamId == widget.activeStreamId)
        : -1;
    _focusedIndex = activeIdx >= 0 ? activeIdx : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menuFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(TvLiveChannelMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryName != widget.categoryName || oldWidget.streams != widget.streams) {
      final activeIdx = (widget.activeStreamId != null)
          ? widget.streams.indexWhere((s) => s.streamId == widget.activeStreamId)
          : -1;
      _focusedIndex = activeIdx >= 0 ? activeIdx : 0;
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _menuFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openColorMenuForFocused() async {
    if (widget.streams.isEmpty) return;
    final stream = widget.streams[_focusedIndex.clamp(0, widget.streams.length - 1)];
    final favIds = ref.read(favoriteStreamIdsProvider('live')).value ?? const <String>{};
    final isFav = favIds.contains(stream.streamId);
    final isDe = Localizations.localeOf(context).languageCode == 'de';

    final action = await TvColorActionPicker.showLiveActions(
      context: context,
      channelName: ChannelNameCleaner.clean(stream.name),
      isFavorite: isFav,
      isDe: isDe,
    );
    if (!mounted) return;
    _menuFocusNode.requestFocus();

    if (action == TvLiveColorAction.toggleFavorite) {
      widget.onToggleFavorite(stream);
    } else if (action == TvLiveColorAction.openEpg) {
      widget.onOpenEpg(stream);
    } else if (action == TvLiveColorAction.openCategories) {
      widget.onOpenCategories();
    }
  }

  void _activateFocused() {
    if (widget.streams.isEmpty) return;
    final stream = widget.streams[_focusedIndex.clamp(0, widget.streams.length - 1)];
    if (stream.streamId == widget.activeStreamId) {
      widget.onClose();
    } else {
      widget.onSelectStream(stream);
      widget.onClose();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final total = widget.streams.length;
    final isBack = event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.backspace;

    if (total == 0) {
      if (event is KeyDownEvent && isBack) {
        widget.onClose();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent) {
        _openColorMenuForFocused();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;

    if (isSelect) {
      if (event is KeyDownEvent) {
        _keyDownHandled = true;
        _longPressTriggered = false;
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _longPressTriggered = true;
            _openColorMenuForFocused();
          }
        });
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (_keyDownHandled) {
          _keyDownHandled = false;
          if (!_longPressTriggered) {
            _activateFocused();
          }
          _longPressTriggered = false;
          return KeyEventResult.handled;
        }
      }
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (isBack) {
        widget.onClose();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _focusedIndex = (_focusedIndex + 1) % total;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _focusedIndex = (_focusedIndex - 1 + total) % total;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.pageDown) {
        setState(() {
          final nextPageStart = ((_focusedIndex ~/ _pageSize) + 1) * _pageSize;
          _focusedIndex = nextPageStart < total ? nextPageStart : 0;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.pageUp) {
        setState(() {
          final currentPage = _focusedIndex ~/ _pageSize;
          final totalPages = (total / _pageSize).ceil();
          final prevPage = currentPage > 0 ? currentPage - 1 : totalPages - 1;
          _focusedIndex = (prevPage * _pageSize).clamp(0, total - 1);
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final total = widget.streams.length;
    final totalPages = total > 0 ? (total / _pageSize).ceil() : 1;
    final currentPage = total > 0 ? (_focusedIndex ~/ _pageSize) : 0;
    final startIdx = currentPage * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, total);

    final currentPrograms = ref.watch(currentProgramsMapProvider).asData?.value ?? const <String, EpgProgram>{};
    final favoriteIds = ref.watch(favoriteStreamIdsProvider('live')).value ?? const <String>{};
    final now = DateTime.now();

    return Focus(
      focusNode: _menuFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Container(
          width: 620,
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xF2120D20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB388FF).withValues(alpha: 0.4), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 32, offset: Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1430),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tv_rounded, color: Color(0xFFB388FF), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isDe ? 'Seite' : 'Page'} ${currentPage + 1} / $totalPages',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_left_rounded, size: 15, color: Colors.white70),
                          const Icon(Icons.chevron_right_rounded, size: 15, color: Colors.white70),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // 10 Channels Page List
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: total == 0
                      ? SizedBox(
                          height: 410,
                          child: Center(
                            child: Text(
                              isDe ? 'Keine Sender in dieser Kategorie' : 'No channels in this category',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int idx = startIdx; idx < endIdx; idx++)
                              _buildChannelRow(
                                idx: idx,
                                stream: widget.streams[idx],
                                isFocused: idx == _focusedIndex,
                                isPlaying: widget.streams[idx].streamId == widget.activeStreamId,
                                isFavorite: favoriteIds.contains(widget.streams[idx].streamId),
                                currentPrograms: currentPrograms,
                                now: now,
                              ),
                            for (int i = 0; i < (_pageSize - (endIdx - startIdx)); i++)
                              Container(
                                height: 38,
                                margin: const EdgeInsets.symmetric(vertical: 1.5),
                              ),
                          ],
                        ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // Footer Legend
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: const BoxDecoration(
                  color: Color(0xFF161028),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDe ? 'OK: Wählen  ·  ' : 'OK: Select  ·  ',
                          style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.chevron_left_rounded, size: 13, color: Colors.white70),
                        const Icon(Icons.chevron_right_rounded, size: 13, color: Colors.white70),
                        Text(
                          isDe ? ' Seite' : ' Page',
                          style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDe ? 'OK Halten: ' : 'Hold OK: ',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        _legendDot(const Color(0xFFFACC15), isDe ? 'Favorit' : 'Favorite'),
                        const SizedBox(width: 10),
                        _legendDot(const Color(0xFF4ADE80), 'EPG'),
                        const SizedBox(width: 10),
                        _legendDot(const Color(0xFF60A5FA), isDe ? 'Gruppen' : 'Groups'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildChannelRow({
    required int idx,
    required StreamItem stream,
    required bool isFocused,
    required bool isPlaying,
    required bool isFavorite,
    required Map<String, EpgProgram> currentPrograms,
    required DateTime now,
  }) {
    final cleanName = ChannelNameCleaner.clean(stream.name);
    final epgId = (stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty)
        ? stream.epgChannelId!
        : stream.streamId;
    final prog = currentPrograms[epgId];

    double progress = 0.0;
    String remStr = '';
    if (prog != null) {
      final totalSecs = prog.stopTime.difference(prog.startTime).inSeconds;
      final elapsedSecs = now.difference(prog.startTime).inSeconds;
      if (totalSecs > 0) {
        progress = (elapsedSecs / totalSecs).clamp(0.0, 1.0);
      }
      final remMins = prog.stopTime.difference(now).inMinutes.clamp(0, 999);
      remStr = '+${remMins}m';
    }

    return GestureDetector(
      onTap: () {
        setState(() => _focusedIndex = idx);
        _activateFocused();
      },
      onLongPress: () {
        setState(() => _focusedIndex = idx);
        _openColorMenuForFocused();
      },
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isFocused
              ? const Color(0xFF3B2370)
              : (isPlaying ? const Color(0xFF231742) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused
                ? const Color(0xFFB388FF)
                : (isPlaying ? const Color(0xFF7C3AED).withValues(alpha: 0.5) : Colors.transparent),
            width: isFocused ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${idx + 1}',
                style: TextStyle(
                  color: isFocused ? const Color(0xFFD8B4FE) : Colors.white54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            ChannelIcon(
              iconUrl: stream.streamIcon,
              channelName: cleanName,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Text(
                cleanName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: (isFocused || isPlaying) ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Text(
                prog?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isFocused ? const Color(0xFFE9D5FF) : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
            if (prog != null) ...[
              const SizedBox(width: 8),
              Text(
                remStr,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB388FF)),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              child: isFavorite
                  ? const Icon(Icons.star_rounded, color: Colors.amber, size: 16)
                  : (isPlaying
                      ? const Icon(Icons.play_arrow_rounded, color: Color(0xFFB388FF), size: 16)
                      : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Smart-IPTV style Centered Paginated Category / Bouquet Menu (10 categories per page).
class TvLiveCategoryMenu extends StatefulWidget {
  final List<Category> categories;
  final String? activeCategoryId;
  final String? focusedCategoryId;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onClose;

  const TvLiveCategoryMenu({
    super.key,
    required this.categories,
    this.activeCategoryId,
    this.focusedCategoryId,
    required this.onSelectCategory,
    required this.onClose,
  });

  @override
  State<TvLiveCategoryMenu> createState() => _TvLiveCategoryMenuState();
}

class _TvLiveCategoryMenuState extends State<TvLiveCategoryMenu> {
  static const int _pageSize = 7;
  final FocusNode _focusNode = FocusNode(debugLabel: 'tv_live_category_menu');
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    final targetId = widget.focusedCategoryId ?? widget.activeCategoryId;
    if (targetId != null) {
      final idx = widget.categories.indexWhere((c) => c.categoryId == targetId);
      if (idx >= 0) _focusedIndex = idx;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final total = widget.categories.length;
    final isBack = event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.backspace;

    if (total == 0) {
      if (event is KeyDownEvent && isBack) {
        widget.onClose();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (isBack) {
        widget.onClose();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final cat = widget.categories[_focusedIndex.clamp(0, total - 1)];
        widget.onSelectCategory(cat.categoryId);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() => _focusedIndex = (_focusedIndex + 1) % total);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() => _focusedIndex = (_focusedIndex - 1 + total) % total);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.pageDown) {
        setState(() {
          final nextPageStart = ((_focusedIndex ~/ _pageSize) + 1) * _pageSize;
          _focusedIndex = nextPageStart < total ? nextPageStart : 0;
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.pageUp) {
        setState(() {
          final currentPage = _focusedIndex ~/ _pageSize;
          final totalPages = (total / _pageSize).ceil();
          final prevPage = currentPage > 0 ? currentPage - 1 : totalPages - 1;
          _focusedIndex = (prevPage * _pageSize).clamp(0, total - 1);
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final total = widget.categories.length;
    final totalPages = total > 0 ? (total / _pageSize).ceil() : 1;
    final currentPage = total > 0 ? (_focusedIndex ~/ _pageSize) : 0;
    final startIdx = currentPage * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, total);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Container(
          width: 500,
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xF2120D20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.45), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 32, offset: Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1430),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_rounded, color: Color(0xFF60A5FA), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDe ? 'Gruppen / Kategorien' : 'Groups / Categories',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isDe ? 'Seite' : 'Page'} ${currentPage + 1} / $totalPages',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_left_rounded, size: 15, color: Colors.white70),
                          const Icon(Icons.chevron_right_rounded, size: 15, color: Colors.white70),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: total == 0
                      ? SizedBox(
                          height: 410,
                          child: Center(
                            child: Text(
                              isDe ? 'Keine Kategorien vorhanden' : 'No categories available',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int idx = startIdx; idx < endIdx; idx++)
                              Builder(
                                builder: (context) {
                                  final cat = widget.categories[idx];
                                  final isFocused = idx == _focusedIndex;
                                  final isPlayingCat = cat.categoryId == widget.activeCategoryId;
                                  final isFav = cat.categoryId == 'favorites';
                                  return GestureDetector(
                                    onTap: () => widget.onSelectCategory(cat.categoryId),
                                    child: Container(
                                      height: 38,
                                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? const Color(0xFF3B2370)
                                            : (isPlayingCat ? const Color(0xFF231742) : Colors.transparent),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isFocused
                                              ? const Color(0xFFB388FF)
                                              : (isPlayingCat ? const Color(0xFF7C3AED).withValues(alpha: 0.5) : Colors.transparent),
                                          width: isFocused ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isFav ? Icons.star_rounded : Icons.folder_outlined,
                                            size: 18,
                                            color: isFav ? Colors.amber : (isFocused ? const Color(0xFFB388FF) : Colors.white60),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              isFav ? (isDe ? 'Favoriten' : 'Favorites') : cat.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: (isFocused || isPlayingCat) ? FontWeight.bold : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (isPlayingCat)
                                            const Icon(Icons.check_circle, size: 16, color: Color(0xFFB388FF)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            for (int i = 0; i < (_pageSize - (endIdx - startIdx)); i++)
                              Container(
                                height: 38,
                                margin: const EdgeInsets.symmetric(vertical: 1.5),
                              ),
                          ],
                        ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: const BoxDecoration(
                  color: Color(0xFF161028),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDe ? 'OK: Gruppe öffnen  ·  ' : 'OK: Open Group  ·  ',
                          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                        ),
                        const Icon(Icons.chevron_left_rounded, size: 13, color: Colors.white70),
                        const Icon(Icons.chevron_right_rounded, size: 13, color: Colors.white70),
                        Text(
                          isDe ? ' Seite' : ' Page',
                          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                        ),
                      ],
                    ),
                    Text(
                      isDe ? 'Zurück: Schließen' : 'Back: Close',
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smart-IPTV style Centered Full Channel EPG Schedule Overlay.
class TvLiveEpgOverlay extends ConsumerWidget {
  final StreamItem stream;
  final VoidCallback onClose;

  const TvLiveEpgOverlay({
    super.key,
    required this.stream,
    required this.onClose,
  });

  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final cleanName = ChannelNameCleaner.clean(stream.name);
    final epgId = (stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty)
        ? stream.epgChannelId!
        : stream.streamId;
    final programsAsync = ref.watch(channelProgramsProvider(epgId));
    final now = DateTime.now();

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final isBack = event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.backspace;
          if (isBack) {
            onClose();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Container(
          width: 640,
          height: 392,
          decoration: BoxDecoration(
          color: const Color(0xF2120D20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.45), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 32, offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1B1430),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  ChannelIcon(iconUrl: stream.streamIcon, channelName: cleanName, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$cleanName — ${isDe ? 'TV-Programm (EPG)' : 'Channel Schedule (EPG)'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(8),
                    onPressed: onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDe ? '✕ Schließen' : '✕ Close',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: programsAsync.when(
                data: (allPrograms) {
                  final upcoming = allPrograms.where((p) => p.stopTime.isAfter(now)).toList();
                  if (upcoming.isEmpty) {
                    return Center(
                      child: Text(
                        isDe ? 'Keine EPG-Daten für diesen Sender verfügbar.' : 'No EPG schedule available for this channel.',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: upcoming.length,
                    itemBuilder: (context, index) {
                      final p = upcoming[index];
                      final isLive = now.isAfter(p.startTime) && now.isBefore(p.stopTime);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TvFocusable(
                          autofocus: index == 0,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () {},
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                (event.logicalKey == LogicalKeyboardKey.escape ||
                                    event.logicalKey == LogicalKeyboardKey.goBack)) {
                              onClose();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isLive ? const Color(0xFF281A48) : const Color(0xFF1A132B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLive ? const Color(0xFFB388FF).withValues(alpha: 0.4) : Colors.white10,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${_fmtTime(p.startTime)} - ${_fmtTime(p.stopTime)}',
                                      style: const TextStyle(
                                        color: Color(0xFFB388FF),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    if (isLive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isDe ? 'JETZT' : 'LIVE',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (p.description != null && p.description!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    p.description!.trim(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
