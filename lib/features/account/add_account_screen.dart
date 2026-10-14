import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dio/dio.dart';
import '../../main.dart';
import '../../core/utils/m3u_isolate_parser.dart';
import '../../core/utils/title_sanitizer.dart';
import '../../core/database/app_database.dart';
import '../../core/remote_sync/remote_sync_service.dart';
import '../../core/utils/platform_utils.dart';

enum AddAccountMode { manual, remote }
enum PlaylistType { xtream, m3u }

class AddAccountScreen extends ConsumerStatefulWidget {
  final Account? accountToEdit;
  const AddAccountScreen({super.key, this.accountToEdit});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playlistNameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  AddAccountMode _selectedMode = AddAccountMode.manual;
  PlaylistType _playlistType = PlaylistType.xtream;

  PairingSession? _session;
  bool _isLoadingSession = false;
  String? _sessionError;
  StreamSubscription<RemoteSyncEvent>? _remoteSubscription;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _playlistReceived = false;
  bool _isClosingSession = false;
  late final RemoteSyncService _syncService;

  @override
  void initState() {
    super.initState();
    if (GoatPlatform.isMobile) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _syncService = ref.read(remoteSyncServiceProvider);
    if (widget.accountToEdit != null) {
      _playlistNameController.text = widget.accountToEdit!.playlistName ?? '';
      _serverUrlController.text = widget.accountToEdit!.serverUrl;
      _usernameController.text = widget.accountToEdit!.username;
      _passwordController.text = widget.accountToEdit!.password;
      if (widget.accountToEdit!.username.isEmpty || widget.accountToEdit!.serverUrl.contains('.m3u')) {
        _playlistType = PlaylistType.m3u;
      }
    }
  }

  void _onModeChanged(AddAccountMode mode) {
    if (_selectedMode == AddAccountMode.remote && mode == AddAccountMode.manual && _session != null) {
      _syncService.closePairingSession(_session!.deviceId);
    }
    setState(() => _selectedMode = mode);
    if (mode == AddAccountMode.remote && _session == null) {
      _initRemoteSession();
    }
  }

