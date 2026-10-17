import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'add_account_screen.dart';
import '../dashboard/home_dashboard.dart';
import '../../main.dart'; // To access providers for now
import '../../core/player/playback_controller.dart';
import '../live_tv/live_tv_controller.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/tv_remote_scope.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/platform_utils.dart';
import 'dart:io';
import '../../core/updater/app_updater_service.dart';
import '../../core/updater/widgets/update_dialog.dart';

class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({super.key});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  bool _isNavigating = false;
  bool _hasNoAccounts = true;

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  void _checkForUpdates() async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    try {
      final updater = AppUpdaterService();
      final updateInfo = await updater.checkForUpdate();
      if (updateInfo != null && updateInfo.hasUpdate && mounted) {
        UpdateDialog.show(context, updateInfo: updateInfo, updaterService: updater);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openAddAccount() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    print('[GOAT] Navigating to AddAccountScreen...');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountScreen()),
    ).then((_) {
      if (mounted) {
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
        setState(() => _isNavigating = false);
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, Account account) async {
    final l10n = AppLocalizations.of(context)!;
    final displayName = (account.playlistName != null && account.playlistName!.trim().isNotEmpty)
        ? account.playlistName!.trim()
        : account.username;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1730),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(l10n.localeName == 'de' ? 'Konto löschen?' : 'Delete Account?'),
          ],
        ),
        content: Text(
          l10n.localeName == 'de'
              ? 'Möchtest du das Konto "$displayName" wirklich löschen? Alle zugehörigen Favoriten und Daten werden entfernt.'
              : 'Are you sure you want to delete the account "$displayName"? All related data and favorites will be removed.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.localeName == 'de' ? 'Löschen' : 'Delete',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final accountDao = ref.read(accountDaoProvider);
      await accountDao.deleteAccount(account);
      ref.read(categoryDaoProvider).clearCategories(account.id, 'live');
      ref.read(categoryDaoProvider).clearCategories(account.id, 'movie');
      ref.read(streamDaoProvider).clearAllStreams(account.id);
      ref.read(epgDaoProvider).clearPrograms(account.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[GOAT] AccountListScreen.build() executing');
    final l10n = AppLocalizations.of(context)!;
    final accountDao = ref.watch(accountDaoProvider);

    return StreamBuilder<List<Account>>(
      stream: accountDao.watchAllAccounts(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];
        _hasNoAccounts = accounts.isEmpty;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldExit = await TvRemoteScope.showTvExitDialog(context);
            if (shouldExit && context.mounted) {
              await TvRemoteScope.performExit();
            }
          },
          child: TvRemoteScope(
            isRoot: true,
            child: Scaffold(
            appBar: AppBar(
              title: Padding(
                padding: EdgeInsets.only(left: GoatPlatform.isTv ? 32.0 : 0),
                child: Text(l10n.accounts),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 26),
                  tooltip: l10n.addAccount,
                  onPressed: _openAddAccount,
                ),
                SizedBox(width: GoatPlatform.isTv ? 32 : 8),
              ],
            ),
            body: SafeArea(
              minimum: EdgeInsets.symmetric(
                horizontal: GoatPlatform.isTv ? 48.0 : 0,
                vertical: GoatPlatform.isTv ? 24.0 : 0,
              ),
              child: Builder(
                builder: (context) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Database Error: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                      ),
                    );
                  }

                  if (accounts.isEmpty) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _openAddAccount,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: GoatPlatform.isTv ? 104 : 88,
                                height: GoatPlatform.isTv ? 104 : 88,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.playlist_add_rounded,
                                  size: GoatPlatform.isTv ? 56 : 48,
                                  color: const Color(0xFFB388FF),
                                ),
                              ),
                              SizedBox(height: GoatPlatform.isTv ? 28 : 24),
                              Text(
                                l10n.noAccountsAdded,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: GoatPlatform.isTv ? 24 : 20,
                                    ),
                              ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.localeName == 'de'
                              ? 'Füge eine Playlist hinzu, um Live TV, Filme & Serien zu starten.'
                              : 'Add a playlist to start watching Live TV, Movies & Series.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        TvFocusable(
                          autofocus: true,
                          borderRadius: BorderRadius.circular(14),
                          focusScale: 1.05,
                          onPressed: _openAddAccount,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openAddAccount,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                                    const SizedBox(width: 10),
                                    Text(
                                      l10n.addAccount,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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

            final isWide = GoatPlatform.isTv || MediaQuery.of(context).size.width >= 800;
            if (isWide) {
              return GridView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: GoatPlatform.isTv ? 24 : 20,
                  vertical: GoatPlatform.isTv ? 20 : 16,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 440,
                  mainAxisExtent: 88,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: accounts.length,
                itemBuilder: (context, index) => _buildAccountTile(context, accounts[index], index, l10n),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: accounts.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildAccountTile(context, accounts[index], index, l10n),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _hasNoAccounts
            ? null
            : TvFocusable(
                borderRadius: BorderRadius.circular(16),
                onPressed: _openAddAccount,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openAddAccount,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            l10n.addAccount,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
      },
    );
  }

  Widget _buildAccountTile(BuildContext context, Account account, int index, AppLocalizations l10n) {
    final isM3u = account.username.isEmpty || account.serverUrl.contains('.m3u');
    final displayName = (account.playlistName != null && account.playlistName!.trim().isNotEmpty)
        ? account.playlistName!.trim()
        : (isM3u ? 'M3U Playlist' : account.username);

    return TvFocusable(
      autofocus: index == 0,
      borderRadius: BorderRadius.circular(12),
      onPressed: () {
        ref.read(playbackControllerProvider.notifier).stop();
        ref.read(selectedLiveCategoryProvider.notifier).set(null);
        ref.read(selectedLiveStreamProvider.notifier).set(null);
        ref.read(isLiveFullWidthProvider.notifier).set(false);
        ref.read(activeAccountProvider.notifier).set(account);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1730),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
              child: Icon(
                isM3u ? Icons.playlist_play_rounded : Icons.person,
                color: const Color(0xFFB388FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (isM3u)
                    const Row(
                      children: [
                        Icon(Icons.playlist_play_rounded, size: 14, color: Color(0xFF00E5FF)),
                        SizedBox(width: 5),
                        Text(
                          'M3U Playlist',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 13, color: Color(0xFFB388FF)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            account.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 13, color: Colors.white38),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          account.serverUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
                  tooltip: l10n.localeName == 'de' ? 'Bearbeiten' : 'Edit',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddAccountScreen(accountToEdit: account),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: l10n.localeName == 'de' ? 'Löschen' : 'Delete',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context, account),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
