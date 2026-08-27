import 'package:flutter/material.dart';
import '../../core/player/player_service.dart';
import '../live_tv/desktop_live_screen.dart';
import '../live_tv/mobile_live_view.dart';
import '../settings/widgets/vpn_import_dialog.dart';
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
import 'master_search_modal.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fire and forget background sync of entire catalog for global search
    Future.microtask(() {
      ref.read(vodControllerProvider).syncAllVodStreams();
      ref.read(seriesControllerProvider).syncAllSeriesStreams();
      ref.read(liveTvControllerProvider).syncAllLiveStreams();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLiveFullWidth = ref.watch(isLiveFullWidthProvider);
    final hideChrome = isLiveFullWidth && _selectedIndex == 0;
    
    return Scaffold(
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
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MasterSearchModal(),
                  fullscreenDialog: true,
                ),
              );
              if (result != null && result is int) {
                setState(() => _selectedIndex = result);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: AppLocalizations.of(context)!.changeLanguage,
            onSelected: (value) {
              ref.read(localeControllerProvider.notifier).setLocale(value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'en',
                child: Text(AppLocalizations.of(context)!.english),
              ),
              PopupMenuItem(
                value: 'de',
                child: Text(AppLocalizations.of(context)!.german),
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, child) {
              final stageAsync = ref.watch(vpnStageProvider);
              final isConnected = stageAsync.value == VpnStage.connected;
              final status = stageAsync.value?.name ?? 'disconnected';
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
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: AppLocalizations.of(context)!.switchAccount,
              onPressed: () async {
                // Safely stop any running Live TV player before unmounting to prevent segfaults
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
      body: LayoutBuilder(
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
                    onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(icon: const Icon(Icons.tv), label: Text(AppLocalizations.of(context)!.liveTv)),
                      NavigationRailDestination(icon: const Icon(Icons.movie), label: Text(AppLocalizations.of(context)!.movies)),
                      NavigationRailDestination(icon: const Icon(Icons.video_library), label: Text(AppLocalizations.of(context)!.series)),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                ],
                Expanded(child: pages[_selectedIndex]),
              ],
            );
          } else {
            return pages[_selectedIndex];
          }
        },
      ),
      bottomNavigationBar: (!hideChrome && MediaQuery.of(context).size.width <= 800) ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.tv), label: AppLocalizations.of(context)!.liveTv),
          BottomNavigationBarItem(icon: const Icon(Icons.movie), label: AppLocalizations.of(context)!.movies),
          BottomNavigationBarItem(icon: const Icon(Icons.video_library), label: AppLocalizations.of(context)!.series),
        ],
      ) : null,
    );
  }
}

