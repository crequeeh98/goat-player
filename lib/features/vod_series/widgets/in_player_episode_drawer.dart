import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/widgets/tv_focusable.dart';

class InPlayerEpisodeDrawer extends StatefulWidget {
  final String seriesName;
  final Map<String, List<dynamic>> seasonsWithEpisodes;
  final String currentEpisodeId;
  final String? currentSeason;
  final Map<String, PlaybackProgressItem> episodeProgress;
  final ValueChanged<Map<String, dynamic>> onSelectEpisode;
  final VoidCallback onClose;
  final bool isOpen;

  const InPlayerEpisodeDrawer({
    super.key,
    required this.seriesName,
    required this.seasonsWithEpisodes,
    required this.currentEpisodeId,
    this.currentSeason,
    required this.episodeProgress,
    required this.onSelectEpisode,
    required this.onClose,
    this.isOpen = false,
  });

  @override
  State<InPlayerEpisodeDrawer> createState() => _InPlayerEpisodeDrawerState();
}

class _InPlayerEpisodeDrawerState extends State<InPlayerEpisodeDrawer> {
  late String _selectedSeason;
  final ScrollController _scrollController = ScrollController();
  final FocusScopeNode _drawerScopeNode = FocusScopeNode(debugLabel: 'EpisodeDrawerScope');
  final FocusNode _targetEpisodeFocusNode = FocusNode(debugLabel: 'target_episode');

