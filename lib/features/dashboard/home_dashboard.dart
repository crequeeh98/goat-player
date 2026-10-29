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
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/tv_remote_scope.dart';
import '../../core/player/widgets/floating_mini_player.dart';
import '../../core/player/playback_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'master_search_modal.dart';
import 'account_connection_provider.dart';
import 'dashboard_state.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  int _selectedIndex = 0;
  bool _isSearchOpen = false;
  bool _wasLiveExpandedBeforeSearch = false;

  late final FocusNode _headerSearchFocusNode;
  late final FocusNode _headerPrefFocusNode;
  late final FocusNode _headerLangFocusNode;
  late final FocusNode _headerVpnFocusNode;
  late final FocusNode _headerSwitchFocusNode;
  final List<FocusNode> _sidebarFocusNodes = [];

  void _openSearch() async {
    ref.read(dashboardTabResetProvider.notifier).reset();
    ref.read(selectedLiveCategoryProvider.notifier).set(null);
    final active = ref.read(playbackControllerProvider);
    _wasLiveExpandedBeforeSearch = active != null && active.streamType == StreamType.live && !active.isMinimized;
    if (_wasLiveExpandedBeforeSearch) {
      if (GoatPlatform.isTv) {
        ref.read(playbackControllerProvider.notifier).stop();
      } else {
        ref.read(playbackControllerProvider.notifier).minimize();
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    setState(() => _isSearchOpen = true);
  }

  void _closeSearch() async {
    ref.read(dashboardTabResetProvider.notifier).reset();
    ref.read(selectedLiveCategoryProvider.notifier).set(null);
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

  Future<void> _handleSwitchAccount() async {
    if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else if (GoatPlatform.isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    ref.read(playbackControllerProvider.notifier).stop();
    ref.read(selectedLiveCategoryProvider.notifier).set(null);
    ref.read(selectedLiveStreamProvider.notifier).set(null);
    ref.read(isLiveFullWidthProvider.notifier).set(false);
    final playerService = ref.read(playerServiceProvider);
    playerService.player.stop().catchError((_) {});
    
    ref.read(activeAccountProvider.notifier).set(null);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AccountListScreen(fromSwitchAccount: true)),
        (route) => false,
      );
    }
  }

  void _showLanguageDialog() {
    final currentLocale = ref.read(localeControllerProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(ctx)!.changeLanguage,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _buildUsFlag(),
              title: Text(AppLocalizations.of(ctx)!.english),
              trailing: currentLocale.languageCode == 'en' ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                ref.read(localeControllerProvider.notifier).setLocale('en');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: _buildGermanFlag(),
              title: Text(AppLocalizations.of(ctx)!.german),
              trailing: currentLocale.languageCode == 'de' ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                ref.read(localeControllerProvider.notifier).setLocale('de');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.close),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _headerSearchFocusNode = FocusNode(debugLabel: 'header_search');
    _headerPrefFocusNode = FocusNode(debugLabel: 'header_pref');
    _headerLangFocusNode = FocusNode(debugLabel: 'header_lang');
    _headerVpnFocusNode = FocusNode(debugLabel: 'header_vpn');
    _headerSwitchFocusNode = FocusNode(debugLabel: 'header_switch');
    for (var i = 0; i < 3; i++) {
      _sidebarFocusNodes.add(FocusNode(debugLabel: 'sidebar_$i'));
    }
    if (GoatPlatform.isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (GoatPlatform.isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    // Smooth, non-blocking background sync pipeline:
    // Allow the UI to render and settle smoothly on startup before checking background updates
    Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      await ref.read(liveTvControllerProvider).syncLiveCategories();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await ref.read(vodControllerProvider).syncVodCategories();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await ref.read(seriesControllerProvider).syncSeriesCategories();

      // On TV, do not dump tens of thousands of streams into memory concurrently.
      // Category streams are loaded on-demand when a category is selected.
      if (!GoatPlatform.isTv) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        await ref.read(liveTvControllerProvider).syncAllLiveStreams();
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        await ref.read(vodControllerProvider).syncAllVodStreams();
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        await ref.read(seriesControllerProvider).syncAllSeriesStreams();
      }
    });
  }

  @override
  void dispose() {
    _headerSearchFocusNode.dispose();
    _headerPrefFocusNode.dispose();
    _headerLangFocusNode.dispose();
    _headerVpnFocusNode.dispose();
    _headerSwitchFocusNode.dispose();
    for (final node in _sidebarFocusNodes) {
      node.dispose();
    }
    super.dispose();
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
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    if (GoatPlatform.isTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(headerSearchFocusNodeProvider) != _headerSearchFocusNode) {
          ref.read(headerSearchFocusNodeProvider.notifier).set(_headerSearchFocusNode);
        }
        if (_selectedIndex < _sidebarFocusNodes.length &&
            ref.read(activeSidebarFocusNodeProvider) != _sidebarFocusNodes[_selectedIndex]) {
          ref.read(activeSidebarFocusNodeProvider.notifier).set(_sidebarFocusNodes[_selectedIndex]);
        }
      });
    }

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
          await TvRemoteScope.performExit();
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
        child: Container(
          color: const Color(0xFF0D0915),
          padding: EdgeInsets.zero,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            appBar: hideChrome ? null : AppBar(
              toolbarHeight: GoatPlatform.isTv ? 46 : null,
              titleSpacing: isCompact ? 8 : (GoatPlatform.isTv ? 14 : null),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/logo.png', width: isCompact ? 28 : 32, height: isCompact ? 28 : 32),
                ),
                SizedBox(width: isCompact ? 8 : 12),
                Flexible(child: _buildAccountHeaderPill(isCompact)),
              ],
            ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Theme.of(context).dividerColor,
            height: 1.0,
          ),
        ),
        actions: isCompact
            ? [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: AppLocalizations.of(context)!.search,
                  onPressed: _openSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.language),
                  tooltip: AppLocalizations.of(context)!.changeLanguage,
                  onPressed: _showLanguageDialog,
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final stageAsync = ref.watch(vpnStageProvider);
                    final isConnected = stageAsync.value == VpnStage.connected;
                    final localizedStatus = isConnected 
                        ? AppLocalizations.of(context)!.vpnConnected 
                        : AppLocalizations.of(context)!.vpnDisconnected;

                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (action) {
                        if (action == 'vpn') {
                          showDialog(
                            context: context,
                            builder: (context) => const VpnImportDialog(),
                          );
                        } else if (action == 'playback') {
                          showDialog(
                            context: context,
                            builder: (context) => const PlaybackSettingsDialog(),
                          );
                        } else if (action == 'switch') {
                          _handleSwitchAccount();
                        }
                      },
                      itemBuilder: (context) => [
                        if (!GoatPlatform.isWeb)
                          PopupMenuItem(
                            value: 'vpn',
                            child: Row(
                              children: [
                                Icon(
                                  isConnected ? Icons.security : Icons.shield_outlined,
                                  size: 20,
                                  color: isConnected ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'VPN ($localizedStatus)',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'playback',
                          child: Row(
                            children: [
                              const Icon(Icons.tune, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context)?.playbackPreferences ?? 'Playback Settings',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'switch',
                          child: Row(
                            children: [
                              const Icon(Icons.logout, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context)!.switchAccount,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 4),
              ]
            : GoatPlatform.isTv
                ? [
                    _buildTvHeaderButton(
                      focusNode: _headerSearchFocusNode,
                      icon: Icons.search,
                      label: AppLocalizations.of(context)!.search,
                      onPressed: _openSearch,
                      isLeftmost: true,
                    ),
                    const SizedBox(width: 8),
                    _buildTvHeaderButton(
                      focusNode: _headerPrefFocusNode,
                      icon: Icons.tune,
                      label: AppLocalizations.of(context)?.localeName == 'de' ? 'Einstellungen' : 'Preferences',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const PlaybackSettingsDialog(),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final currentLocale = ref.watch(localeControllerProvider);
                        final isDe = currentLocale.languageCode == 'de';
                        return _buildTvHeaderButton(
                          focusNode: _headerLangFocusNode,
                          icon: Icons.language,
                          label: isDe ? 'DE' : 'EN',
                          onPressed: () {
                            ref.read(localeControllerProvider.notifier).setLocale(isDe ? 'en' : 'de');
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildTvHeaderButton(
                      focusNode: _headerSwitchFocusNode,
                      icon: Icons.logout_rounded,
                      label: AppLocalizations.of(context)!.switchAccount,
                      onPressed: _handleSwitchAccount,
                      isRightmost: true,
                    ),
                    const SizedBox(width: 12),
                    _buildTvLiveClock(),
                    const SizedBox(width: 16),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: AppLocalizations.of(context)!.search,
                      onPressed: _openSearch,
                    ),
                    if (!GoatPlatform.isWeb)
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
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: AppLocalizations.of(context)!.switchAccount,
                      onPressed: _handleSwitchAccount,
                    ),
                    const SizedBox(width: 8),
                  ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = (constraints.maxWidth > 800 && !GoatPlatform.isPhone) || GoatPlatform.isTv;
              
              final pages = [
                isDesktop ? const DesktopLiveScreen() : const MobileLiveCategoriesScreen(),
                const MoviesGridScreen(),
                const SeriesGridScreen(),
              ];

              if (isDesktop) {
                return Row(
                  children: [
                    if (!hideChrome) ...[
                      if (GoatPlatform.isTv)
                        _buildTvSidebar(context)
                      else
                        NavigationRail(
                          selectedIndex: _selectedIndex,
                          minWidth: 72,
                          unselectedIconTheme: const IconThemeData(
                            size: 24,
                            color: Colors.white60,
                          ),
                          selectedIconTheme: const IconThemeData(
                            size: 24,
                            color: Color(0xFFB388FF),
                          ),
                          unselectedLabelTextStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                          selectedLabelTextStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          onDestinationSelected: _onTabSelected,
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
              child: Container(
                color: const Color(0xFF0F0817),
                child: MasterSearchModal(
                  onClose: _closeSearch,
                  onSelectTab: (idx) {
                    _wasLiveExpandedBeforeSearch = false;
                    ref.read(dashboardTabResetProvider.notifier).reset();
                    setState(() {
                      _isSearchOpen = false;
                      _selectedIndex = idx;
                    });
                  },
                ),
              ),
            ),
          if (!GoatPlatform.isWeb && !GoatPlatform.isTv && (ModalRoute.of(context)?.isCurrent ?? true))
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
      bottomNavigationBar: (!hideChrome && (MediaQuery.sizeOf(context).width <= 800 || GoatPlatform.isPhone))
          ? SafeArea(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (idx) {
                  if (_selectedIndex != idx) {
                    ref.read(dashboardTabResetProvider.notifier).reset();
                    ref.read(selectedLiveCategoryProvider.notifier).set(null);
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
  ),
);
}

  void _onTabSelected(int idx) {
    ref.read(activeDashboardTabProvider.notifier).set(idx);
    if (_selectedIndex != idx) {
      ref.read(dashboardTabResetProvider.notifier).reset();
      ref.read(selectedLiveCategoryProvider.notifier).set(null);
    }
    if (_selectedIndex == 0 && idx != 0) {
      final active = ref.read(playbackControllerProvider);
      if (active != null && active.streamType == StreamType.live) {
        if (GoatPlatform.isTv) {
          ref.read(playbackControllerProvider.notifier).stop();
        } else {
          ref.read(playbackControllerProvider.notifier).minimize();
        }
      }
    } else if (_selectedIndex != 0 && idx == 0) {
      final active = ref.read(playbackControllerProvider);
      if (active != null && active.streamType == StreamType.live) {
        ref.read(playbackControllerProvider.notifier).expand();
      }
    }
    if (GoatPlatform.isWeb) {
      if (idx == 1) ref.read(vodControllerProvider).syncVodCategories();
      if (idx == 2) ref.read(seriesControllerProvider).syncSeriesCategories();
    }
    setState(() => _selectedIndex = idx);
  }

  Widget _buildTvSidebar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (icon: Icons.tv_rounded, label: l10n.liveTv, index: 0),
      (icon: Icons.movie_rounded, label: l10n.movies, index: 1),
      (icon: Icons.video_library_rounded, label: l10n.series, index: 2),
    ];

    return Container(
      width: 72,
      color: const Color(0xFF0E0A18),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          for (final item in items) ...[
            TvFocusable(
              focusNode: _sidebarFocusNodes.length > item.index ? _sidebarFocusNodes[item.index] : null,
              borderRadius: BorderRadius.circular(12),
              onPressed: () => _onTabSelected(item.index),
              onFocusChange: (has) {
                if (has && _sidebarFocusNodes.length > item.index) {
                  ref.read(activeSidebarFocusNodeProvider.notifier).set(_sidebarFocusNodes[item.index]);
                }
              },
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    if (_selectedIndex != item.index) {
                      _onTabSelected(item.index);
                    }
                    final catTarget = ref.read(tabCategoryFocusNodesProvider)[item.index] ??
                        ref.read(activeCategoryFocusNodeProvider);
                    if (catTarget != null && catTarget.context != null && catTarget.canRequestFocus) {
                      catTarget.requestFocus();
                      return KeyEventResult.handled;
                    }
                    final searchTarget = ref.read(activeScreenSearchFocusNodeProvider);
                    if (searchTarget != null && searchTarget.context != null && searchTarget.canRequestFocus) {
                      searchTarget.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (FocusScope.of(context).focusInDirection(TraversalDirection.right)) {
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && item.index >= items.length - 1) {
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && item.index == 0) {
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: _selectedIndex == item.index
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: _selectedIndex == item.index
                          ? const Color(0xFFB388FF)
                          : Colors.white60,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: _selectedIndex == item.index ? FontWeight.bold : FontWeight.w500,
                        color: _selectedIndex == item.index ? Colors.white : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTvHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required FocusNode focusNode,
    bool isLeftmost = false,
    bool isRightmost = false,
    Color iconColor = Colors.white70,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TvFocusable(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(10),
        onPressed: onPressed,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            // Block ArrowUp completely so focus NEVER jumps into category lists
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              final target = ref.read(activeScreenSearchFocusNodeProvider);
              if (target != null && target.context != null && target.canRequestFocus) {
                target.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.handled;
            } else if (isLeftmost && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final sidebar = ref.read(activeSidebarFocusNodeProvider);
              if (sidebar != null && sidebar.context != null && sidebar.canRequestFocus) {
                sidebar.requestFocus();
                return KeyEventResult.handled;
              }
            } else if (isRightmost && event.logicalKey == LogicalKeyboardKey.arrowRight) {
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTvLiveClock() {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 15), (i) => i),
      builder: (context, _) {
        final now = DateTime.now();
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        return Text(
          timeStr,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  Widget _buildAccountHeaderPill(bool isCompact) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) {
      return const Text('GOATPlayer', style: TextStyle(fontWeight: FontWeight.bold));
    }

    final displayName = (account.playlistName != null && account.playlistName!.trim().isNotEmpty)
        ? account.playlistName!.trim()
        : account.username;

    final connInfo = ref.watch(accountConnectionInfoProvider);
    final isWarning = connInfo.active >= connInfo.max && connInfo.max > 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10, vertical: isCompact ? 3 : 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 6 : 8,
            height: isCompact ? 6 : 8,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                  blurRadius: isCompact ? 4 : 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: isCompact ? 5 : 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isCompact ? 80 : 160),
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
            child: Text(
              '|',
              style: TextStyle(
                fontSize: isCompact ? 11 : 13,
                color: Colors.white24,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 8, vertical: 2),
            decoration: BoxDecoration(
              color: isWarning
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWarning
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi,
                  size: isCompact ? 11 : 13,
                  color: isWarning ? const Color(0xFFF59E0B) : const Color(0xFFA78BFA),
                ),
                SizedBox(width: isCompact ? 3 : 5),
                Text(
                  connInfo.isLoading && connInfo.active == 0 && connInfo.max == 1
                      ? '-- / --'
                      : '${connInfo.active} / ${connInfo.max}',
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isWarning ? const Color(0xFFF59E0B) : Colors.white70,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
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

