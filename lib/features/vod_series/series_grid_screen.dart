import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'series_detail_modal.dart';
import 'series_controller.dart';
import '../dashboard/widgets/continue_watching_rail.dart';
import '../dashboard/dashboard_state.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/tv_text_field.dart';
import '../../core/utils/platform_utils.dart';

class SeriesGridScreen extends ConsumerStatefulWidget {
  const SeriesGridScreen({super.key});

  @override
  ConsumerState<SeriesGridScreen> createState() => _SeriesGridScreenState();
}

class _SeriesGridScreenState extends ConsumerState<SeriesGridScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  String _catSearchQuery = '';
  final _searchController = TextEditingController();
  final _catSearchController = TextEditingController();
  final ScrollController _seriesScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final FocusNode _firstSeriesNode = FocusNode(debugLabel: 'first_series');
  final FocusNode _firstRailItemNode = FocusNode(debugLabel: 'series_first_rail_item');
  final FocusNode _firstCategoryNode = FocusNode(debugLabel: 'series_first_category');
  final FocusNode _catSearchFocusNode = FocusNode(debugLabel: 'series_cat_search');
  final FocusNode _topSearchFocusNode = FocusNode(debugLabel: 'series_top_search');
  final Map<String, FocusNode> _categoryFocusNodes = {};
  final Map<int, FocusNode> _seriesFocusNodes = {};
  String _sortMode = 'default'; // default, asc, desc

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeScreenSearchFocusNodeProvider.notifier).set(null);
      ref.read(activeCategoryFocusNodeProvider.notifier).set(null);
    });
    _searchController.dispose();
    _catSearchController.dispose();
    _seriesScrollController.dispose();
    _categoryScrollController.dispose();
    _firstSeriesNode.dispose();
    _firstRailItemNode.dispose();
    _firstCategoryNode.dispose();
    _catSearchFocusNode.dispose();
    _topSearchFocusNode.dispose();
    for (final node in _categoryFocusNodes.values) {
      node.dispose();
    }
    for (final node in _seriesFocusNodes.values) {
      node.dispose();
    }
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
  }

  void _showTvSortDialog(AppLocalizations l10n) {
    final options = [
      ('default', l10n.defaultAdded),
      ('asc', l10n.aToZ),
      ('desc', l10n.zToA),
    ];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1730),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.sortSeries,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                for (final opt in options) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TvFocusable(
                      autofocus: _sortMode == opt.$1,
                      borderRadius: BorderRadius.circular(10),
                      onPressed: () {
                        setState(() => _sortMode = opt.$1);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _sortMode == opt.$1
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                              : const Color(0xFF161124),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _sortMode == opt.$1 ? const Color(0xFFB388FF) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                opt.$2,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: _sortMode == opt.$1 ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_sortMode == opt.$1)
                              const Icon(Icons.check_circle, size: 18, color: Color(0xFFB388FF)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(activeDashboardTabProvider) == 2) {
        ref.read(activeScreenSearchFocusNodeProvider.notifier).set(_topSearchFocusNode);
        ref.read(activeCategoryFocusNodeProvider.notifier).set(_firstCategoryNode);
      }
    });
    Future.microtask(() {
      ref.read(seriesControllerProvider).syncSeriesCategories();
      if (!GoatPlatform.isTv) {
        ref.read(seriesControllerProvider).syncAllSeriesStreams();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeDashboardTabProvider, (prev, next) {
      if (next == 2 && mounted) {
        ref.read(activeScreenSearchFocusNodeProvider.notifier).set(_topSearchFocusNode);
        ref.read(activeCategoryFocusNodeProvider.notifier).set(_firstCategoryNode);
      }
    });

    ref.listen(dashboardTabResetProvider, (_, __) {
      if (ref.read(activeDashboardTabProvider) == 2 && mounted) {
        ref.read(activeScreenSearchFocusNodeProvider.notifier).set(_topSearchFocusNode);
        ref.read(activeCategoryFocusNodeProvider.notifier).set(_firstCategoryNode);
      }
      _searchController.clear();
      _catSearchController.clear();
      if (mounted) {
        setState(() {
          _searchQuery = '';
          _catSearchQuery = '';
          _selectedCategory = null;
        });
        if (_seriesScrollController.hasClients) {
          _seriesScrollController.jumpTo(0);
        }
        if (_categoryScrollController.hasClients) {
          _categoryScrollController.jumpTo(0);
        }
      }
    });

    final l10n = AppLocalizations.of(context)!;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = (constraints.maxWidth > 800 && !GoatPlatform.isPhone) || GoatPlatform.isTv;
          
          final hasSearch = _searchQuery.trim().isNotEmpty;
          final provider = hasSearch 
              ? seriesSearchProvider(_searchQuery.trim())
              : (_selectedCategory == null ? null : seriesStreamsProvider(_selectedCategory!));

          final gridAreaWidth = isDesktop ? (constraints.maxWidth * (80 / (GoatPlatform.isTv ? 104 : 100))) - 20 : constraints.maxWidth - 32;
          final maxExtent = GoatPlatform.isTv ? 130.0 : (isDesktop ? 200.0 : 150.0);
          final spacing = GoatPlatform.isTv ? 10.0 : 16.0;
          final crossAxisCount = ((gridAreaWidth + spacing) / (maxExtent + spacing)).ceil().clamp(1, 20);

          final content = provider == null
              ? Column(
                  children: [
                    if (GoatPlatform.isTv && _searchQuery.isEmpty)
                      ContinueWatchingRail(
                        type: 'series',
                        onExitLeft: GoatPlatform.isTv ? _focusCategoryColumn : null,
                        firstItemFocusNode: GoatPlatform.isTv ? _firstRailItemNode : null,
                      ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_library, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.selectCategoryOrSearch, style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                      return CustomScrollView(
                        controller: _seriesScrollController,
                        slivers: [
                          if (_searchQuery.isEmpty)
                            SliverToBoxAdapter(
                              child: ContinueWatchingRail(
                                type: 'series',
                                onExitLeft: GoatPlatform.isTv ? _focusCategoryColumn : null,
                                firstItemFocusNode: GoatPlatform.isTv ? _firstRailItemNode : null,
                              ),
                            ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                    _focusCategoryColumn();
                                    return KeyEventResult.handled;
                                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                    if (_firstRailItemNode.context != null && _firstRailItemNode.canRequestFocus) {
                                      _firstRailItemNode.requestFocus();
                                    } else {
                                      _topSearchFocusNode.requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                                      event.logicalKey == LogicalKeyboardKey.goBack) {
                                    _focusCategoryColumn();
                                    return KeyEventResult.handled;
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search_off, size: 64, color: Colors.white24),
                                    const SizedBox(height: 16),
                                    Text(AppLocalizations.of(context)!.noSeriesFound, style: const TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return CustomScrollView(
                      controller: _seriesScrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (_searchQuery.isEmpty)
                          SliverToBoxAdapter(
                            child: ContinueWatchingRail(
                              type: 'series',
                              onExitLeft: GoatPlatform.isTv ? _focusCategoryColumn : null,
                              firstItemFocusNode: GoatPlatform.isTv ? _firstRailItemNode : null,
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.all(GoatPlatform.isTv ? 10 : 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: maxExtent,
                              childAspectRatio: 2 / 3,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final stream = streams[index];
                                final isLeftmostColumn = index % crossAxisCount == 0;
                                final isRightmostColumn = (index + 1) % crossAxisCount == 0;
                                final cardNode = _seriesFocusNodes.putIfAbsent(
                                  index,
                                  () => index == 0 ? _firstSeriesNode : FocusNode(debugLabel: 'series_card_$index'),
                                );
                                return TvFocusable(
                                  key: ValueKey('series_${stream.streamId}'),
                                  focusNode: cardNode,
                                  focusScale: 1.03,
                                  borderRadius: BorderRadius.circular(12),
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                      // VOD Grid Leftmost Column Boundary Exit to Active Category
                                      if (GoatPlatform.isTv &&
                                          isLeftmostColumn &&
                                          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                        _focusCategoryColumn();
                                        return KeyEventResult.handled;
                                      }
                                      // VOD Grid Rightmost Column Wrap to First Element of Next Row
                                      if (GoatPlatform.isTv &&
                                          isRightmostColumn &&
                                          event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                        if (index + 1 < streams.length) {
                                          final nextNode = _seriesFocusNodes.putIfAbsent(
                                            index + 1,
                                            () => FocusNode(debugLabel: 'series_card_${index + 1}'),
                                          );
                                          nextNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                                          index >= streams.length - (isDesktop ? crossAxisCount : 3)) {
                                        _seriesScrollController.jumpTo(0);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _firstSeriesNode.requestFocus();
                                        });
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
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
            final sortLabel = _sortMode == 'asc'
                ? l10n.aToZ
                : (_sortMode == 'desc' ? l10n.zToA : l10n.defaultAdded);

            return Scaffold(
              appBar: AppBar(
                toolbarHeight: GoatPlatform.isTv ? 52 : null,
                title: Row(
                  children: [
                    Text(
                      l10n.series,
                      style: TextStyle(fontSize: GoatPlatform.isTv ? 15 : null),
                    ),
                    SizedBox(width: GoatPlatform.isTv ? 16 : 24),
                    Expanded(
                      child: TvTextField(
                        focusNode: _topSearchFocusNode,
                        controller: _searchController,
                        style: TextStyle(fontSize: GoatPlatform.isTv ? 13 : 14),
                        hintText: l10n.searchSeries,
                        hintStyle: TextStyle(fontSize: GoatPlatform.isTv ? 13 : 14, color: Colors.white54),
                        prefixIcon: Icon(Icons.search, size: GoatPlatform.isTv ? 18 : 22, color: const Color(0xFFB388FF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: GoatPlatform.isTv ? 6 : 12),
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
                              if (_catSearchFocusNode.context != null && _catSearchFocusNode.canRequestFocus) {
                                _catSearchFocusNode.requestFocus();
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
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              if (_searchController.text.isEmpty || _searchController.selection.extentOffset <= 0) {
                                _focusCategoryColumn();
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
                              _focusCategoryColumn();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        onSubmitted: (_) {
                          if (_catSearchFocusNode.context != null && _catSearchFocusNode.canRequestFocus) {
                            _catSearchFocusNode.requestFocus();
                          } else {
                            _focusCategoryColumn();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (GoatPlatform.isTv)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: TvFocusable(
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => _showTvSortDialog(l10n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 16, color: Color(0xFFB388FF)),
                              const SizedBox(width: 6),
                              Text(
                                sortLabel,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, size: 24),
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
                ],
              ),
              body: Row(
                children: [
                  Expanded(
                    flex: GoatPlatform.isTv ? 24 : 20,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      child: Column(
                        children: [
                          if (GoatPlatform.isTv)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: TvTextField(
                                focusNode: _catSearchFocusNode,
                                controller: _catSearchController,
                                style: const TextStyle(fontSize: 12),
                                hintText: 'Suchen...',
                                hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFFB388FF)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                suffixIcon: _catSearchController.text.isNotEmpty
                                    ? IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _catSearchController.clear();
                                            _catSearchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                isDense: true,
                                onChanged: (val) => setState(() => _catSearchQuery = val),
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                      if (_categoryScrollController.hasClients && _categoryScrollController.offset > 0) {
                                        _categoryScrollController.jumpTo(0.0);
                                      }
                                      if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
                                        _firstCategoryNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      final favNode = _categoryFocusNodes['favorites'];
                                      if (favNode != null && favNode.context != null && favNode.canRequestFocus) {
                                        favNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      for (final n in _categoryFocusNodes.values) {
                                        if (n.context != null && n.canRequestFocus) {
                                          n.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                      if (_topSearchFocusNode.context != null && _topSearchFocusNode.canRequestFocus) {
                                        _topSearchFocusNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                      final sidebarFocus = ref.read(activeSidebarFocusNodeProvider);
                                      if (sidebarFocus != null && sidebarFocus.context != null && sidebarFocus.canRequestFocus) {
                                        sidebarFocus.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                      if (_firstRailItemNode.context != null && _firstRailItemNode.canRequestFocus) {
                                        _firstRailItemNode.requestFocus();
                                        return KeyEventResult.handled;
                                      } else if (_firstSeriesNode.context != null && _firstSeriesNode.canRequestFocus) {
                                        _firstSeriesNode.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.handled;
                                    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                                        event.logicalKey == LogicalKeyboardKey.goBack) {
                                      if (_catSearchController.text.isNotEmpty) {
                                        setState(() {
                                          _catSearchController.clear();
                                          _catSearchQuery = '';
                                        });
                                        return KeyEventResult.handled;
                                      }
                                      _focusCategoryColumn();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                onSubmitted: (_) {
                                  if (_categoryScrollController.hasClients && _categoryScrollController.offset > 0) {
                                    _categoryScrollController.jumpTo(0.0);
                                  }
                                  if (_firstCategoryNode.context != null && _firstCategoryNode.canRequestFocus) {
                                    _firstCategoryNode.requestFocus();
                                  } else {
                                    _focusCategoryColumn();
                                  }
                                },
                              ),
                            ),
                          Expanded(
                            child: ref.watch(seriesCategoriesProvider).when(
                              data: (rawCategories) {
                                var categories = rawCategories;
                                if (GoatPlatform.isTv && _catSearchQuery.isNotEmpty) {
                                  categories = categories
                                      .where((c) => c.name.toLowerCase().contains(_catSearchQuery.toLowerCase()))
                                      .toList();
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
                                        : (GoatPlatform.isTv
                                            ? _categoryFocusNodes.putIfAbsent(
                                                cat.categoryId,
                                                () => FocusNode(debugLabel: 'scat_${cat.categoryId}'),
                                              )
                                            : null);
                                    if (index == 0) {
                                      _categoryFocusNodes[cat.categoryId] = _firstCategoryNode;
                                    }

                                    return Padding(
                                      key: ValueKey(cat.categoryId),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: GoatPlatform.isTv ? 4 : 6,
                                        vertical: GoatPlatform.isTv ? 1.5 : 2,
                                      ),
                                      child: TvFocusable(
                                        focusNode: itemNode,
                                        focusScale: 1.02,
                                        borderRadius: BorderRadius.circular(8),
                                        onFocusChange: (has) {
                                          if (has && itemNode != null) {
                                            ref.read(activeCategoryFocusNodeProvider.notifier).set(itemNode);
                                          }
                                        },
                                        onKeyEvent: GoatPlatform.isTv
                                            ? (n, event) {
                                                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                                                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                                    if (_firstRailItemNode.context != null && _firstRailItemNode.canRequestFocus) {
                                                      _firstRailItemNode.requestFocus();
                                                      return KeyEventResult.handled;
                                                    } else if (_firstSeriesNode.context != null && _firstSeriesNode.canRequestFocus) {
                                                      _firstSeriesNode.requestFocus();
                                                      return KeyEventResult.handled;
                                                    }
                                                    return KeyEventResult.handled;
                                                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                                    final sidebarFocus = ref.read(activeSidebarFocusNodeProvider);
                                                    if (sidebarFocus != null && sidebarFocus.context != null && sidebarFocus.canRequestFocus) {
                                                      sidebarFocus.requestFocus();
                                                      return KeyEventResult.handled;
                                                    }
                                                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
                                                    _catSearchFocusNode.requestFocus();
                                                    return KeyEventResult.handled;
                                                  }
                                                }
                                                return KeyEventResult.ignored;
                                              }
                                            : null,
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
                        ],
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
