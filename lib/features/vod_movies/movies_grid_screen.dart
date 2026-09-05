import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'movie_detail_modal.dart';
import 'vod_controller.dart';
import '../dashboard/widgets/continue_watching_rail.dart';
import '../dashboard/progress_provider.dart';
import '../../core/widgets/tv_focusable.dart';

class MoviesGridScreen extends ConsumerStatefulWidget {
  const MoviesGridScreen({super.key});

  @override
  ConsumerState<MoviesGridScreen> createState() => _MoviesGridScreenState();
}

class _MoviesGridScreenState extends ConsumerState<MoviesGridScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final ScrollController _movieScrollController = ScrollController();
  final FocusNode _firstMovieNode = FocusNode();
  String _sortMode = 'default'; // default, asc, desc

  @override
  void dispose() {
    _searchController.dispose();
    _movieScrollController.dispose();
    _firstMovieNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(vodControllerProvider).syncVodCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(l10n.movies),
            const SizedBox(width: 24),
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
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchMovies,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: AppLocalizations.of(context)!.sortMovies,
            onSelected: (val) => setState(() => _sortMode = val),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'default', child: Text(AppLocalizations.of(context)!.defaultAdded)),
              PopupMenuItem(value: 'asc', child: Text(AppLocalizations.of(context)!.aToZ)),
              PopupMenuItem(value: 'desc', child: Text(AppLocalizations.of(context)!.zToA)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          
          final hasSearch = _searchQuery.trim().isNotEmpty;
          final provider = hasSearch 
              ? vodSearchProvider(_searchQuery.trim())
              : (_selectedCategory == null ? null : vodStreamsProvider(_selectedCategory!));

          final content = provider == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.movie_filter, size: 64, color: Colors.white24),
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
                            Text(AppLocalizations.of(context)!.noMoviesFound, style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                    }

                    final progressAsync = ref.watch(inProgressMoviesProvider);
                    final progressMap = progressAsync.asData?.value != null 
                        ? { for (var item in progressAsync.asData!.value) item.streamId : item }
                        : {};
                        
                    return CustomScrollView(
                      controller: _movieScrollController,
                      slivers: [
                        if (_searchQuery.isEmpty)
                          const SliverToBoxAdapter(
                            child: ContinueWatchingRail(type: 'movie'),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: isDesktop ? 200 : 150,
                              childAspectRatio: 2 / 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final stream = streams[index];
                                final progress = progressMap[stream.streamId];
                                
                                return Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey == LogicalKeyboardKey.arrowDown &&
                                        index >= streams.length - (isDesktop ? 6 : 3)) {
                                      _movieScrollController.jumpTo(0);
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _firstMovieNode.requestFocus();
                                      });
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TvFocusable(
                                    focusNode: index == 0 ? _firstMovieNode : null,
                                    focusScale: 1.03,
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        opaque: false,
                                        barrierDismissible: true,
                                        barrierColor: Colors.black87,
                                        transitionDuration: const Duration(milliseconds: 400),
                                        reverseTransitionDuration: const Duration(milliseconds: 400),
                                        pageBuilder: (context, animation, secondaryAnimation) => MovieDetailModal(
                                          movieName: stream.name,
                                          streamId: stream.streamId,
                                          posterUrl: stream.streamIcon,
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
                                            tag: 'movie_${stream.streamId}',
                                            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                              return fromHeroContext.widget;
                                            },
                                            child: Image.network(
                                              stream.streamIcon!, 
                                              fit: BoxFit.cover,
                                              cacheWidth: 200,
                                              cacheHeight: 300,
                                              errorBuilder: (_,__,___) => const Center(child: Icon(Icons.movie, size: 40, color: Colors.grey)),
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
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        if (progress != null && progress.duration > 0)
                                          Positioned(
                                            bottom: 0, left: 0, right: 0,
                                            child: LinearProgressIndicator(
                                              value: progress.position / progress.duration,
                                              backgroundColor: Colors.black54,
                                              color: Colors.red,
                                              minHeight: 4,
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
            return Row(
              children: [
                Expanded(
                  flex: 20,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    child: ref.watch(vodCategoriesProvider).when(
                      data: (categories) {
                        return ListView.builder(
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
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                  if (!isFavorites) {
                                    ref.read(vodControllerProvider).syncVodStreams(cat.categoryId);
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
                                            : (isSelected ? Icons.movie : Icons.folder_outlined),
                                        size: 18,
                                        color: isFavorites
                                            ? Colors.amber
                                            : (isSelected ? const Color(0xFFB388FF) : Colors.white54),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          cat.name,
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
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(flex: 80, child: content),
              ],
            );
          } else {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ref.watch(vodCategoriesProvider).when(
                    data: (categories) {
                      if (categories.isEmpty) return Text(AppLocalizations.of(context)!.noCategoriesAvailable);
                      
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Category',
                          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        isExpanded: true,
                        value: _selectedCategory,
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat.categoryId,
                            child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                            if (val != 'favorites') {
                              ref.read(vodControllerProvider).syncVodStreams(val);
                            }
                          }
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => Text('Error: '),
                  ),
                ),
                Expanded(child: content),
              ],
            );
          }
        },
      ),
    );
  }
}
