import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../../core/database/app_database.dart';
import '../vod_movies/vod_controller.dart';
import '../vod_series/series_controller.dart';
import '../live_tv/live_tv_controller.dart';
import '../vod_movies/movie_detail_modal.dart';
import '../vod_series/series_detail_modal.dart';
import '../../main.dart';
import '../../core/player/playback_controller.dart';
import '../../core/utils/channel_name_cleaner.dart';
import '../../core/utils/platform_utils.dart';

class MasterSearchModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final ValueChanged<int>? onSelectTab;

  const MasterSearchModal({
    super.key,
    this.onClose,
    this.onSelectTab,
  });

  @override
  ConsumerState<MasterSearchModal> createState() => _MasterSearchModalState();
}

class _MasterSearchModalState extends ConsumerState<MasterSearchModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _handleBack,
      },
      child: FocusScope(
        child: PopScope(
          canPop: widget.onClose == null,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && widget.onClose != null) {
              widget.onClose!();
            }
          },
          child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Focus(
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
              autofocus: true,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                hintText: '${AppLocalizations.of(context)!.search}...',
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.white54),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.liveTv),
              Tab(text: AppLocalizations.of(context)!.movies),
              Tab(text: AppLocalizations.of(context)!.series),
            ],
          ),
        ),
        body: _query.trim().isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, size: 64, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.typeToSearch, style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildResultsList(liveTvSearchProvider(_query.trim()), 'live'),
                  _buildResultsList(vodSearchProvider(_query.trim()), 'movie'),
                  _buildResultsList(seriesSearchProvider(_query.trim()), 'series'),
                ],
              ),
      ),
        ),
      ),
    );
  }

  Widget _buildResultsList(dynamic provider, String type) {
    final asyncValue = ref.watch(provider) as AsyncValue<List<StreamItem>>;
    return asyncValue.when(
      data: (streams) {
        if (streams.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.noResultsFound, style: const TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            return ListTile(
              leading: stream.streamIcon != null && stream.streamIcon!.isNotEmpty
                  ? Image.network(
                      stream.streamIcon!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      cacheWidth: 100,
                      cacheHeight: 100,
                      errorBuilder: (_,__,___) => const Icon(Icons.tv),
                    )
                  : const Icon(Icons.tv),
              title: Text(stream.name),
              onTap: () {
                if (type == 'movie') {
                  ref.read(selectedLiveStreamProvider.notifier).set(null);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      barrierDismissible: true,
                      barrierColor: Colors.black87,
                      pageBuilder: (context, animation, secondaryAnimation) => MovieDetailModal(
                        movieName: stream.name,
                        streamId: stream.streamId,
                        posterUrl: stream.streamIcon,
                      ),
                    ),
                  );
                } else if (type == 'series') {
                  ref.read(selectedLiveStreamProvider.notifier).set(null);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      barrierDismissible: true,
                      barrierColor: Colors.black87,
                      pageBuilder: (context, animation, secondaryAnimation) => SeriesDetailModal(
                        seriesName: stream.name,
                        seriesId: stream.streamId,
                        coverUrl: stream.streamIcon,
                      ),
                    ),
                  );
                } else if (type == 'live') {
                  final account = ref.read(activeAccountProvider);
                  if (account != null) {
                    final baseUrl = account.serverUrl.endsWith('/') ? account.serverUrl.substring(0, account.serverUrl.length - 1) : account.serverUrl;
                    final ext = GoatPlatform.isWeb ? 'm3u8' : 'ts';
                    final url = '$baseUrl/live/${account.username}/${account.password}/${stream.streamId}.$ext';
                    final epgChannelId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId;
                    ref.read(playbackControllerProvider.notifier).playLive(
                      title: ChannelNameCleaner.clean(stream.name),
                      url: url,
                      channelId: epgChannelId,
                      streamId: stream.streamId,
                      categoryId: stream.categoryId,
                    );
                  }
                  ref.read(selectedLiveCategoryProvider.notifier).set(stream.categoryId);
                  ref.read(selectedLiveStreamProvider.notifier).set(stream);
                  if (widget.onSelectTab != null) {
                    widget.onSelectTab!(0);
                  } else {
                    Navigator.pop(context, 0); // pop MasterSearchModal and switch to Live TV tab
                  }
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('${AppLocalizations.of(context)!.error}$e')),
    );
  }
}
