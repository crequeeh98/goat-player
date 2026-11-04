import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/platform_utils.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../main.dart';
import '../../live_tv/epg_controller.dart';
import '../../live_tv/live_tv_controller.dart';
import '../../vod_movies/vod_controller.dart';
import '../../vod_series/series_controller.dart';

enum SyncModalState { idle, syncing, success, error }

class PlaylistSyncModal extends ConsumerStatefulWidget {
  const PlaylistSyncModal({super.key});

  @override
  ConsumerState<PlaylistSyncModal> createState() => _PlaylistSyncModalState();
}

class _PlaylistSyncModalState extends ConsumerState<PlaylistSyncModal> {
  SyncModalState _state = SyncModalState.idle;
  String _currentStatus = '';
  String? _errorMessage;

  int? _lastLiveSync;
  int? _lastVodSync;
  int? _lastSeriesSync;
  int? _lastEpgSync;

  @override
  void initState() {
    super.initState();
    _loadSyncTimestamps();
  }

  void _loadSyncTimestamps() {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _lastLiveSync = prefs.getInt('last_sync_all_live_${account.id}');
      _lastVodSync = prefs.getInt('last_sync_all_vod_${account.id}');
      _lastSeriesSync = prefs.getInt('last_sync_all_series_${account.id}');
      _lastEpgSync = prefs.getInt('last_sync_epg_${account.id}');
    });
  }

  String _formatTimestamp(int? ts, bool isDe) {
    if (ts == null || ts == 0) return isDe ? 'Nie' : 'Never';
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    if (diff < 60 * 1000) return isDe ? 'Gerade eben' : 'Just now';
    if (diff < 60 * 60 * 1000) {
      final mins = diff ~/ (60 * 1000);
      return isDe ? 'Vor $mins Min.' : '${mins}m ago';
    }
    if (diff < 24 * 60 * 60 * 1000) {
      final hours = diff ~/ (60 * 60 * 1000);
      return isDe ? 'Vor $hours Std.' : '${hours}h ago';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return isDe ? '$day.$month. $hour:$minute Uhr' : '$month/$day $hour:$minute';
  }

  Future<void> _runSync(String initialStatus, Future<void> Function() action, bool isDe) async {
    setState(() {
      _state = SyncModalState.syncing;
      _currentStatus = initialStatus;
      _errorMessage = null;
    });

    try {
      await action();
      if (!mounted) return;
      _loadSyncTimestamps();
      setState(() {
        _state = SyncModalState.success;
        _currentStatus = isDe ? 'Aktualisierung erfolgreich!' : 'Refresh successful!';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = SyncModalState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _syncLive(bool isDe) {
    _runSync(
      isDe ? 'Live TV Sender & Kategorien werden aktualisiert...' : 'Updating Live TV channels & categories...',
      () async {
        await ref.read(liveTvControllerProvider).syncLiveCategories(force: true, rethrowOnError: true);
        await ref.read(liveTvControllerProvider).syncAllLiveStreams(force: true, rethrowOnError: true);
      },
      isDe,
    );
  }

  void _syncVod(bool isDe) {
    _runSync(
      isDe ? 'Filme (VOD) werden aktualisiert...' : 'Updating Movies (VOD)...',
      () async {
        await ref.read(vodControllerProvider).syncVodCategories(force: true, rethrowOnError: true);
        await ref.read(vodControllerProvider).syncAllVodStreams(force: true, rethrowOnError: true);
      },
      isDe,
    );
  }

  void _syncSeries(bool isDe) {
    _runSync(
      isDe ? 'Serien werden aktualisiert...' : 'Updating Series...',
      () async {
        await ref.read(seriesControllerProvider).syncSeriesCategories(force: true, rethrowOnError: true);
        await ref.read(seriesControllerProvider).syncAllSeriesStreams(force: true, rethrowOnError: true);
      },
      isDe,
    );
  }

  void _syncEpg(bool isDe) {
    _runSync(
      isDe ? 'EPG TV Guide wird aktualisiert...' : 'Updating EPG TV Guide...',
      () async {
        await ref.read(epgControllerProvider).syncEpgData(force: true);
      },
      isDe,
    );
  }

  Future<void> _toggleScope(String type, bool isDe) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    bool newLive = account.syncLiveTv;
    bool newMovies = account.syncMovies;
    bool newSeries = account.syncSeries;

    if (type == 'live') newLive = !newLive;
    if (type == 'movie') newMovies = !newMovies;
    if (type == 'series') newSeries = !newSeries;

    if (!newLive && !newMovies && !newSeries) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDe
                ? 'Mindestens ein Bereich muss aktiv bleiben.'
                : 'At least one section must remain active.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final dao = ref.read(accountDaoProvider);
    await dao.updateSyncScopes(account.id, syncLiveTv: newLive, syncMovies: newMovies, syncSeries: newSeries);
    final updatedAccount = account.copyWith(syncLiveTv: newLive, syncMovies: newMovies, syncSeries: newSeries);
    ref.read(activeAccountProvider.notifier).set(updatedAccount);

    if (type == 'live' && !newLive) {
      await ref.read(streamDaoProvider).clearStreamsByType(account.id, 'live');
      await ref.read(categoryDaoProvider).clearCategories(account.id, 'live');
    } else if (type == 'movie' && !newMovies) {
      await ref.read(streamDaoProvider).clearStreamsByType(account.id, 'movie');
      await ref.read(categoryDaoProvider).clearCategories(account.id, 'movie');
    } else if (type == 'series' && !newSeries) {
      await ref.read(streamDaoProvider).clearStreamsByType(account.id, 'series');
      await ref.read(categoryDaoProvider).clearCategories(account.id, 'series');
    }

    if (type == 'live' && newLive) {
      _syncLive(isDe);
    } else if (type == 'movie' && newMovies) {
      _syncVod(isDe);
    } else if (type == 'series' && newSeries) {
      _syncSeries(isDe);
    } else {
      if (mounted) setState(() {});
    }
  }

  void _syncAll(bool isDe) {
    final account = ref.read(activeAccountProvider);
    final hasLive = account?.syncLiveTv ?? true;
    final hasMovies = account?.syncMovies ?? true;
    final hasSeries = account?.syncSeries ?? true;

    _runSync(
      isDe ? 'Inhalte werden aktualisiert...' : 'Updating content...',
      () async {
        if (hasLive) {
          setState(() => _currentStatus = isDe ? 'Live TV wird aktualisiert...' : 'Updating Live TV...');
          await ref.read(liveTvControllerProvider).syncLiveCategories(force: true, rethrowOnError: true);
          await ref.read(liveTvControllerProvider).syncAllLiveStreams(force: true, rethrowOnError: true);
          if (!mounted) return;
        }

        if (hasMovies) {
          setState(() => _currentStatus = isDe ? 'Filme (VOD) werden aktualisiert...' : 'Updating Movies (VOD)...');
          await ref.read(vodControllerProvider).syncVodCategories(force: true, rethrowOnError: true);
          await ref.read(vodControllerProvider).syncAllVodStreams(force: true, rethrowOnError: true);
          if (!mounted) return;
        }

        if (hasSeries) {
          setState(() => _currentStatus = isDe ? 'Serien werden aktualisiert...' : 'Updating Series...');
          await ref.read(seriesControllerProvider).syncSeriesCategories(force: true, rethrowOnError: true);
          await ref.read(seriesControllerProvider).syncAllSeriesStreams(force: true, rethrowOnError: true);
          if (!mounted) return;
        }

        if (hasLive) {
          setState(() => _currentStatus = isDe ? 'EPG TV Guide wird aktualisiert...' : 'Updating EPG TV Guide...');
          await ref.read(epgControllerProvider).syncEpgData(force: true);
        }
      },
      isDe,
    );
  }

  void _syncM3u(bool isDe) {
    _runSync(
      isDe ? 'M3U Playlist wird geladen...' : 'Loading M3U playlist...',
      () async {
        await ref.read(liveTvControllerProvider).syncAllLiveStreams(force: true, rethrowOnError: true);
      },
      isDe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    final locale = ref.watch(localeControllerProvider);
    final isDe = locale.languageCode == 'de';
    final isM3u = account != null && (account.username.isEmpty || account.serverUrl.contains('.m3u'));

    return PopScope(
      canPop: _state != SyncModalState.syncing,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: GoatPlatform.isTv ? 48 : 20,
          vertical: 24,
        ),
        child: Container(
          width: GoatPlatform.isTv ? 580 : 480,
          constraints: BoxConstraints(maxHeight: GoatPlatform.isTv ? 560 : 640),
          decoration: BoxDecoration(
            color: const Color(0xFF160F26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildBody(isM3u, isDe),
        ),
      ),
    );
  }

  Widget _buildBody(bool isM3u, bool isDe) {
    switch (_state) {
      case SyncModalState.syncing:
        return _buildSyncingView(isDe);
      case SyncModalState.success:
        return _buildSuccessView();
      case SyncModalState.error:
        return _buildErrorView(isDe);
      case SyncModalState.idle:
        return _buildIdleView(isM3u, isDe);
    }
  }

  Widget _buildSyncingView(bool isDe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB388FF)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _currentStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isDe
                ? 'Bitte warten, Playlist-Daten werden synchronisiert...'
                : 'Please wait, synchronizing playlist data...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF22C55E), width: 2),
            ),
            child: const Icon(Icons.check, color: Color(0xFF22C55E), size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            _currentStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withValues(alpha: 0.15),
              border: Border.all(color: Colors.redAccent, width: 2),
            ),
            child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            isDe ? 'Fehler bei der Synchronisierung' : 'Sync error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? (isDe ? 'Unbekannter Netzwerkfehler' : 'Unknown network error'),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TvFocusable(
                borderRadius: BorderRadius.circular(10),
                onPressed: () => setState(() => _state = SyncModalState.idle),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isDe ? 'Erneut versuchen' : 'Retry',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              TvFocusable(
                borderRadius: BorderRadius.circular(10),
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isDe ? 'Schließen' : 'Close',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(10),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFB388FF) : Colors.white12,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 15,
              color: isSelected ? const Color(0xFFB388FF) : Colors.white30,
            ),
            const SizedBox(width: 5),
            Icon(icon, size: 15, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleView(bool isM3u, bool isDe) {
    final account = ref.watch(activeAccountProvider);
    final hasLive = account?.syncLiveTv ?? true;
    final hasMovies = account?.syncMovies ?? true;
    final hasSeries = account?.syncSeries ?? true;

    final lastUpdatedPrefix = isDe ? 'Zuletzt aktualisiert' : 'Last updated';
    final refreshBtnLabel = isDe ? 'Aktualisieren' : 'Refresh';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modal Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.sync_rounded, color: Color(0xFFB388FF), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDe ? 'Playlist aktualisieren' : 'Refresh Playlist',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              TvFocusable(
                borderRadius: BorderRadius.circular(16),
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isM3u) ...[
                  _buildSyncRow(
                    icon: Icons.playlist_play_rounded,
                    title: isDe ? 'M3U Playlist & Sender' : 'M3U Playlist & Channels',
                    subtitle: '$lastUpdatedPrefix: ${_formatTimestamp(_lastLiveSync, isDe)}',
                    buttonLabel: refreshBtnLabel,
                    onPressed: () => _syncM3u(isDe),
                    autofocus: true,
                  ),
                ] else ...[
                  Text(
                    isDe ? 'INHALTS-UMFANG' : 'CONTENT SCOPES',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildScopeChip(
                          label: 'Live TV',
                          icon: Icons.tv_rounded,
                          isSelected: hasLive,
                          onTap: () => _toggleScope('live', isDe),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildScopeChip(
                          label: isDe ? 'Filme' : 'Movies',
                          icon: Icons.movie_rounded,
                          isSelected: hasMovies,
                          onTap: () => _toggleScope('movie', isDe),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildScopeChip(
                          label: isDe ? 'Serien' : 'Series',
                          icon: Icons.video_library_rounded,
                          isSelected: hasSeries,
                          onTap: () => _toggleScope('series', isDe),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 10),

                  if (hasLive) ...[
                    _buildSyncRow(
                      icon: Icons.tv_rounded,
                      title: 'Live TV',
                      subtitle: '$lastUpdatedPrefix: ${_formatTimestamp(_lastLiveSync, isDe)}',
                      buttonLabel: refreshBtnLabel,
                      onPressed: () => _syncLive(isDe),
                      autofocus: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hasMovies) ...[
                    _buildSyncRow(
                      icon: Icons.movie_rounded,
                      title: isDe ? 'Filme (VOD)' : 'Movies (VOD)',
                      subtitle: '$lastUpdatedPrefix: ${_formatTimestamp(_lastVodSync, isDe)}',
                      buttonLabel: refreshBtnLabel,
                      onPressed: () => _syncVod(isDe),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hasSeries) ...[
                    _buildSyncRow(
                      icon: Icons.video_library_rounded,
                      title: isDe ? 'Serien' : 'Series',
                      subtitle: '$lastUpdatedPrefix: ${_formatTimestamp(_lastSeriesSync, isDe)}',
                      buttonLabel: refreshBtnLabel,
                      onPressed: () => _syncSeries(isDe),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hasLive) ...[
                    _buildSyncRow(
                      icon: Icons.table_chart_rounded,
                      title: 'EPG TV Guide',
                      subtitle: '$lastUpdatedPrefix: ${_formatTimestamp(_lastEpgSync, isDe)}',
                      buttonLabel: refreshBtnLabel,
                      onPressed: () => _syncEpg(isDe),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(12),
                    focusScale: 1.02,
                    focusBorderColor: const Color(0xFFB388FF),
                    onPressed: () => _syncAll(isDe),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.all_inclusive_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            isDe ? 'Alles auf einmal aktualisieren' : 'Refresh Everything',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool autofocus = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFB388FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TvFocusable(
            autofocus: autofocus,
            borderRadius: BorderRadius.circular(8),
            onPressed: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
