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

  String _formatTimestamp(int? ts) {
    if (ts == null || ts == 0) return 'Nie';
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    if (diff < 60 * 1000) return 'Gerade eben';
    if (diff < 60 * 60 * 1000) return 'Vor ${diff ~/ (60 * 1000)} Min.';
    if (diff < 24 * 60 * 60 * 1000) return 'Vor ${diff ~/ (60 * 60 * 1000)} Std.';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month. $hour:$minute Uhr';
  }

  Future<void> _runSync(String initialStatus, Future<void> Function() action) async {
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
        _currentStatus = 'Aktualisierung erfolgreich!';
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

  void _syncLive() {
    _runSync('Live TV Sender & Kategorien werden aktualisiert...', () async {
      await ref.read(liveTvControllerProvider).syncLiveCategories(force: true, rethrowOnError: true);
      await ref.read(liveTvControllerProvider).syncAllLiveStreams(force: true, rethrowOnError: true);
    });
  }

  void _syncVod() {
    _runSync('Filme (VOD) werden aktualisiert...', () async {
      await ref.read(vodControllerProvider).syncVodCategories(force: true, rethrowOnError: true);
      await ref.read(vodControllerProvider).syncAllVodStreams(force: true, rethrowOnError: true);
    });
  }

  void _syncSeries() {
    _runSync('Serien werden aktualisiert...', () async {
      await ref.read(seriesControllerProvider).syncSeriesCategories(force: true, rethrowOnError: true);
      await ref.read(seriesControllerProvider).syncAllSeriesStreams(force: true, rethrowOnError: true);
    });
  }

  void _syncEpg() {
    _runSync('EPG TV Guide wird aktualisiert...', () async {
      await ref.read(epgControllerProvider).syncEpgData(force: true);
    });
  }

  void _syncAll() {
    _runSync('1/4: Live TV wird aktualisiert...', () async {
      await ref.read(liveTvControllerProvider).syncLiveCategories(force: true, rethrowOnError: true);
      await ref.read(liveTvControllerProvider).syncAllLiveStreams(force: true, rethrowOnError: true);
      if (!mounted) return;

      setState(() => _currentStatus = '2/4: Filme (VOD) werden aktualisiert...');
      await ref.read(vodControllerProvider).syncVodCategories(force: true, rethrowOnError: true);
      await ref.read(vodControllerProvider).syncAllVodStreams(force: true, rethrowOnError: true);
      if (!mounted) return;

      setState(() => _currentStatus = '3/4: Serien werden aktualisiert...');
      await ref.read(seriesControllerProvider).syncSeriesCategories(force: true, rethrowOnError: true);
      await ref.read(seriesControllerProvider).syncAllSeriesStreams(force: true, rethrowOnError: true);
      if (!mounted) return;

      setState(() => _currentStatus = '4/4: EPG TV Guide wird aktualisiert...');
      await ref.read(epgControllerProvider).syncEpgData(force: true);
    });
  }

  void _syncM3u() {
    _runSync('M3U Playlist wird geladen...', () async {
      await ref.read(liveTvControllerProvider).syncAllLiveStreams(force: true, rethrowOnError: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
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
          constraints: const BoxConstraints(maxHeight: 560),
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
          child: _buildBody(isM3u),
        ),
      ),
    );
  }

  Widget _buildBody(bool isM3u) {
    switch (_state) {
      case SyncModalState.syncing:
        return _buildSyncingView();
      case SyncModalState.success:
        return _buildSuccessView();
      case SyncModalState.error:
        return _buildErrorView();
      case SyncModalState.idle:
        return _buildIdleView(isM3u);
    }
  }

  Widget _buildSyncingView() {
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
          const Text(
            'Bitte warten, Playlist-Daten werden synchronisiert...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.white60),
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

  Widget _buildErrorView() {
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
          const Text(
            'Fehler bei der Synchronisierung',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Unbekannter Netzwerkfehler',
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
                  child: const Text('Erneut versuchen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  child: const Text('Schließen', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdleView(bool isM3u) {
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
              const Expanded(
                child: Text(
                  'Playlist aktualisieren',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isM3u) ...[
                  _buildSyncRow(
                    icon: Icons.playlist_play_rounded,
                    title: 'M3U Playlist & Sender',
                    subtitle: 'Zuletzt aktualisiert: ${_formatTimestamp(_lastLiveSync)}',
                    buttonLabel: 'Aktualisieren',
                    onPressed: _syncM3u,
                    autofocus: true,
                  ),
                ] else ...[
                  _buildSyncRow(
                    icon: Icons.tv_rounded,
                    title: 'Live TV',
                    subtitle: 'Zuletzt aktualisiert: ${_formatTimestamp(_lastLiveSync)}',
                    buttonLabel: 'Aktualisieren',
                    onPressed: _syncLive,
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  _buildSyncRow(
                    icon: Icons.movie_rounded,
                    title: 'Filme (VOD)',
                    subtitle: 'Zuletzt aktualisiert: ${_formatTimestamp(_lastVodSync)}',
                    buttonLabel: 'Aktualisieren',
                    onPressed: _syncVod,
                  ),
                  const SizedBox(height: 10),
                  _buildSyncRow(
                    icon: Icons.video_library_rounded,
                    title: 'Serien',
                    subtitle: 'Zuletzt aktualisiert: ${_formatTimestamp(_lastSeriesSync)}',
                    buttonLabel: 'Aktualisieren',
                    onPressed: _syncSeries,
                  ),
                  const SizedBox(height: 10),
                  _buildSyncRow(
                    icon: Icons.table_chart_rounded,
                    title: 'EPG TV Guide',
                    subtitle: 'Zuletzt aktualisiert: ${_formatTimestamp(_lastEpgSync)}',
                    buttonLabel: 'Aktualisieren',
                    onPressed: _syncEpg,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 16),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(12),
                    focusScale: 1.02,
                    focusBorderColor: const Color(0xFFB388FF),
                    onPressed: _syncAll,
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.all_inclusive_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Alles auf einmal aktualisieren',
                            style: TextStyle(
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
