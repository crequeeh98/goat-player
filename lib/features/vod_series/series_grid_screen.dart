import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'series_detail_modal.dart';
import 'series_controller.dart';
import '../dashboard/widgets/continue_watching_rail.dart';
import '../dashboard/dashboard_state.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/utils/platform_utils.dart';

class SeriesGridScreen extends ConsumerStatefulWidget {
  const SeriesGridScreen({super.key});

  @override
  ConsumerState<SeriesGridScreen> createState() => _SeriesGridScreenState();
}

class _SeriesGridScreenState extends ConsumerState<SeriesGridScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final ScrollController _seriesScrollController = ScrollController();
  final FocusNode _firstSeriesNode = FocusNode();
  String _sortMode = 'default'; // default, asc, desc

  @override
  void dispose() {
    _searchController.dispose();
    _seriesScrollController.dispose();
    _firstSeriesNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(seriesControllerProvider).syncSeriesCategories();
      if (!GoatPlatform.isTv) {
        ref.read(seriesControllerProvider).syncAllSeriesStreams();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dashboardTabResetProvider, (_, __) {
      _searchController.clear();
      if (mounted) {
        setState(() {
          _searchQuery = '';
          _selectedCategory = null;
        });
        if (_seriesScrollController.hasClients) {
          _seriesScrollController.jumpTo(0);
        }
      }
    });

    final l10n = AppLocalizations.of(context)!;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
          
          final hasSearch = _searchQuery.trim().isNotEmpty;
          final provider = hasSearch 
              ? seriesSearchProvider(_searchQuery.trim())
              : (_selectedCategory == null ? null : seriesStreamsProvider(_selectedCategory!));

          final content = provider == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_library, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.selectCategoryOrSearch, style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : ref.watch(provider).when(
                  data: (rawStreams) {
                    var streams = rawStreams;
                    
                    // Apply in-memory sorting
                    if (_sortMode == 'asc') {
                      streams = List.from(streams)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    } else if (_sortMode == 'desc') {
                      streams = List.from(streams)..sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
                    } else if (_sortMode == 'default') {
                      streams = List.from(streams)..sort((a, b) {
                        final aAdded = a.added ?? 0;
                        final bAdded = b.added ?? 0;
                        if (aAdded != bAdded) {
                          return bAdded.compareTo(aAdded); // Newest added first
                        }
                        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                      });
                    }

                    if (streams.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noSeriesFound, style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                    }

                    return CustomScrollView(
                      controller: _seriesScrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (_searchQuery.isEmpty)
                          const SliverToBoxAdapter(
                            child: ContinueWatchingRail(type: 'series'),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.all(GoatPlatform.isTv ? 10 : 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: GoatPlatform.isTv ? 130 : (isDesktop ? 200 : 150),
                              childAspectRatio: 2 / 3,
                              crossAxisSpacing: GoatPlatform.isTv ? 10 : 16,
                              mainAxisSpacing: GoatPlatform.isTv ? 10 : 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final stream = streams[index];
                                return Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey == LogicalKeyboardKey.arrowDown &&
                                        index >= streams.length - (isDesktop ? 6 : 3)) {
                                      _seriesScrollController.jumpTo(0);
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _firstSeriesNode.requestFocus();
                                      });
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TvFocusable(
                                    focusNode: index == 0 ? _firstSeriesNode : null,
                                    focusScale: 1.03,
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        opaque: false,
                                        barrierDismissible: true,
                                        barrierColor: Colors.black54,
                                        transitionDuration: const Duration(milliseconds: 300),
                                        reverseTransitionDuration: const Duration(milliseconds: 300),
                                        pageBuilder: (context, animation, secondaryAnimation) => SeriesDetailModal(
                                          seriesName: stream.name,
                                          seriesId: stream.streamId,
                                          coverUrl: stream.streamIcon,
                                        ),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return FadeTransition(opacity: animation, child: child);
                                        },
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                        if (stream.streamIcon != null && stream.streamIcon!.isNotEmpty)
                                          Hero(
                                            tag: 'series_${stream.streamId}',
                                            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                              return fromHeroContext.widget;
                                            },
                                            child: Image.network(
                                              stream.streamIcon!, 
                                              fit: BoxFit.cover,
                                              cacheWidth: 200,
                                              cacheHeight: 300,
                                              errorBuilder: (_,__,___) => const Center(child: Icon(Icons.tv, size: 40, color: Colors.grey)),
                                            ),
                                          ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.center,
                                              colors: [
                                                Colors.black.withAlpha(220),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          right: 8,
                                          child: Text(
                                            stream.name,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: GoatPlatform.isTv ? 10.5 : 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                              childCount: streams.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );

          if (isDesktop) {
            return Scaffold(
              appBar: AppBar(
                toolbarHeight: GoatPlatform.isTv ? 46 : null,
                title: Row(
                  children: [
                    Text(
                      l10n.series,
                      style: TextStyle(fontSize: GoatPlatform.isTv ? 15 : null),
                    ),
                    SizedBox(width: GoatPlatform.isTv ? 16 : 24),
                    Expanded(
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
                          style: TextStyle(fontSize: GoatPlatform.isTv ? 12 : 14),
                          decoration: InputDecoration(
                            hintText: l10n.searchSeries,
                            hintStyle: TextStyle(fontSize: GoatPlatform.isTv ? 12 : 14, color: Colors.white54),
                            prefixIcon: Icon(Icons.search, size: GoatPlatform.isTv ? 18 : 22),
                            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, size: GoatPlatform.isTv ? 16 : 20), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: GoatPlatform.isTv ? 6 : 12),
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  PopupMenuButton<String>(
                    icon: Icon(Icons.sort, size: GoatPlatform.isTv ? 20 : 24),
                    tooltip: l10n.sortSeries,
                    onSelected: (val) => setState(() => _sortMode = val),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'default', child: Text(l10n.defaultAdded)),
                      PopupMenuItem(value: 'asc', child: Text(l10n.aToZ)),
                      PopupMenuItem(value: 'desc', child: Text(l10n.zToA)),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Row(
                children: [
                  Expanded(
                    flex: GoatPlatform.isTv ? 24 : 20,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      child: ref.watch(seriesCategoriesProvider).when(
                        data: (categories) {
                          return ListView.builder(
                            itemExtent: GoatPlatform.isTv ? 36.0 : 46.0,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategory == cat.categoryId;
                              final isFavorites = cat.categoryId == 'favorites';

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: GoatPlatform.isTv ? 4 : 6,
                                  vertical: GoatPlatform.isTv ? 1.5 : 2,
                                ),
                                child: TvFocusable(
                                  focusScale: 1.02,
                                  borderRadius: BorderRadius.circular(8),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategory = cat.categoryId;
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                    if (!isFavorites) {
                                      ref.read(seriesControllerProvider).syncSeriesStreams(cat.categoryId);
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
                                            isFavorites ? l10n.favorites : cat.name,
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
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(flex: 80, child: content),
                ],
              ),
            );
          } else {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: l10n.searchSeries,
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
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, color: Colors.white70),
                        tooltip: l10n.sortSeries,
                        onSelected: (val) => setState(() => _sortMode = val),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'default', child: Text(l10n.defaultAdded)),
                          PopupMenuItem(value: 'asc', child: Text(l10n.aToZ)),
                          PopupMenuItem(value: 'desc', child: Text(l10n.zToA)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5, color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ref.watch(seriesCategoriesProvider).when(
                    data: (categories) {
                      if (categories.isEmpty) return Text(l10n.noCategoriesAvailable);
                      
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.category,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
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
                        isExpanded: true,
                        value: _selectedCategory,
                        items: categories.map((cat) {
                          final isFavorites = cat.categoryId == 'favorites';
                          final displayName = isFavorites ? l10n.favorites : cat.name;
                          return DropdownMenuItem(
                            value: cat.categoryId,
                            child: Row(
                              children: [
                                if (isFavorites) ...[
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isFavorites ? Colors.amber : null,
                                      fontWeight: isFavorites ? FontWeight.bold : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _searchController.clear();
                              _searchQuery = '';
                            });
                            if (val != 'favorites') {
                              ref.read(seriesControllerProvider).syncSeriesStreams(val);
                            }
                          }
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => Text('Error: $err'),
                  ),
                ),
                Expanded(child: content),
              ],
            );
          }
        },
      );
  }
}
