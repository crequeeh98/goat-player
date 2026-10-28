import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../core/database/app_database.dart';

import 'epg_controller.dart';
import 'widgets/video_preview.dart';
import 'widgets/epg_timeline.dart';
import 'widgets/channel_icon.dart';
import 'widgets/tv_smart_iptv_overlays.dart';
import 'live_tv_controller.dart';
import '../dashboard/favorites_provider.dart';
import '../dashboard/dashboard_state.dart';
import '../../core/utils/channel_name_cleaner.dart';
import '../../core/utils/live_stream_matcher.dart';
import '../../core/player/playback_controller.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/tv_text_field.dart';
import '../../core/utils/platform_utils.dart';
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
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'category_search');
  final FocusNode _firstCategoryNode = FocusNode(debugLabel: 'first_category');
  final FocusNode _firstChannelNode = FocusNode(debugLabel: 'first_channel');
  final FocusNode _playerNode = FocusNode(debugLabel: 'player_preview');
  final Map<String, FocusNode> _categoryFocusNodes = {};
  final Map<String, FocusNode> _channelFocusNodes = {};
  FocusNode? _lastFocusedChannelNode;
  final Set<String> _syncedCategories = {};
  bool _focusFirstChannelOnNextBuild = false;
  Timer? _channelPlayDebounce;

  String? _lastScrolledStreamId;
  String? _lastScrolledCategoryId;
  String? _lastCategoryRailScrolledId;

  @override
  void dispose() {
    _channelPlayDebounce?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeScreenSearchFocusNodeProvider.notifier).set(null);
      ref.read(activeCategoryFocusNodeProvider.notifier).set(null);
    });
    _categoryScrollController.dispose();
    _channelScrollController.dispose();
    _firstCategoryNode.dispose();
    _firstChannelNode.dispose();
    _playerNode.dispose();
    _searchFocusNode.dispose();
    for (final node in _categoryFocusNodes.values) {
      node.dispose();
    }
    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _focusCategoryColumn() {
    if (_selectedCategory != null) {
      final node = _categoryFocusNodes[_selectedCategory];
      if (node != null && node.context != null && node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
    // If not currently in view, jump directly to active category so it mounts immediately
    final categories = ref.read(liveCategoriesProvider).asData?.value;
    if (categories != null && _selectedCategory != null) {
      final index = categories.indexWhere((c) => c.categoryId == _selectedCategory);
      if (index >= 0 && _categoryScrollController.hasClients) {
        final itemHeight = GoatPlatform.isTv ? 36.0 : 46.0;
        final viewportHeight = _categoryScrollController.position.hasViewportDimension
            ? _categoryScrollController.position.viewportDimension
            : 600.0;
        final targetOffset = ((index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2))
            .clamp(0.0, _categoryScrollController.position.maxScrollExtent);
        _categoryScrollController.jumpTo(targetOffset);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final node = _categoryFocusNodes[_selectedCategory];
        if (node != null && node.context != null && node.canRequestFocus) {
          node.requestFocus();
        } else if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
          _firstCategoryNode.requestFocus();
        } else if (_searchFocusNode.context != null && _searchFocusNode.canRequestFocus) {
          _searchFocusNode.requestFocus();
        }
      });
      return;
    }
    if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
      _firstCategoryNode.requestFocus();
      return;
    }
    for (final node in _categoryFocusNodes.values) {
      if (node.context != null && node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
    // Fallback: move focus left or search
    if (_searchFocusNode.context != null && _searchFocusNode.canRequestFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _focusChannelColumn() {
    final activeId = ref.read(playbackControllerProvider)?.streamId ?? ref.read(selectedLiveStreamProvider)?.streamId;
    if (activeId != null) {
      final activeNode = _channelFocusNodes[activeId];
      if (activeNode != null && activeNode.context != null && activeNode.canRequestFocus) {
        activeNode.requestFocus();
        return;
      }
    }
    if (_lastFocusedChannelNode != null && _lastFocusedChannelNode!.context != null && _lastFocusedChannelNode!.canRequestFocus) {
      _lastFocusedChannelNode!.requestFocus();
      return;
    }
    if (_firstChannelNode.context != null && _firstChannelNode.canRequestFocus) {
      _firstChannelNode.requestFocus();
      return;
    }
    for (final node in _channelFocusNodes.values) {
      if (node.context != null && node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
    // If channel items are not mounted yet (loading or rebuilding), queue focus for the next frame
    _focusFirstChannelOnNextBuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_firstChannelNode.context != null && _firstChannelNode.canRequestFocus) {
        _firstChannelNode.requestFocus();
      } else {
        for (final node in _channelFocusNodes.values) {
          if (node.context != null && node.canRequestFocus) {
            node.requestFocus();
            return;
          }
        }
      }
    });
  }

  Future<void> _handleChannelLongPress(StreamItem stream) async {
    if (!GoatPlatform.isTv) {
      await _toggleFavorite(stream);
      return;
    }
    final favIds = ref.read(favoriteStreamIdsProvider('live')).value ?? const <String>{};
    final isFav = favIds.contains(stream.streamId);
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final cleanName = ChannelNameCleaner.clean(stream.name);

    final action = await TvColorActionPicker.showLiveActions(
      context: context,
      channelName: cleanName,
      isFavorite: isFav,
      isDe: isDe,
    );
    if (!mounted || action == null) return;

    if (action == TvLiveColorAction.toggleFavorite) {
      await _toggleFavorite(stream);
    } else if (action == TvLiveColorAction.openEpg) {
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: TvLiveEpgOverlay(
            stream: stream,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } else if (action == TvLiveColorAction.openCategories) {
      _focusCategoryColumn();
    }
  }

  Future<void> _toggleFavorite(StreamItem stream) async {
    final acc = ref.read(activeAccountProvider);
    if (acc == null) return;
    final isFav = (ref.read(favoriteStreamIdsProvider('live')).value ?? const <String>{}).contains(stream.streamId);
    await ref.read(databaseProvider).favoriteDao.toggleFavorite(acc.id, stream.streamId, 'live');
    if (!mounted) return;
    final cleanTitle = ChannelNameCleaner.clean(stream.name);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              !isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: !isFav ? Colors.amber : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                Localizations.localeOf(context).languageCode == 'de'
                    ? (!isFav
                        ? '$cleanTitle zu Favoriten hinzugefügt'
                        : '$cleanTitle aus Favoriten entfernt')
                    : (!isFav
                        ? '$cleanTitle added to Favorites'
                        : '$cleanTitle removed from Favorites'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: const Color(0xFFB388FF).withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(activeDashboardTabProvider) == 0) {
        ref.read(activeScreenSearchFocusNodeProvider.notifier).set(_searchFocusNode);
        ref.read(activeCategoryFocusNodeProvider.notifier).set(_firstCategoryNode);
      }
    });
    if (!GoatPlatform.isTv) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          final account = ref.read(activeAccountProvider);
          final isM3u = account != null && (account.username.isEmpty || account.serverUrl.contains('.m3u'));
          if (!isM3u) {
            ref.read(epgControllerProvider).syncEpgData();
          }
        }
      });
    }
  }

  void _selectCategory(String catId) {
    setState(() {
      _selectedCategory = catId;
      _lastScrolledStreamId = null;
      _lastFocusedChannelNode = null;
      _channelFocusNodes.clear();
    });
    if (_channelScrollController.hasClients) {
      _channelScrollController.jumpTo(0.0);
    }
    ref.read(selectedLiveCategoryProvider.notifier).set(catId);
    final account = ref.read(activeAccountProvider);
    final isM3u = account != null && (account.username.isEmpty || account.serverUrl.contains('.m3u'));
    if (catId != 'favorites' && !isM3u) {
      _syncedCategories.add(catId);
      ref.read(liveTvControllerProvider).syncLiveStreams(catId);
    }
  }

  void _scrollToActiveChannel(List<StreamItem> streams, String? activeId) {
    if (activeId == null || streams.isEmpty) return;
    final index = streams.indexWhere((s) => s.streamId == activeId);
    if (index >= 0) {
      _lastScrolledStreamId = activeId;
      _lastScrolledCategoryId = _selectedCategory;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_channelScrollController.hasClients) return;
        final itemHeight = GoatPlatform.isTv ? 48.0 : 64.0;
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
        final itemHeight = GoatPlatform.isTv ? 36.0 : 46.0;
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
    debugPrint('[GOAT_PLAY] _playStream clicked: name="${stream.name}", id="${stream.streamId}", storedUrl="${stream.url}"');
    final activePlayback = ref.read(playbackControllerProvider);
    final effectiveCat = _selectedCategory ?? stream.categoryId;

    // On Smart TV / Fire TV: 2nd OK press on the already-playing channel enters Fullscreen!
    if (activePlayback != null &&
        activePlayback.streamType == StreamType.live &&
        activePlayback.streamId == stream.streamId &&
        activePlayback.categoryId == effectiveCat) {
      if (GoatPlatform.isTv && !ref.read(isLiveFullWidthProvider)) {
        ref.read(isLiveFullWidthProvider.notifier).set(true);
      }
      return;
    }

    ref.read(selectedLiveCategoryProvider.notifier).set(effectiveCat);

    _channelPlayDebounce?.cancel();
    ref.read(selectedLiveStreamProvider.notifier).set(stream);
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final cleanName = ChannelNameCleaner.clean(stream.name);
    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
    final ext = GoatPlatform.isWeb ? 'm3u8' : 'ts';
    final url = (stream.url != null && stream.url!.startsWith('http'))
        ? stream.url!
        : '$baseUrl/live/${account.username}/${account.password}/${stream.streamId}.$ext';
    final epgChannelId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId;

    ref.read(playbackControllerProvider.notifier).playLive(
      title: cleanName,
      url: url,
      channelId: epgChannelId,
      streamId: stream.streamId,
      categoryId: effectiveCat,
    );
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

    ref.listen(activeDashboardTabProvider, (prev, next) {
      if (next == 0 && mounted) {
        ref.read(activeScreenSearchFocusNodeProvider.notifier).set(_searchFocusNode);
        ref.read(activeCategoryFocusNodeProvider.notifier).set(_firstCategoryNode);
      }
    });

    ref.listen(dashboardTabResetProvider, (_, __) {
      if (ref.read(activeDashboardTabProvider) == 0 && mounted) {
        ref.read(activeScreenSearchFocusNodeProvider.notifier).set(_searchFocusNode);
        ref.read(activeCategoryFocusNodeProvider.notifier).set(_firstCategoryNode);
      }
      _searchController.clear();
      if (mounted) {
        setState(() {
          _searchQuery = '';
        });
        if (_categoryScrollController.hasClients) {
          _categoryScrollController.jumpTo(0.0);
        }
        if (_channelScrollController.hasClients) {
          _channelScrollController.jumpTo(0.0);
        }
      }
    });

    ref.listen<String?>(selectedLiveCategoryProvider, (prev, next) {
      if (next != null && next != _selectedCategory) {
        setState(() {
          _selectedCategory = next;
          _lastScrolledStreamId = null;
          _lastFocusedChannelNode = null;
          _channelFocusNodes.clear();
          _focusFirstChannelOnNextBuild = true;
        });
      }
    });

    ref.listen<bool>(isLiveFullWidthProvider, (prev, next) {
      if (prev == true && next == false) {
        _lastScrolledStreamId = null;
        _lastScrolledCategoryId = null;
        _lastCategoryRailScrolledId = null;
        // When exiting fullscreen back to dashboard, ensure dashboard category
        // matches the currently playing stream's category!
        final activePlayback = ref.read(playbackControllerProvider);
        if (activePlayback?.categoryId != null && activePlayback!.categoryId != _selectedCategory) {
          setState(() {
            _selectedCategory = activePlayback.categoryId;
            _lastFocusedChannelNode = null;
            _channelFocusNodes.clear();
            _focusFirstChannelOnNextBuild = false;
          });
          ref.read(selectedLiveCategoryProvider.notifier).set(activePlayback.categoryId);
        }
        if (GoatPlatform.isTv) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusChannelColumn();
          });
        }
      }
    });

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: null,
      body: Row(
        children: [
          // Left Column: Categories
          if (!_isFullWidth)
            Expanded(
              flex: GoatPlatform.isTv ? 24 : 20,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: GoatPlatform.isTv ? 4.0 : 8.0),
                      child: TvTextField(
                        focusNode: _searchFocusNode,
                        controller: _searchController,
                        style: TextStyle(fontSize: GoatPlatform.isTv ? 12 : 14),
                        hintText: 'Suchen...',
                        hintStyle: TextStyle(fontSize: GoatPlatform.isTv ? 12 : 14, color: Colors.white54),
                        prefixIcon: Icon(Icons.search, size: GoatPlatform.isTv ? 16 : 22, color: const Color(0xFFB388FF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: GoatPlatform.isTv ? 4 : 12),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                icon: Icon(Icons.close, size: GoatPlatform.isTv ? 16 : 20),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent || event is KeyRepeatEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
                                _firstCategoryNode.requestFocus();
                              } else {
                                _focusCategoryColumn();
                              }
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              final headerSearch = ref.read(headerSearchFocusNodeProvider);
                              if (headerSearch != null && headerSearch.context != null && headerSearch.canRequestFocus) {
                                headerSearch.requestFocus();
                                return KeyEventResult.handled;
                              }
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              final headerSearch = ref.read(headerSearchFocusNodeProvider);
                              if (headerSearch != null && headerSearch.context != null && headerSearch.canRequestFocus) {
                                headerSearch.requestFocus();
                                return KeyEventResult.handled;
                              }
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              final sidebarFocus = ref.read(activeSidebarFocusNodeProvider);
                              if (sidebarFocus != null && sidebarFocus.context != null && sidebarFocus.canRequestFocus) {
                                sidebarFocus.requestFocus();
                                return KeyEventResult.handled;
                              }
                            } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                                event.logicalKey == LogicalKeyboardKey.goBack) {
                              if (_searchController.text.isNotEmpty) {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                                return KeyEventResult.handled;
                              }
                              if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
                                _firstCategoryNode.requestFocus();
                              } else {
                                _focusCategoryColumn();
                              }
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        onSubmitted: (_) {
                          if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
                            _firstCategoryNode.requestFocus();
                          } else {
                            _focusCategoryColumn();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ref.watch(liveCategoriesProvider).when(
                        data: (rawCategories) {
                          var categories = rawCategories;
                          if (_searchQuery.isNotEmpty) {
                            categories = categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                          }
                          if (!GoatPlatform.isTv && _selectedCategory != null && _selectedCategory != _lastCategoryRailScrolledId) {
                            _scrollToActiveCategory(categories, _selectedCategory);
                          }
                          return ListView.builder(
                            controller: _categoryScrollController,
                            cacheExtent: GoatPlatform.isTv ? 3000.0 : 500.0,
                            itemExtent: GoatPlatform.isTv ? 36.0 : 46.0,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategory == cat.categoryId;
                              final isFavorites = cat.categoryId == 'favorites';

                              final itemNode = index == 0
                                  ? _firstCategoryNode
                                  : _categoryFocusNodes.putIfAbsent(
                                      cat.categoryId,
                                      () => FocusNode(debugLabel: 'cat_${cat.categoryId}'),
                                    );
                              if (index == 0) {
                                _categoryFocusNodes[cat.categoryId] = _firstCategoryNode;
                              }
                              if (isSelected && itemNode.context != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) ref.read(activeCategoryFocusNodeProvider.notifier).set(itemNode);
                                });
                              }

                              return Padding(
                                key: ValueKey(cat.categoryId),
                                padding: EdgeInsets.symmetric(
                                  horizontal: GoatPlatform.isTv ? 4 : 6,
                                  vertical: GoatPlatform.isTv ? 1.5 : 2,
                                ),
                                child: TvFocusable(
                                  focusNode: itemNode,
                                  autofocus: false,
                                  focusScale: 1.02,
                                  borderRadius: BorderRadius.circular(8),
                                  onFocusChange: (has) {
                                    if (has) {
                                      ref.read(activeCategoryFocusNodeProvider.notifier).set(itemNode);
                                    }
                                  },
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                        if (_selectedCategory != cat.categoryId) {
                                          _focusFirstChannelOnNextBuild = true;
                                          _selectCategory(cat.categoryId);
                                        } else {
                                          _focusChannelColumn();
                                        }
                                        return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                        final sidebarFocus = ref.read(activeSidebarFocusNodeProvider);
                                        if (sidebarFocus != null && sidebarFocus.context != null && sidebarFocus.canRequestFocus) {
                                          sidebarFocus.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                                        _searchFocusNode.requestFocus();
                                        return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && index >= categories.length - 1) {
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  onPressed: () => _selectCategory(cat.categoryId),
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: GoatPlatform.isTv ? 8 : 10,
                                      vertical: GoatPlatform.isTv ? 4 : 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isFavorites
                                              ? (isSelected ? Icons.star_rounded : Icons.star_outline_rounded)
                                              : (isSelected ? Icons.tv : Icons.folder_outlined),
                                          size: GoatPlatform.isTv ? 15 : 18,
                                          color: isFavorites
                                              ? Colors.amber
                                              : (isSelected ? const Color(0xFFB388FF) : Colors.white54),
                                        ),
                                        SizedBox(width: GoatPlatform.isTv ? 8 : 10),
                                        Expanded(
                                          child: Text(
                                            isFavorites ? AppLocalizations.of(context)!.favorites : cat.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white70,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              fontSize: GoatPlatform.isTv ? 11.5 : 13.5,
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

          // Middle Column: Channels in Category
          if (!_isFullWidth)
            Expanded(
              flex: GoatPlatform.isTv ? 38 : 35,
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
                        final isSyncing = ref.watch(syncingCategoriesProvider).contains(_selectedCategory);
                        final hasSynced = _syncedCategories.contains(_selectedCategory);
                        if (streams.isEmpty) {
                          if (isSyncing || (!hasSynced && _selectedCategory != 'favorites')) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: Color(0xFF7C3AED)),
                                  SizedBox(height: 16),
                                  Text('Loading channels...', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            );
                          }
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
                        final currentPrograms = GoatPlatform.isTv
                            ? (ref.watch(currentProgramsMapProvider).asData?.value ?? const <String, EpgProgram>{})
                            : const <String, EpgProgram>{};
                        final account = ref.read(activeAccountProvider);
                        final baseUrl = account?.serverUrl.endsWith('/') == true ? account!.serverUrl.substring(0, account.serverUrl.length - 1) : account?.serverUrl;

                        final channelListView = ListView.builder(
                          controller: _channelScrollController,
                          cacheExtent: GoatPlatform.isTv ? 1500.0 : 500.0,
                          itemExtent: GoatPlatform.isTv ? 48.0 : 64.0,
                          itemCount: streams.length,
                          itemBuilder: (context, index) {
                            final stream = streams[index];
                            final ext = GoatPlatform.isWeb ? 'm3u8' : 'ts';
                            final url = (stream.url != null && stream.url!.startsWith('http'))
                                ? stream.url!
                                : '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.$ext';
                            final cleanName = ChannelNameCleaner.clean(stream.name);
                            final isFavorite = favoriteIds.contains(stream.streamId);
                            final isCurrentPlaying = (activePlayback?.streamId != null && activePlayback!.streamId == stream.streamId) ||
                                (currentLive?.streamId != null && currentLive!.streamId == stream.streamId) ||
                                currentLive?.streamUrl == url ||
                                activePlayback?.streamUrl == url;
                            final epgId = (stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty)
                                ? stream.epgChannelId!
                                : stream.streamId;
                            final currentProg = currentPrograms[epgId];

                            final itemFocusNode = index == 0
                                ? _firstChannelNode
                                : (GoatPlatform.isTv
                                    ? _channelFocusNodes.putIfAbsent(
                                        stream.streamId,
                                        () => FocusNode(debugLabel: 'ch_${stream.streamId}'),
                                      )
                                    : null);
                            if (index == 0 && GoatPlatform.isTv) {
                               _channelFocusNodes[stream.streamId] = _firstChannelNode;
                            }

                            if (index == 0 && _focusFirstChannelOnNextBuild) {
                              _focusFirstChannelOnNextBuild = false;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _firstChannelNode.requestFocus();
                                }
                              });
                            }

                            return Padding(
                              key: ValueKey(stream.streamId),
                              padding: EdgeInsets.symmetric(
                                horizontal: GoatPlatform.isTv ? 6 : 8,
                                vertical: GoatPlatform.isTv ? 2 : 3,
                              ),
                              child: TvFocusable(
                                focusNode: itemFocusNode,
                                focusScale: 1.02,
                                borderRadius: BorderRadius.circular(10),
                                onPressed: () => _playStream(stream),
                                onLongPress: () => _handleChannelLongPress(stream),
                                onFocusChange: (hasF) {
                                  if (hasF) {
                                    _lastFocusedChannelNode = itemFocusNode;
                                  }
                                },
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                      final activeCatId = _selectedCategory;
                                      if (activeCatId != null && _categoryFocusNodes.containsKey(activeCatId)) {
                                        final catNode = _categoryFocusNodes[activeCatId];
                                        if (catNode != null && catNode.context != null && catNode.canRequestFocus) {
                                          catNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      _focusCategoryColumn();
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                      if (_isFullWidth) return KeyEventResult.handled;
                                      final activePlayback = ref.read(playbackControllerProvider);
                                      final isPlaying = activePlayback != null && activePlayback.streamType == StreamType.live;
                                      if (isPlaying && _playerNode.context != null && _playerNode.canRequestFocus) {
                                        _playerNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && index >= streams.length - 1) {
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                                      final headerSearch = ref.read(headerSearchFocusNodeProvider);
                                      if (headerSearch != null && headerSearch.context != null && headerSearch.canRequestFocus) {
                                        headerSearch.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.handled;
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: GoatPlatform.isTv ? 8 : 10,
                                    vertical: GoatPlatform.isTv ? 4 : 6,
                                  ),
                                  child: Row(
                                    children: [
                                      ChannelIcon(
                                        iconUrl: stream.streamIcon,
                                        channelName: cleanName,
                                        size: GoatPlatform.isTv ? 28 : 40,
                                      ),
                                      SizedBox(width: GoatPlatform.isTv ? 8 : 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cleanName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isCurrentPlaying ? Colors.white : Colors.white.withValues(alpha: 0.88),
                                                fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.w500,
                                                fontSize: GoatPlatform.isTv ? 11.5 : 14,
                                              ),
                                            ),
                                            if (GoatPlatform.isTv && currentProg != null && currentProg.title.isNotEmpty) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                currentProg.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isCurrentPlaying ? const Color(0xFFD8B4FE) : Colors.white54,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (GoatPlatform.isTv)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: Icon(
                                            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 16,
                                            color: isFavorite ? Colors.amber : Colors.white24,
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(
                                            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 22,
                                          ),
                                          color: isFavorite ? Colors.amber : Colors.white38,
                                          onPressed: () => _toggleFavorite(stream),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );

                        if (GoatPlatform.isTv) {
                          final isDe = Localizations.localeOf(context).languageCode == 'de';
                          return Column(
                            children: [
                              Expanded(child: channelListView),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF140E24),
                                  border: Border(top: BorderSide(color: Colors.white12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isDe ? 'OK: Vorschau / 2× Vollbild  ·  Halten:' : 'OK: Preview / 2× Fullscreen  ·  Hold:',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    for (final e in [
                                      (const Color(0xFFFACC15), isDe ? 'Favorit' : 'Fav'),
                                      (const Color(0xFF22C55E), 'EPG'),
                                      (const Color(0xFF3B82F6), isDe ? 'Gruppen' : 'Groups'),
                                    ]) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(color: e.$1, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(e.$2, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return channelListView;
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.error}$err')),
                    ),
            ),
          
          if (!_isFullWidth)
            const VerticalDivider(width: 1, thickness: 1),

          // Right Column: Player & EPG
          Expanded(
            flex: _isFullWidth ? 100 : (GoatPlatform.isTv ? 38 : 45),
            child: Column(
              children: [
                Expanded(
                  flex: _isFullWidth ? 100 : 50,
                  child: currentLive != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPreview(
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
                                if (_isFullWidth) {
                                  ref.read(isLiveFullWidthProvider.notifier).set(false);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _focusChannelColumn();
                                  });
                                }
                              },
                            ),
                            if (GoatPlatform.isTv && !_isFullWidth)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: TvFocusable(
                                    focusNode: _playerNode,
                                    borderRadius: BorderRadius.circular(12),
                                    focusScale: 1.0,
                                    focusBorderColor: const Color(0xFFB388FF),
                                    glowColor: const Color(0x33B388FF),
                                    onPressed: () {
                                      _playerNode.unfocus();
                                      ref.read(isLiveFullWidthProvider.notifier).set(true);
                                    },
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                          _focusChannelColumn();
                                          return KeyEventResult.handled;
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          final headerSearch = ref.read(headerSearchFocusNodeProvider);
                                          if (headerSearch != null && headerSearch.context != null && headerSearch.canRequestFocus) {
                                            headerSearch.requestFocus();
                                            return KeyEventResult.handled;
                                          }
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                                            event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: Colors.black45,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tv, size: GoatPlatform.isTv ? 40 : 64, color: Colors.white24),
                                const SizedBox(height: 12),
                                Text(AppLocalizations.of(context)!.selectChannel, style: TextStyle(color: Colors.white54, fontSize: GoatPlatform.isTv ? 12 : 14)),
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
                    padding: EdgeInsets.all(GoatPlatform.isTv ? 10.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.epgSchedule,
                          style: TextStyle(
                            fontSize: GoatPlatform.isTv ? 14 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: GoatPlatform.isTv ? 8 : 16),
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

