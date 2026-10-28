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
import '../live_tv/mobile_live_view.dart';
import '../../main.dart';
import '../../core/player/playback_controller.dart';
import '../../core/utils/channel_name_cleaner.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/tv_text_field.dart';

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
  final FocusScopeNode _searchScopeNode = FocusScopeNode(debugLabel: 'MasterSearchScope');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'MasterSearchInput');
  final List<FocusNode> _firstResultFocusNodes = [
    FocusNode(debugLabel: 'result_tab_0'),
    FocusNode(debugLabel: 'result_tab_1'),
    FocusNode(debugLabel: 'result_tab_2'),
  ];
  final List<FocusNode> _tabNodes = [
    FocusNode(debugLabel: 'search_tab_0'),
    FocusNode(debugLabel: 'search_tab_1'),
    FocusNode(debugLabel: 'search_tab_2'),
  ];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchScopeNode.dispose();
    _searchFocusNode.dispose();
    for (final node in _firstResultFocusNodes) {
      node.dispose();
    }
    for (final node in _tabNodes) {
      node.dispose();
    }
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
        const SingleActivator(LogicalKeyboardKey.goBack): _handleBack,
      },
      child: FocusScope(
        node: _searchScopeNode,
        autofocus: true,
        child: PopScope(
          canPop: widget.onClose == null,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && widget.onClose != null) {
              widget.onClose!();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F0817),
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: const Color(0xFF160D27),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: TvTextField(
            focusNode: _searchFocusNode,
            controller: _searchController,
            autofocus: true,
            hintText: '${AppLocalizations.of(context)!.search}...',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
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
            onChanged: (val) => setState(() => _query = val),
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _tabNodes[_tabController.index].requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (_tabController.index < 2) {
                    _tabController.animateTo(_tabController.index + 1);
                    _tabNodes[_tabController.index + 1].requestFocus();
                    return KeyEventResult.handled;
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  if (_tabController.index > 0) {
                    _tabController.animateTo(_tabController.index - 1);
                    _tabNodes[_tabController.index - 1].requestFocus();
                    return KeyEventResult.handled;
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                    event.logicalKey == LogicalKeyboardKey.goBack) {
                  _handleBack();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            onSubmitted: (_) {
              final activeResultNode = _firstResultFocusNodes[_tabController.index];
              if (activeResultNode.context != null && activeResultNode.canRequestFocus) {
                activeResultNode.requestFocus();
              } else {
                _tabNodes[_tabController.index].requestFocus();
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildSearchTab(0, AppLocalizations.of(context)!.liveTv, Icons.live_tv),
                  const SizedBox(width: 8),
                  _buildSearchTab(1, AppLocalizations.of(context)!.movies, Icons.movie_outlined),
                  const SizedBox(width: 8),
                  _buildSearchTab(2, AppLocalizations.of(context)!.series, Icons.tv),
                ],
              ),
            ),
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
                  _buildResultsList(liveTvSearchProvider(_query.trim()), 'live', 0),
                  _buildResultsList(vodSearchProvider(_query.trim()), 'movie', 1),
                  _buildResultsList(seriesSearchProvider(_query.trim()), 'series', 2),
                ],
              ),
      ),
        ),
      ),
    );
  }

  Widget _buildResultsList(dynamic provider, String type, int tabIndex) {
    final asyncValue = ref.watch(provider) as AsyncValue<List<StreamItem>>;
    return asyncValue.when(
      data: (streams) {
        if (streams.isEmpty) {
          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowRight && _tabController.index < 2) {
                  _tabController.animateTo(_tabController.index + 1);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _tabController.index > 0) {
                  _tabController.animateTo(_tabController.index - 1);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _searchFocusNode.requestFocus();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                    event.logicalKey == LogicalKeyboardKey.goBack) {
                  _handleBack();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 54, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.noResultsFound, style: const TextStyle(color: Colors.white54, fontSize: 15)),
                  if (GoatPlatform.isTv) ...[
                    const SizedBox(height: 12),
                    Text(
                      _tabController.index == 0
                          ? 'Pfeil Rechts drücken für Filme & Serien'
                          : 'Pfeiltasten Links / Rechts wechseln Tabs',
                      style: const TextStyle(color: Color(0xFFB388FF), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            final itemTile = ListTile(
              dense: GoatPlatform.isTv,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: GoatPlatform.isTv ? 2 : 4),
              leading: stream.streamIcon != null && stream.streamIcon!.isNotEmpty
                  ? Image.network(
                      stream.streamIcon!,
                      width: GoatPlatform.isTv ? 34 : 50,
                      height: GoatPlatform.isTv ? 34 : 50,
                      fit: BoxFit.cover,
                      cacheWidth: GoatPlatform.isTv ? 68 : 100,
                      cacheHeight: GoatPlatform.isTv ? 68 : 100,
                      errorBuilder: (_,__,___) => Icon(Icons.tv, size: GoatPlatform.isTv ? 24 : 32),
                    )
                  : Icon(Icons.tv, size: GoatPlatform.isTv ? 24 : 32),
              title: Text(
                type == 'live' ? ChannelNameCleaner.clean(stream.name) : stream.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: GoatPlatform.isTv ? 12.5 : 14,
                ),
              ),
              subtitle: Text(
                type.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: type == 'live' ? Colors.redAccent : Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: GoatPlatform.isTv ? null : () => _handleSelectStream(stream, type),
            );

            if (GoatPlatform.isTv) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TvFocusable(
                  key: ValueKey('${type}_${stream.streamId}'),
                  focusNode: index == 0 ? _firstResultFocusNodes[tabIndex] : null,
                  borderRadius: BorderRadius.circular(10),
                  focusScale: 1.01,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent || event is KeyRepeatEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                        _tabNodes[_tabController.index].requestFocus();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && index >= streams.length - 1) {
                        return KeyEventResult.handled;
                      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        if (_tabController.index > 0) {
                          _tabController.animateTo(_tabController.index - 1);
                        }
                        return KeyEventResult.handled;
                      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        if (_tabController.index < 2) {
                          _tabController.animateTo(_tabController.index + 1);
                        }
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  onPressed: () => _handleSelectStream(stream, type),
                  child: itemTile,
                ),
              );
            }
            return itemTile;
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('${AppLocalizations.of(context)!.error}$e')),
    );
  }

  Widget _buildSearchTab(int index, String title, IconData icon) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: TvFocusable(
        focusNode: _tabNodes[index],
        borderRadius: BorderRadius.circular(10),
        focusScale: 1.02,
        onPressed: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _searchFocusNode.requestFocus();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              final firstResultNode = _firstResultFocusNodes[index];
              if (_query.trim().isNotEmpty &&
                  firstResultNode.context != null &&
                  firstResultNode.canRequestFocus) {
                firstResultNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index > 0) {
              _tabController.animateTo(index - 1);
              _tabNodes[index - 1].requestFocus();
              setState(() {});
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && index < 2) {
              _tabController.animateTo(index + 1);
              _tabNodes[index + 1].requestFocus();
              setState(() {});
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack) {
              _handleBack();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFB388FF) : Colors.white12,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFFB388FF) : Colors.white70),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSelectStream(StreamItem stream, String type) {
    if (type == 'movie') {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          pageBuilder: (context, _, _) => MovieDetailModal(
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
          barrierColor: Colors.black54,
          pageBuilder: (context, _, _) => SeriesDetailModal(
            seriesName: stream.name,
            seriesId: stream.streamId,
            coverUrl: stream.streamIcon,
          ),
        ),
      );
    } else if (type == 'live') {
      final account = ref.read(activeAccountProvider);
      final isMobile = MediaQuery.sizeOf(context).width <= 800;
      final cleanTitle = ChannelNameCleaner.clean(stream.name);
      final baseUrl = account?.serverUrl.endsWith('/') == true
          ? account!.serverUrl.substring(0, account.serverUrl.length - 1)
          : account?.serverUrl;
      final ext = GoatPlatform.isWeb ? 'm3u8' : 'ts';
      final url = (stream.url != null && stream.url!.startsWith('http'))
          ? stream.url!
          : '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.$ext';
      final epgChannelId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId;

      if (isMobile) {
        if (widget.onSelectTab != null) {
          widget.onSelectTab!(0);
        }
        if (widget.onClose != null) {
          widget.onClose!();
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => MobilePlayerScreen(
              streamUrl: url,
              channelId: epgChannelId,
              channelName: cleanTitle,
              streamId: stream.streamId,
              categoryId: stream.categoryId,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return;
      }

      if (account != null) {
        ref.read(playbackControllerProvider.notifier).playLive(
          title: cleanTitle,
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
  }
}
