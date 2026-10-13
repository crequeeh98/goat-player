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
    if (GoatPlatform.isMobile) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
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
        if (GoatPlatform.isMobile) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
        setState(() => _isNavigating = false);
      }
    });
  }

  bool _handleGlobalKey(KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyUpEvent) || !mounted) return false;
    final key = event.logicalKey;
    final isSelect = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;

    if (isSelect && _hasNoAccounts) {
      print('[GOAT_KEY] Select/Enter (${event.runtimeType}) received on empty AccountListScreen -> triggering _openAddAccount()');
      _openAddAccount();
      return true;
    }
    return false;
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

        return TvRemoteScope(
          isRoot: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.accounts),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 26),
                  tooltip: l10n.addAccount,
                  onPressed: _openAddAccount,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Builder(
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
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            size: 48,
                            color: Color(0xFFB388FF),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.noAccountsAdded,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final isM3u = account.username.isEmpty || account.serverUrl.contains('.m3u');
                final displayName = (account.playlistName != null && account.playlistName!.trim().isNotEmpty)
                    ? account.playlistName!.trim()
                    : (isM3u ? 'M3U Playlist' : account.username);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TvFocusable(
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1730),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          child: Icon(isM3u ? Icons.playlist_play_rounded : Icons.person, color: const Color(0xFFB388FF)),
                        ),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            if (isM3u)
                              const Row(
                                children: [
                                  Icon(Icons.playlist_play_rounded, size: 14, color: Color(0xFF00E5FF)),
                                  SizedBox(width: 5),
                                  Text(
                                    'M3U Playlist',
                                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w600),
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
                                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
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
                                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              tooltip: l10n.localeName == 'de' ? 'Bearbeiten' : 'Edit',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddAccountScreen(accountToEdit: account),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              tooltip: l10n.localeName == 'de' ? 'Löschen' : 'Delete',
                              onPressed: () => _confirmDelete(context, account),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
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
    );
      },
    );
  }
}