  @override
  void initState() {
    super.initState();
    _initSeason();
    _scrollToCurrentEpisode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && GoatPlatform.isTv) {
        _drawerScopeNode.requestFocus();
        _targetEpisodeFocusNode.requestFocus();
      }
    });
  }

  void _initSeason() {
    if (widget.currentSeason != null && widget.seasonsWithEpisodes.containsKey(widget.currentSeason)) {
      _selectedSeason = widget.currentSeason!;
    } else if (widget.seasonsWithEpisodes.isNotEmpty) {
      _selectedSeason = widget.seasonsWithEpisodes.keys.first;
    } else {
      _selectedSeason = '1';
    }
  }

  void _scrollToCurrentEpisode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final episodes = widget.seasonsWithEpisodes[_selectedSeason] ?? [];
      final index = episodes.indexWhere((ep) => ep['id']?.toString() == widget.currentEpisodeId);
      if (index > 2) {
        _scrollController.jumpTo((index - 1) * 88.0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant InPlayerEpisodeDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSeason != widget.currentSeason && widget.currentSeason != null) {
      setState(() {
        _selectedSeason = widget.currentSeason!;
      });
      _scrollToCurrentEpisode();
    } else if (oldWidget.currentEpisodeId != widget.currentEpisodeId) {
      _scrollToCurrentEpisode();
    }
    if (!oldWidget.isOpen && widget.isOpen) {
      _scrollToCurrentEpisode();
    }
  }

  @override
  void dispose() {
    _drawerScopeNode.dispose();
    _targetEpisodeFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final episodes = widget.seasonsWithEpisodes[_selectedSeason] ?? [];
    final seasonKeys = widget.seasonsWithEpisodes.keys.toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onClose();
      },
      child: FocusScope(
        node: _drawerScopeNode,
        autofocus: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: GoatPlatform.isMobile ? 330 : 420,
            color: const Color(0xE814141E), // Frosted glass dark slate
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.only(left: 16, right: 8, top: 14, bottom: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library_outlined, color: Colors.white70, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.seriesName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              l10n?.episodes ?? 'Episodes',
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      GoatPlatform.isTv
                          ? TvFocusable(
                              borderRadius: BorderRadius.circular(18),
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                  if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                    return KeyEventResult.handled;
                                  } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                                      event.logicalKey == LogicalKeyboardKey.backspace ||
                                      event.logicalKey == LogicalKeyboardKey.goBack) {
                                    widget.onClose();
                                    return KeyEventResult.handled;
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              onPressed: widget.onClose,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.close, color: Colors.white70, size: 20),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                              tooltip: l10n?.close ?? 'Close',
                              onPressed: widget.onClose,
                            ),
                    ],
                  ),
                ),

                // Season Selector Bar
                if (seasonKeys.length > 1)
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: seasonKeys.length,
                      itemBuilder: (context, index) {
                        final seasonKey = seasonKeys[index];
                        final isSelected = seasonKey == _selectedSeason;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: TvFocusable(
                            focusScale: 1.01,
                            borderRadius: BorderRadius.circular(8),
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index == 0) {
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && index >= seasonKeys.length - 1) {
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                                    event.logicalKey == LogicalKeyboardKey.goBack ||
                                    (GoatPlatform.isTv && event.logicalKey == LogicalKeyboardKey.backspace)) {
                                  widget.onClose();
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            onPressed: () {
                              setState(() => _selectedSeason = seasonKey);
                              _scrollToCurrentEpisode();
                            },
                            child: ChoiceChip(
                              label: Text(
                                '${l10n?.season ?? 'Season'} $seasonKey',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedSeason = seasonKey);
                                  _scrollToCurrentEpisode();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Episodes List
                Expanded(
                  child: episodes.isEmpty
                      ? Center(
                          child: const Text(
                            'Keine Folgen / No episodes found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          itemCount: episodes.length,
                          itemBuilder: (context, index) {
                            final ep = episodes[index] is Map ? (episodes[index] as Map).cast<String, dynamic>() : <String, dynamic>{};
                            final epId = ep['id']?.toString() ?? '';
                            final isCurrent = epId == widget.currentEpisodeId;
                            final epNum = ep['episode_num']?.toString() ?? '${index + 1}';
                            final title = ep['title']?.toString() ?? 'Episode $epNum';
                            final durationStr = ep['info']?['duration']?.toString() ?? '';
                            final imageUrl = ep['info']?['movie_image']?.toString();

                            final progress = widget.episodeProgress[epId];
                            final isCompleted = progress?.isCompleted == true ||
                                (progress != null && progress.duration > 0 && (progress.position / progress.duration) >= 0.95);
                            final progressRatio = (progress != null && progress.duration > 0)
                                ? (isCompleted ? 1.0 : (progress.position / progress.duration).clamp(0.0, 1.0))
                                : 0.0;

                            final targetIndex = episodes.indexWhere((e) => e['id']?.toString() == widget.currentEpisodeId);
                            final resolvedTargetIndex = targetIndex != -1 ? targetIndex : 0;
                            final isTarget = index == resolvedTargetIndex;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TvFocusable(
                                focusNode: isTarget ? _targetEpisodeFocusNode : null,
                                autofocus: GoatPlatform.isTv && isTarget,
                                focusScale: 1.01,
                                borderRadius: BorderRadius.circular(10),
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                                        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                                        event.logicalKey == LogicalKeyboardKey.goBack ||
                                        (GoatPlatform.isTv && event.logicalKey == LogicalKeyboardKey.backspace)) {
                                      widget.onClose();
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && index >= episodes.length - 1) {
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0 && seasonKeys.length <= 1) {
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                              onPressed: () => widget.onSelectEpisode(ep),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrent
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: isCurrent ? 1.5 : 1.0,
                                  ),
                                ),
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Thumbnail or Episode badge
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              width: 76,
                                              height: 48,
                                              color: Colors.black45,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  if (imageUrl != null && imageUrl.isNotEmpty)
                                                    Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      cacheWidth: 152,
                                                      cacheHeight: 96,
                                                      errorBuilder: (_, __, ___) => Center(
                                                        child: Text('E$epNum', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                                      ),
                                                    )
                                                  else
                                                    Center(
                                                      child: Text('E$epNum', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                                    ),
                                                  Center(
                                                    child: Icon(
                                                      isCurrent ? Icons.play_arrow : Icons.play_circle_outline,
                                                      color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white70,
                                                      size: 28,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Episode info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                                          fontSize: 13,
                                                          height: 1.25,
                                                          color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                                        ),
                                                      ),
                                                    ),
                                                    if (isCompleted)
                                                      const Padding(
                                                        padding: EdgeInsets.only(left: 4, top: 2),
                                                        child: Icon(Icons.check_circle, size: 14, color: Colors.green),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  durationStr.isNotEmpty ? durationStr : 'Ep. $epNum',
                                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (progressRatio > 0) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: progressRatio,
                                          backgroundColor: Colors.white12,
                                          color: Colors.redAccent,
                                          minHeight: 3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
    ),
  );
}
}
