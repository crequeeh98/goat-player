import 'package:flutter/material.dart';
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
import '../../core/player/playback_controller.dart';
import '../../main.dart';

class DesktopLiveScreen extends ConsumerStatefulWidget {
  const DesktopLiveScreen({super.key});

  @override
  ConsumerState<DesktopLiveScreen> createState() => _DesktopLiveScreenState();
}

class _DesktopLiveScreenState extends ConsumerState<DesktopLiveScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final GlobalKey _videoPreviewKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(liveTvControllerProvider).syncLiveCategories();
      ref.read(epgControllerProvider).syncEpgData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final _isFullWidth = ref.watch(isLiveFullWidthProvider);
    final activePlayback = ref.watch(playbackControllerProvider);
    final currentLive = (activePlayback != null && activePlayback.streamType == StreamType.live) ? activePlayback : null;

    ref.listen<String?>(selectedLiveCategoryProvider, (prev, next) {
      if (next != null && next != _selectedCategory) {
        setState(() {
          _selectedCategory = next;
        });
      }
    });

    ref.listen<StreamItem?>(selectedLiveStreamProvider, (prev, next) {
      if (next != null) {
        final account = ref.read(activeAccountProvider);
        if (account == null) return;
        final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
        final url = '$baseUrl/live/${account.username}/${account.password}/${next.streamId}.ts';
        ref.read(playbackControllerProvider.notifier).playLive(
          title: next.name,
          url: url,
          channelId: next.streamId,
        );
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
                      child: TextField(
                          controller: _searchController,
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
                    Expanded(
                      child: ref.watch(liveCategoriesProvider).when(
                        data: (rawCategories) {
                          var categories = rawCategories;
                          if (_searchQuery.isNotEmpty) {
                            categories = categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                          }
                          return ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              return ListTile(
                                title: Text(cat.categoryId == 'favorites' ? (AppLocalizations.of(context)!.favorites ?? cat.name) : cat.name),
                                selected: _selectedCategory == cat.categoryId,
                                onTap: () {
                                  setState(() => _selectedCategory = cat.categoryId);
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
                        return ListView.builder(
                          itemCount: streams.length,
                          itemBuilder: (context, index) {
                            final stream = streams[index];
                            final account = ref.read(activeAccountProvider);
                            final baseUrl = account?.serverUrl.endsWith('/') == true ? account!.serverUrl.substring(0, account.serverUrl.length - 1) : account?.serverUrl;
                            final url = '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.ts';
                            
                            final cleanName = ChannelNameCleaner.clean(stream.name);
                            
                            return ListTile(
                              leading: ChannelIcon(
                                iconUrl: stream.streamIcon,
                                channelName: cleanName,
                              ),
                              title: Text(cleanName),
                              trailing: Consumer(
                                builder: (context, ref, child) {
                                  final isFavorite = ref.watch(isFavoriteProvider(FavoriteQuery(streamId: stream.streamId, streamType: 'live'))).value ?? false;
                                  return IconButton(
                                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                                    color: isFavorite ? Colors.red : null,
                                    onPressed: () async {
                                      final account = ref.read(activeAccountProvider);
                                      if (account != null) {
                                        await ref.read(databaseProvider).favoriteDao.toggleFavorite(account.id, stream.streamId, 'live');
                                      }
                                    },
                                  );
                                },
                              ),
                              selected: currentLive?.streamUrl == url,
                              onTap: () {
                                ref.read(playbackControllerProvider.notifier).playLive(
                                  title: cleanName,
                                  url: url,
                                  channelId: stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId,
                                );
                              },
                            );
                          },
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
                          channelId: currentLive.channelId,
                          channelName: currentLive.title,
                          isFullWidth: _isFullWidth,
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

