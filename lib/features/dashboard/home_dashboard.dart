import 'dart:io' show exit;
import 'package:flutter/material.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/player/player_service.dart';
import '../live_tv/desktop_live_screen.dart';
import '../live_tv/mobile_live_view.dart';
import '../settings/widgets/vpn_import_dialog.dart';
import '../settings/widgets/playback_settings_dialog.dart';
import '../../core/vpn/wireguard_service.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../vod_movies/movies_grid_screen.dart';
import '../vod_series/series_grid_screen.dart';
import '../account/account_list_screen.dart';
import '../../main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vod_movies/vod_controller.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import '../vod_series/series_controller.dart';
import '../live_tv/live_tv_controller.dart';
import '../../core/settings/locale_controller.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/tv_remote_scope.dart';
import '../../core/player/widgets/floating_mini_player.dart';
import '../../core/player/playback_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'master_search_modal.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  int _selectedIndex = 0;
  bool _isSearchOpen = false;
  bool _wasLiveExpandedBeforeSearch = false;

  void _openSearch() async {
    final active = ref.read(playbackControllerProvider);
    _wasLiveExpandedBeforeSearch = active != null && active.streamType == StreamType.live && !active.isMinimized;
    if (_wasLiveExpandedBeforeSearch) {
      ref.read(playbackControllerProvider.notifier).minimize();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    setState(() => _isSearchOpen = true);
  }

  void _closeSearch() async {
    setState(() => _isSearchOpen = false);
    final active = ref.read(playbackControllerProvider);
    if (_wasLiveExpandedBeforeSearch && _selectedIndex == 0 && active != null && active.streamType == StreamType.live) {
      _wasLiveExpandedBeforeSearch = false;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      ref.read(playbackControllerProvider.notifier).expand();
    } else {
      _wasLiveExpandedBeforeSearch = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Stagger category syncs to keep UI thread and database connection completely snappy
    Future.microtask(() async {
      await ref.read(liveTvControllerProvider).syncLiveCategories();
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      ref.read(vodControllerProvider).syncVodCategories();
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      ref.read(seriesControllerProvider).syncSeriesCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ActivePlayback?>(playbackControllerProvider, (previous, next) {
      if (next != null && (next.streamType == StreamType.movie || next.streamType == StreamType.series)) {
        _wasLiveExpandedBeforeSearch = false;
        if (_isSearchOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isSearchOpen) {
              setState(() {
                _isSearchOpen = false;
                _selectedIndex = next.streamType == StreamType.movie ? 1 : 2;
              });
            }
          });
        }
      }
    });

    final isLiveFullWidth = ref.watch(isLiveFullWidthProvider);
    final hideChrome = (isLiveFullWidth && _selectedIndex == 0) || _isSearchOpen;

    return TvRemoteScope(
      isRoot: true,
      onBackAtRoot: () async {
        // Priority 0: If window is in OS fullscreen, restore windowed/full-width mode
        if (isFullscreen(context)) {
          ref.read(isLiveFullWidthProvider.notifier).set(true);
          toggleFullscreen(context);
          ref.read(isLiveFullWidthProvider.notifier).set(true);
          return;
        }

        // Priority 1: If Live TV is in full-width mode, restore standard 3-column view
        if (ref.read(isLiveFullWidthProvider)) {
          ref.read(isLiveFullWidthProvider.notifier).set(false);
          return;
        }

        // Priority 2: Close active master search modal if open
        if (_isSearchOpen) {
          _closeSearch();
          return;
        }

        // Priority 3: Root Level Exit Confirmation
        final shouldExit = await TvRemoteScope.showTvExitDialog(context);
        if (shouldExit && context.mounted) {
          if (GoatPlatform.isDesktop) {
            exit(0);
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (isFullscreen(context)) {
            ref.read(isLiveFullWidthProvider.notifier).set(true);
            toggleFullscreen(context);
            ref.read(isLiveFullWidthProvider.notifier).set(true);
            return;
          }
          if (ref.read(isLiveFullWidthProvider)) {
            ref.read(isLiveFullWidthProvider.notifier).set(false);
            return;
          }
          if (_isSearchOpen) {
            _closeSearch();
            return;
          }
          final shouldExit = await TvRemoteScope.showTvExitDialog(context);
          if (shouldExit && context.mounted) {
            if (GoatPlatform.isDesktop) {
              exit(0);
            } else {
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
          appBar: hideChrome ? null : AppBar(
            title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo.png', width: 32, height: 32),
            ),
            const SizedBox(width: 12),
            const Text('GOATPlayer'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Theme.of(context).dividerColor,
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppLocalizations.of(context)!.search,
            onPressed: _openSearch,
          ),
          Consumer(
            builder: (context, ref, child) {
              final stageAsync = ref.watch(vpnStageProvider);
              final isConnected = stageAsync.value == VpnStage.connected;
              final localizedStatus = isConnected 
                  ? AppLocalizations.of(context)!.vpnConnected 
                  : AppLocalizations.of(context)!.vpnDisconnected;
                  
              return IconButton(
                icon: Icon(
                  isConnected ? Icons.security : Icons.shield_outlined,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
                tooltip: '${AppLocalizations.of(context)!.vpnStatus}: $localizedStatus',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const VpnImportDialog(),
                  );
                },
              );
            },
          ),
          // Dedicated Language Selection Button
          // Dedicated Language Selection Button
          Consumer(
            builder: (context, ref, child) {
              final currentLocale = ref.watch(localeControllerProvider);
              return PopupMenuButton<String>(
                icon: const Icon(Icons.language),
                tooltip: AppLocalizations.of(context)!.changeLanguage,
                onSelected: (lang) {
                  ref.read(localeControllerProvider.notifier).setLocale(lang);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        _buildUsFlag(),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.english),
                        if (currentLocale.languageCode == 'en') ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 16, color: Colors.green),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'de',
                    child: Row(
                      children: [
                        _buildGermanFlag(),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.german),
                        if (currentLocale.languageCode == 'de') ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 16, color: Colors.green),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context)?.playbackPreferences ?? 'Playback Preferences',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const PlaybackSettingsDialog(),
              );
            },
          ),
          // Dedicated Konto Wechseln / Door Logout Button on the far right
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppLocalizations.of(context)!.switchAccount,
            onPressed: () async {
              ref.read(playbackControllerProvider.notifier).stop();
              ref.read(selectedLiveCategoryProvider.notifier).set(null);
              ref.read(selectedLiveStreamProvider.notifier).set(null);
              ref.read(isLiveFullWidthProvider.notifier).set(false);
              final playerService = ref.read(playerServiceProvider);
              await playerService.player.stop();
              await Future.delayed(const Duration(milliseconds: 50));
              
              ref.read(activeAccountProvider.notifier).set(null);
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountListScreen()),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              
              final pages = [
                isDesktop ? const DesktopLiveScreen() : const MobileLiveCategoriesScreen(),
                const MoviesGridScreen(),
                const SeriesGridScreen(),
              ];

              if (isDesktop) {
                return Row(
                  children: [
                    if (!hideChrome) ...[
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (idx) {
                          if (_selectedIndex == 0 && idx != 0) {
                            final active = ref.read(playbackControllerProvider);
                            if (active != null && active.streamType == StreamType.live) {
                              ref.read(playbackControllerProvider.notifier).minimize();
                            }
                          } else if (_selectedIndex != 0 && idx == 0) {
                            final active = ref.read(playbackControllerProvider);
                            if (active != null && active.streamType == StreamType.live) {
                              ref.read(playbackControllerProvider.notifier).expand();
                            }
                          }
                          setState(() => _selectedIndex = idx);
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          NavigationRailDestination(icon: const Icon(Icons.tv), label: Text(AppLocalizations.of(context)!.liveTv)),
                          NavigationRailDestination(icon: const Icon(Icons.movie), label: Text(AppLocalizations.of(context)!.movies)),
                          NavigationRailDestination(icon: const Icon(Icons.video_library), label: Text(AppLocalizations.of(context)!.series)),
                        ],
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                    ],
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: pages,
                      ),
                    ),
                  ],
                );
              } else {
                return IndexedStack(
                  index: _selectedIndex,
                  children: pages,
                );
              }
            },
          ),
          if (_isSearchOpen)
            Positioned.fill(
              child: MasterSearchModal(
                onClose: _closeSearch,
                onSelectTab: (idx) {
                  _wasLiveExpandedBeforeSearch = false;
                  setState(() {
                    _isSearchOpen = false;
                    _selectedIndex = idx;
                  });
                },
              ),
            ),
          FloatingMiniPlayer(
            onExpandLiveDesktop: () {
              if (_isSearchOpen) {
                _wasLiveExpandedBeforeSearch = false;
                setState(() => _isSearchOpen = false);
              }
              ref.read(playbackControllerProvider.notifier).expand();
              setState(() => _selectedIndex = 0);
              ref.read(isLiveFullWidthProvider.notifier).set(true);
            },
          ),
        ],
      ),
      bottomNavigationBar: (!hideChrome && MediaQuery.of(context).size.width <= 800)
          ? SafeArea(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (idx) {
                  if (_selectedIndex == 0 && idx != 0) {
                    final active = ref.read(playbackControllerProvider);
                    if (active != null && active.streamType == StreamType.live) {
                      ref.read(playbackControllerProvider.notifier).minimize();
                    }
                  } else if (_selectedIndex != 0 && idx == 0) {
                    final active = ref.read(playbackControllerProvider);
                    if (active != null && active.streamType == StreamType.live) {
                      ref.read(playbackControllerProvider.notifier).expand();
                    }
                  }
                  setState(() => _selectedIndex = idx);
                },
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.tv), label: AppLocalizations.of(context)!.liveTv),
                  BottomNavigationBarItem(icon: const Icon(Icons.movie), label: AppLocalizations.of(context)!.movies),
                  BottomNavigationBarItem(icon: const Icon(Icons.video_library), label: AppLocalizations.of(context)!.series),
                ],
              ),
            )
            : null,
      ),
    ),
  );
}

  Widget _buildGermanFlag() {
    return Container(
      width: 24,
      height: 15,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Column(
        children: [
          Expanded(child: Container(color: Colors.black)),
          Expanded(child: Container(color: const Color(0xFFFF0000))),
          Expanded(child: Container(color: const Color(0xFFFFCC00))),
        ],
      ),
    );
  }

  Widget _buildUsFlag() {
    return Container(
      width: 24,
      height: 15,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: CustomPaint(
        size: const Size(24, 15),
        painter: _UsFlagPainter(),
      ),
    );
  }
}

