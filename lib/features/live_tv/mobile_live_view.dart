import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/platform_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'widgets/video_preview.dart';
import 'widgets/epg_timeline.dart';
import 'widgets/channel_icon.dart';
import 'live_tv_controller.dart';
import 'epg_controller.dart';
import '../../core/utils/channel_name_cleaner.dart';
import '../../core/player/playback_controller.dart';
import '../../core/player/widgets/floating_mini_player.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/live_stream_matcher.dart';
import '../../main.dart';
import '../dashboard/dashboard_state.dart';
import '../dashboard/favorites_provider.dart';

class MobileLiveCategoriesScreen extends ConsumerStatefulWidget {
  const MobileLiveCategoriesScreen({super.key});

  @override
  ConsumerState<MobileLiveCategoriesScreen> createState() => _MobileLiveCategoriesScreenState();
}

class _MobileLiveCategoriesScreenState extends ConsumerState<MobileLiveCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!GoatPlatform.isTv) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          ref.read(epgControllerProvider).syncEpgData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dashboardTabResetProvider, (prev, next) {
      _searchController.clear();
      if (mounted) setState(() => _searchQuery = '');
    });

    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        // Dedicated search bar with clear visual container
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchCategories,
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white54),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: Colors.white12),
        Expanded(
          child: ref.watch(liveCategoriesProvider).when(
            data: (rawCategories) {
              var categories = rawCategories;
              if (_searchQuery.trim().isNotEmpty) {
                final q = _searchQuery.trim().toLowerCase();
                categories = categories.where((c) {
                  final name = c.categoryId == 'favorites' ? l10n.favorites : c.name;
                  return name.toLowerCase().contains(q);
                }).toList();
              }
              if (categories.isEmpty) return Center(child: Text(l10n.noCategories));

              return ListView.builder(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isFavorites = cat.categoryId == 'favorites';
                  final displayName = isFavorites ? l10n.favorites : cat.name;

                  return ListTile(
                    leading: Icon(
                      isFavorites ? Icons.star_rounded : Icons.folder_outlined,
                      color: isFavorites ? Colors.amber : Colors.white54,
                      size: isFavorites ? 24 : 20,
                    ),
                    title: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: isFavorites ? FontWeight.bold : FontWeight.normal,
                        color: isFavorites ? Colors.amber : Colors.white,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white38),
                    onTap: () {
                      ref.read(selectedLiveCategoryProvider.notifier).set(cat.categoryId);
                      final account = ref.read(activeAccountProvider);
                      final isM3u = account != null && (account.username.isEmpty || account.serverUrl.contains('.m3u'));
                      if (!isM3u) {
                        ref.read(liveTvControllerProvider).syncLiveStreams(cat.categoryId);
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MobileLiveChannelsScreen(
                            categoryId: cat.categoryId,
                            categoryName: displayName,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}

class MobileLiveChannelsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  
  const MobileLiveChannelsScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  ConsumerState<MobileLiveChannelsScreen> createState() => _MobileLiveChannelsScreenState();
}

class _MobileLiveChannelsScreenState extends ConsumerState<MobileLiveChannelsScreen> {
  String _channelSearchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayCategoryName = widget.categoryId == 'favorites' ? l10n.favorites : widget.categoryName;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '${l10n.search}...',
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _channelSearchQuery = val),
              )
            : Text(displayCategoryName),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _channelSearchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ref.watch(liveStreamsProvider(widget.categoryId)).when(
            data: (rawStreams) {
              var streams = rawStreams;
              if (_channelSearchQuery.trim().isNotEmpty) {
                final query = _channelSearchQuery.trim().toLowerCase();
                streams = streams.where((s) => s.name.toLowerCase().contains(query)).toList();
              }

              if (streams.isEmpty) {
                return Center(child: Text(l10n.noResultsFound));
              }

              final currentPrograms = ref.watch(currentProgramsMapProvider).asData?.value ?? const {};
              final favoriteStreamIds = ref.watch(favoriteStreamIdsProvider('live')).asData?.value ?? const <String>{};
              final activePlayback = ref.watch(playbackControllerProvider);
              final isMiniPlayerVisible = activePlayback != null && activePlayback.isMinimized;
              final now = DateTime.now();
              final bottomPadding = MediaQuery.paddingOf(context).bottom;

              return ListView.builder(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: (isMiniPlayerVisible ? 80 : 16) + bottomPadding,
                ),
                itemCount: streams.length,
                itemBuilder: (context, index) {
                  final stream = streams[index];
                  final account = ref.read(activeAccountProvider);
                  final isFavorite = favoriteStreamIds.contains(stream.streamId);
                  final cleanName = ChannelNameCleaner.clean(stream.name);
                  final epgChannelId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId;
                  
                  final currentProgram = epgChannelId != null ? currentPrograms[epgChannelId] : null;
                  String? currentShowTitle;
                  double? showProgress;
                  
                  if (currentProgram != null) {
                    currentShowTitle = currentProgram.title;
                    final totalMinutes = currentProgram.stopTime.difference(currentProgram.startTime).inMinutes;
                    final elapsedMinutes = now.difference(currentProgram.startTime).inMinutes;
                    if (totalMinutes > 0) {
                      showProgress = (elapsedMinutes / totalMinutes).clamp(0.0, 1.0);
                    }
                  }

                  return ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: ChannelIcon(
                      iconUrl: stream.streamIcon,
                      channelName: cleanName,
                      size: 34,
                    ),
                    title: Text(
                      cleanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: currentShowTitle != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 1),
                              Text(
                                currentShowTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                              if (showProgress != null) ...[
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1.5),
                                  child: LinearProgressIndicator(
                                    value: showProgress,
                                    minHeight: 2.5,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.redAccent : Colors.white38,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          splashRadius: 18,
                          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                          onPressed: () async {
                            if (account != null) {
                              await ref.read(databaseProvider).favoriteDao.toggleFavorite(
                                account.id,
                                stream.streamId,
                                'live',
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.play_circle_outline, color: Colors.white60, size: 22),
                      ],
                    ),
                    onTap: () {
                      final baseUrl = account?.serverUrl.endsWith('/') == true
                          ? account!.serverUrl.substring(0, account.serverUrl.length - 1)
                          : account?.serverUrl;
                      final ext = GoatPlatform.isWeb ? 'm3u8' : 'ts';
                      final url = (stream.url != null && stream.url!.startsWith('http'))
                          ? stream.url!
                          : '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.$ext';
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => MobilePlayerScreen(
                            streamUrl: url,
                            channelId: epgChannelId,
                            channelName: cleanName,
                            streamId: stream.streamId,
                            categoryId: widget.categoryId,
                            categoryName: displayCategoryName,
                            openedFromChannelList: true,
                          ),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('${l10n.error}$err')),
          ),
          if (!GoatPlatform.isWeb && !GoatPlatform.isTv && (ModalRoute.of(context)?.isCurrent ?? true))
            const FloatingMiniPlayer(openedFromChannelList: true),
        ],
      ),
    );
  }
}

class MobilePlayerScreen extends ConsumerStatefulWidget {
  final String streamUrl;
  final String channelName;
  final String? channelId;
  final String? streamId;
  final String? categoryId;
  final String? categoryName;
  final bool openedFromChannelList;
  
  const MobilePlayerScreen({
    super.key,
    required this.streamUrl,
    required this.channelName,
    this.channelId,
    this.streamId,
    this.categoryId,
    this.categoryName,
    this.openedFromChannelList = false,
  });

  @override
  ConsumerState<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends ConsumerState<MobilePlayerScreen> {
  late String _streamUrl;
  late String _channelName;
  String? _channelId;
  String? _streamId;
  String? _categoryId;
  String? _categoryName;
  bool _isFullscreen = false;
  StreamSubscription<String>? _orientationSub;

  @override
  void initState() {
    super.initState();
    _streamUrl = widget.streamUrl;
    _channelName = widget.channelName;
    _channelId = widget.channelId;
    _streamId = widget.streamId;
    _categoryId = widget.categoryId;
    _categoryName = widget.categoryName;

    if (GoatPlatform.isPhone) {
      _orientationSub = GoatPlatform.deviceOrientationStream.listen((orientation) {
        if (!mounted || _isMinimizing) return;
        if (orientation == 'landscapeLeft' || orientation == 'landscapeRight') {
          _setFullscreen(true);
        } else if (orientation == 'portrait') {
          _setFullscreen(false);
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final active = ref.read(playbackControllerProvider);
      if (active == null || active.streamUrl != _streamUrl) {
        ref.read(playbackControllerProvider.notifier).playLive(
          title: _channelName,
          url: _streamUrl,
          channelId: _channelId,
          streamId: _streamId,
          categoryId: _categoryId,
        );
      } else {
        ref.read(playbackControllerProvider.notifier).expand();
      }
    });
  }

  void _setFullscreen(bool full) {
    if (!mounted || _isFullscreen == full) return;
    setState(() {
      _isFullscreen = full;
    });
    if (GoatPlatform.isPhone) {
      if (full) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    }
  }

  void _onSelectStream(StreamItem newStream) {
    final account = ref.read(activeAccountProvider);
    final baseUrl = account?.serverUrl.endsWith('/') == true
        ? account!.serverUrl.substring(0, account.serverUrl.length - 1)
        : account?.serverUrl;
    final ext = GoatPlatform.isWeb ? 'm3u8' : 'ts';
    final url = (newStream.url != null && newStream.url!.startsWith('http'))
        ? newStream.url!
        : '$baseUrl/live/${account?.username}/${account?.password}/${newStream.streamId}.$ext';
    final epgChannelId = newStream.epgChannelId != null && newStream.epgChannelId!.isNotEmpty
        ? newStream.epgChannelId
        : newStream.streamId;
    final cleanName = ChannelNameCleaner.clean(newStream.name);

    setState(() {
      _streamUrl = url;
      _channelName = cleanName;
      _channelId = epgChannelId;
      _streamId = newStream.streamId;
    });

    ref.read(playbackControllerProvider.notifier).playLive(
      title: cleanName,
      url: url,
      channelId: epgChannelId,
      streamId: newStream.streamId,
      categoryId: _categoryId ?? newStream.categoryId,
    );
  }

  @override
  void dispose() {
    _orientationSub?.cancel();
    if (GoatPlatform.isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  bool _isMinimizing = false;

  void _navigateBackToChannelList() {
    final l10n = AppLocalizations.of(context);
    final effectiveCatId = _categoryId ?? ref.read(selectedLiveCategoryProvider);
    final categories = ref.read(liveCategoriesProvider).asData?.value;
    final resolvedCat = categories?.where((c) => c.categoryId == effectiveCatId).firstOrNull;
    final resolvedCategoryName = effectiveCatId == 'favorites'
        ? (l10n?.favorites ?? 'Favoriten')
        : (_categoryName ?? resolvedCat?.name ?? (l10n?.liveTv ?? 'Live TV'));

    if (widget.openedFromChannelList || effectiveCatId == null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MobileLiveChannelsScreen(
            categoryId: effectiveCatId,
            categoryName: resolvedCategoryName,
          ),
        ),
      );
    }
  }

  void _handleMinimize() {
    if (_isMinimizing) return;
    _isMinimizing = true;
    _orientationSub?.cancel();
    if (GoatPlatform.isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    final notifier = ref.read(playbackControllerProvider.notifier);
    notifier.minimize();
    _navigateBackToChannelList();
  }

  void _handleClose() {
    if (_isMinimizing) return;
    _isMinimizing = true;
    _orientationSub?.cancel();
    if (GoatPlatform.isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    final notifier = ref.read(playbackControllerProvider.notifier);
    notifier.stop();
    _navigateBackToChannelList();
  }

  @override
  Widget build(BuildContext context) {
    final favoriteStreamIds = ref.watch(favoriteStreamIdsProvider('live')).asData?.value ?? const <String>{};
    final isFavorite = _streamId != null && favoriteStreamIds.contains(_streamId);
    final account = ref.read(activeAccountProvider);

    final effectiveCatId = _categoryId ?? ref.watch(selectedLiveCategoryProvider);
    final categoryStreams = effectiveCatId != null
        ? ref.watch(liveStreamsProvider(effectiveCatId)).asData?.value
        : null;

    final categories = ref.watch(liveCategoriesProvider).asData?.value;
    final resolvedCat = categories?.where((c) => c.categoryId == effectiveCatId).firstOrNull;
    final resolvedCategoryName = _categoryName ?? resolvedCat?.name;

    final videoWidget = VideoPreview(
      streamUrl: _streamUrl,
      channelId: _channelId,
      channelName: _channelName,
      streamId: _streamId,
      isFullWidth: _isFullscreen,
      onEnsureFullWidth: () => _setFullscreen(true),
      onExitToPreview: () => _setFullscreen(false),
      streams: categoryStreams,
      categoryName: resolvedCategoryName,
      onSelectStream: _onSelectStream,
      onZapPrevious: (categoryStreams != null && categoryStreams.length > 1) ? () {
        final idx = LiveStreamMatcher.indexOf(
          categoryStreams,
          streamId: _streamId,
          channelId: _channelId,
          streamUrl: _streamUrl,
        );
        final prevIdx = (idx != -1) ? (idx - 1 + categoryStreams.length) % categoryStreams.length : categoryStreams.length - 1;
        _onSelectStream(categoryStreams[prevIdx]);
      } : null,
      onZapNext: (categoryStreams != null && categoryStreams.length > 1) ? () {
        final idx = LiveStreamMatcher.indexOf(
          categoryStreams,
          streamId: _streamId,
          channelId: _channelId,
          streamUrl: _streamUrl,
        );
        final nextIdx = (idx != -1) ? (idx + 1) % categoryStreams.length : 0;
        _onSelectStream(categoryStreams[nextIdx]);
      } : null,
      onPullDown: _isFullscreen ? null : _handleMinimize,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isFullscreen) {
          _setFullscreen(false);
        } else {
          _handleMinimize();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isFullscreen
            ? SizedBox.expand(child: videoWidget)
            : SafeArea(
                child: Column(
                  children: [
                    // Top Bar (Inert, no Material 3 scroll tinting or elevation)
                    Container(
                      height: 52,
                      color: Colors.black,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                              tooltip: 'Minimize',
                              onPressed: _handleMinimize,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (_streamId != null)
                              IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.redAccent : Colors.white,
                                ),
                                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                                onPressed: () async {
                                  if (account != null && _streamId != null) {
                                    await ref.read(databaseProvider).favoriteDao.toggleFavorite(
                                      account.id,
                                      _streamId!,
                                      'live',
                                    );
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Close',
                              onPressed: _handleClose,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: videoWidget,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: ClipRect(
                            child: EpgTimelineWidget(channelId: _channelId),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
