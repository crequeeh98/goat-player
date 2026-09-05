import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../core/database/app_database.dart';

import 'epg_controller.dart';
import 'widgets/video_preview.dart';
import 'widgets/epg_timeline.dart';
import 'widgets/channel_icon.dart';
import 'live_tv_controller.dart';
import '../dashboard/favorites_provider.dart';
import '../../core/utils/channel_name_cleaner.dart';
import '../../core/utils/live_stream_matcher.dart';
import '../../core/player/playback_controller.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../main.dart';

class DesktopLiveScreen extends ConsumerStatefulWidget {
  const DesktopLiveScreen({super.key});

  @override
  ConsumerState<DesktopLiveScreen> createState() => _DesktopLiveScreenState();
}

class _DesktopLiveScreenState extends ConsumerState<DesktopLiveScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();
  final GlobalKey _videoPreviewKey = GlobalKey();
  final FocusNode _firstChannelNode = FocusNode();

  String? _lastScrolledStreamId;
  String? _lastScrolledCategoryId;
  String? _lastCategoryRailScrolledId;

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _channelScrollController.dispose();
    _firstChannelNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        ref.read(epgControllerProvider).syncEpgData();
      }
    });
  }

  void _scrollToActiveChannel(List<StreamItem> streams, String? activeId) {
    if (activeId == null || streams.isEmpty) return;
    final index = streams.indexWhere((s) => s.streamId == activeId);
    if (index >= 0) {
      _lastScrolledStreamId = activeId;
      _lastScrolledCategoryId = _selectedCategory;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_channelScrollController.hasClients) return;
        const itemHeight = 64.0;
        final viewportHeight = _channelScrollController.position.hasViewportDimension
            ? _channelScrollController.position.viewportDimension
            : 600.0;
        final targetOffset = (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _channelScrollController.position.maxScrollExtent;
        final clampedOffset = targetOffset.clamp(0.0, maxScroll);
        _channelScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _scrollToActiveCategory(List<Category> categories, String? activeCatId) {
    if (activeCatId == null || categories.isEmpty) return;
    final index = categories.indexWhere((c) => c.categoryId == activeCatId);
    if (index >= 0) {
      _lastCategoryRailScrolledId = activeCatId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_categoryScrollController.hasClients) return;
        const itemHeight = 46.0;
        final viewportHeight = _categoryScrollController.position.hasViewportDimension
            ? _categoryScrollController.position.viewportDimension
            : 600.0;
        final targetOffset = (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _categoryScrollController.position.maxScrollExtent;
        final clampedOffset = targetOffset.clamp(0.0, maxScroll);
        _categoryScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _playStream(StreamItem stream) {
    final activePlayback = ref.read(playbackControllerProvider);
    final effectiveCat = _selectedCategory ?? stream.categoryId;
    
    // Prevent redundant reload if stream is already playing in the same category
    if (activePlayback != null &&
        activePlayback.streamType == StreamType.live &&
        activePlayback.streamId == stream.streamId &&
        activePlayback.categoryId == effectiveCat) {
      return;
    }

    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final cleanName = ChannelNameCleaner.clean(stream.name);
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final url = '$baseUrl/live/${account.username}/${account.password}/${stream.streamId}.ts';
    final epgChannelId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId;

    ref.read(playbackControllerProvider.notifier).playLive(
      title: cleanName,
      url: url,
      channelId: epgChannelId,
      streamId: stream.streamId,
      categoryId: effectiveCat,
    );
    ref.read(selectedLiveCategoryProvider.notifier).set(effectiveCat);
    ref.read(selectedLiveStreamProvider.notifier).set(stream);
  }

  void _zapNext(List<StreamItem> streams) {
    if (streams.isEmpty) return;
    final activePlayback = ref.read(playbackControllerProvider);
    final currentIndex = LiveStreamMatcher.indexOf(
      streams,
      streamId: activePlayback?.streamId,
      channelId: activePlayback?.channelId,
      streamUrl: activePlayback?.streamUrl,
    );
    final nextIndex = currentIndex >= 0 ? (currentIndex + 1) % streams.length : 0;
    _playStream(streams[nextIndex]);
  }

  void _zapPrevious(List<StreamItem> streams) {
    if (streams.isEmpty) return;
    final activePlayback = ref.read(playbackControllerProvider);
    final currentIndex = LiveStreamMatcher.indexOf(
      streams,
      streamId: activePlayback?.streamId,
      channelId: activePlayback?.channelId,
      streamUrl: activePlayback?.streamUrl,
    );
    final prevIndex = currentIndex >= 0 ? (currentIndex - 1 + streams.length) % streams.length : streams.length - 1;
    _playStream(streams[prevIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final _isFullWidth = ref.watch(isLiveFullWidthProvider);
    final activePlayback = ref.watch(playbackControllerProvider);
    final isLiveActive = activePlayback != null &&
        activePlayback.streamType == StreamType.live &&
        !activePlayback.isMinimized;
    final currentLive = isLiveActive ? activePlayback : null;

    final categories = ref.watch(liveCategoriesProvider).asData?.value ?? const <Category>[];
    final globalSelectedCat = ref.watch(selectedLiveCategoryProvider);

    // If _selectedCategory is not set locally (e.g. after minimizing and expanding),
    // restore it from the active playing stream, global provider, or first category
    _selectedCategory ??= activePlayback?.categoryId ?? globalSelectedCat ?? categories.firstOrNull?.categoryId;

    final currentCategoryStreams = _selectedCategory != null
        ? (ref.watch(liveStreamsProvider(_selectedCategory!)).asData?.value ?? const <StreamItem>[])
        : const <StreamItem>[];

    final currentCatObj = categories.where((c) => c.categoryId == _selectedCategory).firstOrNull;
    final categoryName = currentCatObj?.name;

    ref.listen<String?>(selectedLiveCategoryProvider, (prev, next) {
      if (next != null && next != _selectedCategory) {
        setState(() {
          _selectedCategory = next;
          _lastScrolledStreamId = null;
        });
      }
    });

    ref.listen<bool>(isLiveFullWidthProvider, (prev, next) {
      if (prev == true && next == false) {
        _lastScrolledStreamId = null;
        _lastScrolledCategoryId = null;
        _lastCategoryRailScrolledId = null;
      }
    });

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _isFullWidth ? null : AppBar(
        title: Text(l10n.liveTv),
      ),
      body: Row(
        children: [
          // Left Column (20%): Categories
          if (!_isFullWidth)
            Expanded(
              flex: 20,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                               event.logicalKey == LogicalKeyboardKey.enter)) {
                            FocusScope.of(context).nextFocus();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          decoration: InputDecoration(
                            hintText: l10n.search,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ref.watch(liveCategoriesProvider).when(
                        data: (rawCategories) {
                          var categories = rawCategories;
                          if (_searchQuery.isNotEmpty) {
                            categories = categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                          }
                          if (_selectedCategory != null && _selectedCategory != _lastCategoryRailScrolledId) {
                            _scrollToActiveCategory(categories, _selectedCategory);
                          }
                          return ListView.builder(
                            controller: _categoryScrollController,
                            itemExtent: 46.0,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategory == cat.categoryId;
                              final isFavorites = cat.categoryId == 'favorites';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: TvFocusable(
                                  focusScale: 1.02,
                                  borderRadius: BorderRadius.circular(8),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategory = cat.categoryId;
                                      _lastScrolledStreamId = null;
                                    });
                                    ref.read(selectedLiveCategoryProvider.notifier).set(cat.categoryId);
                                    if (cat.categoryId != 'favorites') {
                                      ref.read(liveTvControllerProvider).syncLiveStreams(cat.categoryId);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(
                                        left: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFFB388FF)
                                              : Colors.transparent,
                                          width: 3.5,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isFavorites
                                              ? (isSelected ? Icons.star_rounded : Icons.star_outline_rounded)
                                              : (isSelected ? Icons.tv : Icons.folder_outlined),
                                          size: 18,
                                          color: isFavorites
                                              ? Colors.amber
                                              : (isSelected ? const Color(0xFFB388FF) : Colors.white54),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            isFavorites ? AppLocalizations.of(context)!.favorites : cat.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white70,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('Error: $err')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (!_isFullWidth)
            const VerticalDivider(width: 1, thickness: 1),

          // Middle Column (35%): Channels in Category
          if (!_isFullWidth)
            Expanded(
              flex: 35,
              child: _selectedCategory == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.list, size: 48, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(AppLocalizations.of(context)!.selectCategory, style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ref.watch(liveStreamsProvider(_selectedCategory!)).when(
                      data: (streams) {
                        if (streams.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.tv_off, size: 48, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text('No channels in this category', style: const TextStyle(color: Colors.white54)),
                              ],
                            ),
                          );
                        }

                        final activeStreamId = activePlayback?.streamId ?? ref.watch(selectedLiveStreamProvider)?.streamId;
                        if (activeStreamId != null && (activeStreamId != _lastScrolledStreamId || _selectedCategory != _lastScrolledCategoryId)) {
                          _scrollToActiveChannel(streams, activeStreamId);
                        }

                        final favoriteIds = ref.watch(favoriteStreamIdsProvider('live')).value ?? const <String>{};
                        final account = ref.read(activeAccountProvider);
                        final baseUrl = account?.serverUrl.endsWith('/') == true ? account!.serverUrl.substring(0, account.serverUrl.length - 1) : account?.serverUrl;

                        return FocusScope(
                          child: FocusTraversalGroup(
                            policy: WidgetOrderTraversalPolicy(),
                            child: ListView.builder(
                              controller: _channelScrollController,
                              cacheExtent: 2500.0,
                              itemExtent: 64.0,
                              itemCount: streams.length,
                              itemBuilder: (context, index) {
                                final stream = streams[index];
                                final url = '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.ts';
                                final cleanName = ChannelNameCleaner.clean(stream.name);
                                final isFavorite = favoriteIds.contains(stream.streamId);
                                final isCurrentPlaying = (activePlayback?.streamId != null && activePlayback!.streamId == stream.streamId) ||
                                    (currentLive?.streamId != null && currentLive!.streamId == stream.streamId) ||
                                    currentLive?.streamUrl == url ||
                                    activePlayback?.streamUrl == url;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  child: TvFocusable(
                                    focusNode: index == 0 ? _firstChannelNode : null,
                                    focusScale: 1.02,
                                    borderRadius: BorderRadius.circular(10),
                                    onPressed: () => _playStream(stream),
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          if (index >= streams.length - 1) {
                                            _channelScrollController.jumpTo(0);
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _firstChannelNode.requestFocus();
                                            });
                                            return KeyEventResult.handled;
                                          }
                                          if (_channelScrollController.hasClients) {
                                            final viewport = _channelScrollController.position.viewportDimension;
                                            final offset = _channelScrollController.offset;
                                            final nextItemBottom = (index + 2) * 64.0;
                                            if (nextItemBottom > offset + viewport) {
                                              _channelScrollController.jumpTo((nextItemBottom - viewport + 64.0).clamp(0.0, _channelScrollController.position.maxScrollExtent));
                                            }
                                          }
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          if (index == 0) {
                                            return KeyEventResult.handled;
                                          }
                                          if (_channelScrollController.hasClients) {
                                            final offset = _channelScrollController.offset;
                                            final prevItemTop = (index - 1) * 64.0;
                                            if (prevItemTop < offset) {
                                              _channelScrollController.jumpTo(prevItemTop.clamp(0.0, _channelScrollController.position.maxScrollExtent));
                                            }
                                          }
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isCurrentPlaying
                                        ? const Color(0xFF2E1C59)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isCurrentPlaying
                                        ? Border.all(color: const Color(0xFFB388FF), width: 1.5)
                                        : Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    children: [
                                      ChannelIcon(
                                        iconUrl: stream.streamIcon,
                                        channelName: cleanName,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    cleanName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: isCurrentPlaying ? Colors.white : Colors.white.withValues(alpha: 0.88),
                                                      fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isFavorite ? Icons.favorite : Icons.favorite_border,
                                          size: 20,
                                        ),
                                        color: isFavorite ? Colors.red : Colors.white38,
                                        onPressed: () async {
                                          final acc = ref.read(activeAccountProvider);
                                          if (acc != null) {
                                            await ref.read(databaseProvider).favoriteDao.toggleFavorite(acc.id, stream.streamId, 'live');
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          ),
                        ),
                      );
                    },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.error}$err')),
                    ),
            ),
          
          if (!_isFullWidth)
            const VerticalDivider(width: 1, thickness: 1),

          // Right Column (45% or 100%): Player & EPG
          Expanded(
            flex: _isFullWidth ? 100 : 45,
            child: Column(
              children: [
                Expanded(
                  flex: _isFullWidth ? 100 : 50,
                  child: currentLive != null
                      ? VideoPreview(
                          key: _videoPreviewKey,
                          streamUrl: currentLive.streamUrl,
                          streamId: currentLive.streamId,
                          channelId: currentLive.channelId,
                          channelName: currentLive.title,
                          isFullWidth: _isFullWidth,
                          streams: currentCategoryStreams,
                          categoryName: categoryName,
                          onSelectStream: _playStream,
                          onZapNext: () => _zapNext(currentCategoryStreams),
                          onZapPrevious: () => _zapPrevious(currentCategoryStreams),
                          onToggleFullWidth: () {
                            ref.read(isLiveFullWidthProvider.notifier).toggle();
                          },
                          onEnsureFullWidth: () {
                            if (!_isFullWidth) ref.read(isLiveFullWidthProvider.notifier).set(true);
                          },
                          onExitToPreview: () {
                            if (_isFullWidth) ref.read(isLiveFullWidthProvider.notifier).set(false);
                          },
                        )
                      : Container(
                          color: Colors.black45,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.tv, size: 64, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text(AppLocalizations.of(context)!.selectChannel, style: const TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                ),
                if (!_isFullWidth)
                  const Divider(height: 1, thickness: 1),
                if (!_isFullWidth)
                  Expanded(
                  flex: 50,
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.epgSchedule,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        // EPG Timeline
                        Expanded(
                          child: EpgTimelineWidget(channelId: currentLive?.channelId),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