class _UsFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripeHeight = size.height / 13.0;
    final redPaint = Paint()..color = const Color(0xFFB22234);
    final whitePaint = Paint()..color = Colors.white;

    // 13 alternating stripes
    for (int i = 0; i < 13; i++) {
      final paint = (i % 2 == 0) ? redPaint : whitePaint;
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight + 0.1),
        paint,
      );
    }

    // Blue Canton covering top 7 stripes
    final cantonWidth = size.width * 0.42;
    final cantonHeight = stripeHeight * 7.0;
    final bluePaint = Paint()..color = const Color(0xFF3C3B6E);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cantonWidth, cantonHeight),
      bluePaint,
    );

    // Miniature white star points
    final starPaint = Paint()..color = Colors.white;
    const rows = 4;
    const cols = 5;
    final xStep = cantonWidth / (cols + 1);
    final yStep = cantonHeight / (rows + 1);

    for (int r = 1; r <= rows; r++) {
      for (int c = 1; c <= cols; c++) {
        final xOffset = (r % 2 == 0) ? (xStep * 0.4) : 0.0;
        if (r % 2 == 0 && c == cols) continue;
        canvas.drawCircle(
          Offset(c * xStep - (r % 2 == 0 ? 0 : 0.5) + xOffset, r * yStep),
          0.7,
          starPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