  Future<void> _initRemoteSession() async {
    setState(() {
      _isLoadingSession = true;
      _sessionError = null;
      _playlistReceived = false;
    });

    try {
      final session = await _syncService.startPairingSession();

      _remoteSubscription?.cancel();
      _countdownTimer?.cancel();

      _remoteSubscription = _syncService.listenForRemoteEvents(session.deviceId).listen(
        (event) {
          if (!mounted) return;
          setState(() => _playlistReceived = true);

          final l10n = AppLocalizations.of(context)!;
          String toastMsg = event.message;
          if (event.type == RemoteSyncEventType.accountAdded) {
            toastMsg = l10n.playlistReceived;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(toastMsg),
              backgroundColor: event.type == RemoteSyncEventType.accountDeleted
                  ? Colors.orangeAccent
                  : Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onError: (e) {
          debugPrint('Remote playlist listen error: $e');
        },
      );

      _remainingTime = session.expiresAt.difference(DateTime.now());
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final rem = session.expiresAt.difference(DateTime.now());
        if (rem.isNegative) {
          timer.cancel();
          setState(() {
            _remainingTime = Duration.zero;
          });
          if (_session != null) {
            _syncService.closePairingSession(_session!.deviceId);
          }
        } else {
          setState(() {
            _remainingTime = rem;
          });
        }
      });

      if (mounted) {
        setState(() {
          _session = session;
          _isLoadingSession = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSession = false;
          _sessionError = e.toString();
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return '00:00';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dao = ref.read(accountDaoProvider);

      if (_playlistType == PlaylistType.m3u) {
        final m3uUrl = _serverUrlController.text.trim();
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));
        final resp = await dio.get<String>(m3uUrl);
        final content = resp.data ?? '';
        if (!content.contains('#EXTM3U') && !content.contains('#EXTINF')) {
          throw Exception('Invalid M3U playlist format');
        }
        final items = await M3uIsolateParser.parseContent(content);
        if (items.isEmpty) {
          throw Exception('No playable channels found in M3U');
        }

        String playlistName = _playlistNameController.text.trim();
        if (playlistName.isEmpty) {
          final uri = Uri.tryParse(m3uUrl);
          playlistName = uri?.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'M3U Playlist') ?? 'M3U Playlist';
          playlistName = playlistName.replaceAll(RegExp(r'\.(m3u8?)$', caseSensitive: false), '').toUpperCase();
        }

        int accountId;
        if (widget.accountToEdit != null) {
          accountId = widget.accountToEdit!.id;
          await dao.updateAccount(
            widget.accountToEdit!.copyWith(
              playlistName: drift.Value(playlistName),
              serverUrl: m3uUrl,
              username: '',
              password: '',
            ),
          );
        } else {
          accountId = await dao.insertAccount(
            AccountsCompanion.insert(
              playlistName: drift.Value(playlistName),
              serverUrl: m3uUrl,
              username: '',
              password: '',
            ),
          );
        }

        final catDao = ref.read(categoryDaoProvider);
        final streamDao = ref.read(streamDaoProvider);

        final catCompanions = <CategoriesCompanion>[];
        final streamCompanions = <StreamsCompanion>[];
        final seenCats = <String>{};

        int index = 0;
        for (final item in items) {
          index++;
          final groupName = item.groupTitle.isNotEmpty ? item.groupTitle : 'General';
          final catId = 'cat_${groupName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_')}';

          if (!seenCats.contains(catId)) {
            seenCats.add(catId);
            catCompanions.add(CategoriesCompanion.insert(
              accountId: accountId,
              categoryId: catId,
              name: groupName,
              type: 'live',
            ));
          }

          streamCompanions.add(StreamsCompanion.insert(
            accountId: accountId,
            categoryId: catId,
            streamId: 'm3u_$index',
            epgChannelId: item.tvgId.isNotEmpty ? drift.Value(item.tvgId) : const drift.Value.absent(),
            name: TitleSanitizer.sanitizeLiveTvChannel(item.title),
            streamType: 'live',
            streamIcon: item.tvgLogo.isNotEmpty ? drift.Value(item.tvgLogo) : const drift.Value.absent(),
            url: drift.Value(item.url),
          ));
        }

        await catDao.replaceCategories(accountId, 'live', catCompanions);
        await streamDao.replaceStreamsByType(accountId, 'live', streamCompanions);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('M3U playlist added (${items.length} channels)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (widget.accountToEdit != null) {
          await dao.updateAccount(
            widget.accountToEdit!.copyWith(
              playlistName: drift.Value(_playlistNameController.text.trim().isEmpty ? null : _playlistNameController.text.trim()),
              serverUrl: _serverUrlController.text.trim(),
              username: _usernameController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
        } else {
          await dao.insertAccount(
            AccountsCompanion.insert(
              playlistName: drift.Value(_playlistNameController.text.trim().isEmpty ? null : _playlistNameController.text.trim()),
              serverUrl: _serverUrlController.text.trim(),
              username: _usernameController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error}$e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  Future<void> _handleCloseAndPop() async {
    if (_isClosingSession) return;
    if (_session != null) {
      if (mounted) setState(() => _isClosingSession = true);
      try {
        await _syncService
            .closePairingSession(_session!.deviceId)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error closing pairing session: $e');
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (_session != null) {
      _syncService.closePairingSession(_session!.deviceId);
    }
    _remoteSubscription?.cancel();
    _countdownTimer?.cancel();
    _playlistNameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.accountToEdit != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleCloseAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? l10n.editAccount : l10n.addAccount),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isClosingSession ? null : _handleCloseAndPop,
          ),
        ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: isEditing
                ? SingleChildScrollView(child: _buildManualForm(l10n))
                : Column(
                    children: [
                      // Mode Selector (Manual vs Remote)
                      SegmentedButton<AddAccountMode>(
                        segments: [
                          ButtonSegment(
                            value: AddAccountMode.manual,
                            icon: const Icon(Icons.keyboard_outlined, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.manualSetup,
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: AddAccountMode.remote,
                            icon: const Icon(Icons.qr_code_2, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.linkViaWeb,
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                        selected: {_selectedMode},
                        onSelectionChanged: (set) => _onModeChanged(set.first),
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          selectedBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                          selectedForegroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _selectedMode == AddAccountMode.manual
                            ? SingleChildScrollView(child: _buildManualForm(l10n))
                            : _buildRemotePairingView(l10n),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildManualForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Playlist Type Selector
          SegmentedButton<PlaylistType>(
            segments: const [
              ButtonSegment(
                value: PlaylistType.xtream,
                icon: Icon(Icons.dns_outlined, size: 16),
                label: Text('Xtream Codes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              ButtonSegment(
                value: PlaylistType.m3u,
                icon: Icon(Icons.playlist_play_rounded, size: 16),
                label: Text('M3U URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
            selected: {_playlistType},
            onSelectionChanged: (set) => setState(() => _playlistType = set.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              selectedForegroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _playlistNameController,
            decoration: InputDecoration(
              labelText: l10n.playlistName,
              hintText: _playlistType == PlaylistType.m3u ? l10n.m3uPlaylistNameHint : l10n.m3uPlaylistNameDefault,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: _playlistType == PlaylistType.m3u ? l10n.m3uPlaylistUrl : l10n.serverUrl,
              hintText: _playlistType == PlaylistType.m3u ? l10n.m3uUrlHint : 'http://example.com:8080',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link),
            ),
            validator: (v) => v!.trim().isEmpty ? l10n.fieldRequired : null,
          ),
          if (_playlistType == PlaylistType.xtream) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.username,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (_playlistType == PlaylistType.xtream && v!.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.password,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              validator: (v) => (_playlistType == PlaylistType.xtream && v!.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _playlistType == PlaylistType.m3u ? l10n.connectM3uPlaylist : l10n.login,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemotePairingView(AppLocalizations l10n) {
    if (_isLoadingSession) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating secure session...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_sessionError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Connection error:\n$_sessionError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initRemoteSession,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_session == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      bottom: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Text(
              l10n.scanWithPhone,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),

            // QR Code Card (Compact 135px)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: QrImageView(
                data: _session!.qrUrl,
                version: QrVersions.auto,
                size: 135,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),

            // Device ID & PIN Box (Compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.deviceId, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            _session!.deviceId,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: l10n.copiedToClipboard,
                            onPressed: () {
                              final rawId = _session!.deviceId;
                              final codeToCopy = rawId.startsWith('GP-') ? rawId.substring(3) : rawId;
                              Clipboard.setData(ClipboardData(text: codeToCopy));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${l10n.deviceId}: ${l10n.copied}'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.pairingPin, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _session!.pin,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: l10n.copiedToClipboard,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _session!.pin));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${l10n.pairingPin}: ${l10n.copied}'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Web portal address in compact row
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${l10n.orVisitWebsite} ',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                SelectableText(
                  RemoteSyncService.defaultPortalUrl,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Expiry & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 13, color: Colors.white60),
                const SizedBox(width: 4),
                Text(
                  '${l10n.pinExpiresIn}: ${_formatDuration(_remainingTime)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: l10n.newPin,
                  icon: const Icon(Icons.refresh, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _initRemoteSession,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live Pulse Status converts into Done button in-place
            if (!_playlistReceived)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.waitingForPlaylist,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 15, color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  Text(
                    l10n.localeName == 'de' ? 'Playlist empfangen! Info wird geladen...' : 'Playlist received! Loading info...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isClosingSession ? null : _handleCloseAndPop,
                icon: _isClosingSession
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  l10n.done,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
