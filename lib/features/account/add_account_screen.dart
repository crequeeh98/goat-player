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
import '../../core/database/daos/account_dao.dart';
import '../../core/network/xtream_client.dart';
import '../../core/remote_sync/remote_sync_service.dart';
import '../../core/settings/locale_controller.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/tv_text_field.dart';

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
  bool _syncLiveTv = true;
  bool _syncMovies = true;
  bool _syncSeries = true;

  AddAccountMode _selectedMode = AddAccountMode.manual;
  PlaylistType _playlistType = PlaylistType.xtream;

  PairingSession? _session;
  bool _isLoadingSession = false;
  String? _sessionError;
  StreamSubscription<RemoteSyncEvent>? _remoteSubscription;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _playlistReceived = false;
  String? _remoteSyncErrorMessage;
  bool _isClosingSession = false;
  late final RemoteSyncService _syncService;

  late final FocusNode _remoteTabFocusNode;
  late final FocusNode _manualTabFocusNode;
  late final FocusNode _xtreamTypeFocusNode;
  late final FocusNode _m3uTypeFocusNode;
  late final FocusNode _qrDoneFocusNode;
  late final FocusNode _qrNewPinFocusNode;
  late final FocusNode _nameFocusNode;
  late final FocusNode _urlFocusNode;
  late final FocusNode _userFocusNode;
  late final FocusNode _passFocusNode;
  late final FocusNode _submitFocusNode;

  @override
  void initState() {
    super.initState();
    _remoteTabFocusNode = FocusNode(debugLabel: 'remoteTab');
    _manualTabFocusNode = FocusNode(debugLabel: 'manualTab');
    _xtreamTypeFocusNode = FocusNode(debugLabel: 'xtreamType');
    _m3uTypeFocusNode = FocusNode(debugLabel: 'm3uType');
    _qrDoneFocusNode = FocusNode(debugLabel: 'qrDone');
    _qrNewPinFocusNode = FocusNode(debugLabel: 'qrNewPin');
    _nameFocusNode = FocusNode(
      debugLabel: 'name',
      onKeyEvent: (node, event) => _handleFieldNavigation(
        event,
        up: _playlistType == PlaylistType.xtream ? _xtreamTypeFocusNode : _m3uTypeFocusNode,
        down: _urlFocusNode,
      ),
    );
    _urlFocusNode = FocusNode(
      debugLabel: 'url',
      onKeyEvent: (node, event) => _handleFieldNavigation(
        event,
        up: _nameFocusNode,
        down: _playlistType == PlaylistType.xtream ? _userFocusNode : _submitFocusNode,
      ),
    );
    _userFocusNode = FocusNode(
      debugLabel: 'user',
      onKeyEvent: (node, event) => _handleFieldNavigation(event, up: _urlFocusNode, down: _passFocusNode),
    );
    _passFocusNode = FocusNode(
      debugLabel: 'pass',
      onKeyEvent: (node, event) => _handleFieldNavigation(event, up: _userFocusNode, down: _submitFocusNode),
    );
    _submitFocusNode = FocusNode(
      debugLabel: 'submit',
      onKeyEvent: (node, event) => _handleFieldNavigation(
        event,
        up: _playlistType == PlaylistType.xtream ? _passFocusNode : _urlFocusNode,
      ),
    );

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
    _syncService = ref.read(remoteSyncServiceProvider);
    if (widget.accountToEdit != null) {
      _playlistNameController.text = widget.accountToEdit!.playlistName ?? '';
      _serverUrlController.text = widget.accountToEdit!.serverUrl;
      _usernameController.text = widget.accountToEdit!.username;
      _passwordController.text = widget.accountToEdit!.password;
      _syncLiveTv = widget.accountToEdit!.syncLiveTv;
      _syncMovies = widget.accountToEdit!.syncMovies;
      _syncSeries = widget.accountToEdit!.syncSeries;
      if (widget.accountToEdit!.username.isEmpty || widget.accountToEdit!.serverUrl.contains('.m3u')) {
        _playlistType = PlaylistType.m3u;
      }
    } else if (GoatPlatform.isTv) {
      _selectedMode = AddAccountMode.remote;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _session == null) {
          _initRemoteSession();
        }
      });
    }
  }

  KeyEventResult _handleFieldNavigation(KeyEvent event, {FocusNode? up, FocusNode? down}) {
    if (!GoatPlatform.isTv) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown && down != null) {
        down.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && up != null) {
        up.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
      _remoteSyncErrorMessage = null;
    });

    try {
      final session = await _syncService.startPairingSession();

      _remoteSubscription?.cancel();
      _countdownTimer?.cancel();

      _remoteSubscription = _syncService.listenForRemoteEvents(session.deviceId).listen(
        (event) {
          if (!mounted) return;
          if (event.type == RemoteSyncEventType.error) {
            setState(() {
              _playlistReceived = false;
              _remoteSyncErrorMessage = event.message;
            });
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(event.message),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          setState(() {
            _remoteSyncErrorMessage = null;
            _playlistReceived = true;
          });

          final l10n = AppLocalizations.of(context)!;
          final isDe = l10n.localeName == 'de';
          String toastMsg = event.message;
          if (event.type == RemoteSyncEventType.accountAdded) {
            toastMsg = l10n.playlistReceived;
          } else if (event.type == RemoteSyncEventType.accountUpdated) {
            toastMsg = isDe ? 'Playlist aktualisiert' : 'Playlist updated';
            if (event.account != null) {
              final active = ref.read(activeAccountProvider);
              if (active != null && active.id == event.account!.id) {
                ref.read(activeAccountProvider.notifier).set(event.account);
              }
            }
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
    var effectiveType = _playlistType;

    try {
      final dao = ref.read(accountDaoProvider);
      final isDe = AppLocalizations.of(context)!.localeName == 'de';

      // Auto-detect Xtream credentials embedded in an M3U URL pasted into the M3U tab
      String server = _serverUrlController.text.trim();
      String user = _usernameController.text.trim();
      String pass = _passwordController.text.trim();
      if (effectiveType == PlaylistType.m3u) {
        final parsedXtream = XtreamClient.tryParseXtreamFromM3uUrl(server);
        if (parsedXtream != null) {
          effectiveType = PlaylistType.xtream;
          server = parsedXtream.serverUrl;
          user = parsedXtream.username;
          pass = parsedXtream.password;
        }
      }

      if (effectiveType == PlaylistType.m3u) {
        final m3uUrl = server;
        final uri = Uri.tryParse(m3uUrl);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw const FormatException('Invalid URL');
        }
        String playlistName = _playlistNameController.text.trim();
        if (playlistName.isEmpty) {
          playlistName = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'M3U Playlist');
          playlistName = playlistName.replaceAll(RegExp(r'\.(m3u8?)$', caseSensitive: false), '').toUpperCase();
        }

        if (widget.accountToEdit != null && widget.accountToEdit!.serverUrl.trim() == m3uUrl) {
          await dao.updateAccount(
            widget.accountToEdit!.copyWith(
              playlistName: drift.Value(playlistName),
            ),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isDe ? 'Playlist aktualisiert' : 'Playlist updated'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
          return;
        }

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
        final rawName = _playlistNameController.text.trim();
        final playlistName = rawName.isEmpty ? null : rawName;

        final oldAcc = widget.accountToEdit;
        final credentialsChanged = oldAcc == null ||
            oldAcc.serverUrl != server ||
            oldAcc.username != user ||
            oldAcc.password != pass;

        ({int expDate, int? maxConnections, bool isTrial})? meta;
        if (credentialsChanged) {
          final client = XtreamClient(
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
              ),
            ),
            baseUrl: server,
            username: user,
            password: pass,
          );
          final authData = await client.authenticate();
          final userInfo = authData['user_info'];
          final isAuthOk = userInfo is Map && (userInfo['auth'] == 1 || userInfo['auth'] == '1');
          if (!isAuthOk) {
            throw Exception(
              isDe
                  ? 'Anmeldung fehlgeschlagen: Zugangsdaten ungültig oder Konto inaktiv.'
                  : 'Authentication failed: Invalid credentials or inactive account.',
            );
          }
          meta = AccountDao.parseXtreamUserInfo(userInfo);
        }

        if (oldAcc != null) {
          await dao.updateAccount(
            oldAcc.copyWith(
              playlistName: drift.Value(playlistName),
              serverUrl: server,
              username: user,
              password: pass,
              expDate: drift.Value(meta != null ? meta.expDate : oldAcc.expDate),
              maxConnections: drift.Value(meta != null ? meta.maxConnections : oldAcc.maxConnections),
              isTrial: meta != null ? meta.isTrial : oldAcc.isTrial,
              syncLiveTv: _syncLiveTv,
              syncMovies: _syncMovies,
              syncSeries: _syncSeries,
            ),
          );
          if (credentialsChanged) {
            await ref.read(streamDaoProvider).clearAllStreams(oldAcc.id);
            await ref.read(categoryDaoProvider).clearCategories(oldAcc.id, 'live');
            await ref.read(categoryDaoProvider).clearCategories(oldAcc.id, 'movie');
            await ref.read(categoryDaoProvider).clearCategories(oldAcc.id, 'series');
            await ref.read(epgDaoProvider).clearPrograms(oldAcc.id);
            final prefs = ref.read(sharedPreferencesProvider);
            await prefs.remove('last_sync_categories_live_${oldAcc.id}');
            await prefs.remove('last_sync_all_live_${oldAcc.id}');
            await prefs.remove('last_sync_categories_vod_${oldAcc.id}');
            await prefs.remove('last_sync_all_vod_${oldAcc.id}');
            await prefs.remove('last_sync_categories_series_${oldAcc.id}');
            await prefs.remove('last_sync_all_series_${oldAcc.id}');
            await prefs.remove('last_sync_epg_${oldAcc.id}');
          } else {
            // Purge if disabled
            if (oldAcc.syncLiveTv && !_syncLiveTv) {
              await ref.read(streamDaoProvider).clearStreamsByType(oldAcc.id, 'live');
              await ref.read(categoryDaoProvider).clearCategories(oldAcc.id, 'live');
            }
            if (oldAcc.syncMovies && !_syncMovies) {
              await ref.read(streamDaoProvider).clearStreamsByType(oldAcc.id, 'movie');
              await ref.read(categoryDaoProvider).clearCategories(oldAcc.id, 'movie');
            }
            if (oldAcc.syncSeries && !_syncSeries) {
              await ref.read(streamDaoProvider).clearStreamsByType(oldAcc.id, 'series');
              await ref.read(categoryDaoProvider).clearCategories(oldAcc.id, 'series');
            }
          }
        } else {
          await dao.insertAccount(
            AccountsCompanion.insert(
              playlistName: drift.Value(playlistName),
              serverUrl: server,
              username: user,
              password: pass,
              expDate: drift.Value(meta!.expDate),
              maxConnections: drift.Value(meta.maxConnections),
              isTrial: drift.Value(meta.isTrial),
              syncLiveTv: drift.Value(_syncLiveTv),
              syncMovies: drift.Value(_syncMovies),
              syncSeries: drift.Value(_syncSeries),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final isDe = Localizations.localeOf(context).languageCode == 'de';
        final friendlyMsg = XtreamClient.formatUserFriendlyError(
          e,
          isDe: isDe,
          isM3u: effectiveType == PlaylistType.m3u,
        );
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    _remoteTabFocusNode.dispose();
    _manualTabFocusNode.dispose();
    _xtreamTypeFocusNode.dispose();
    _m3uTypeFocusNode.dispose();
    _qrDoneFocusNode.dispose();
    _qrNewPinFocusNode.dispose();
    _nameFocusNode.dispose();
    _urlFocusNode.dispose();
    _userFocusNode.dispose();
    _passFocusNode.dispose();
    _submitFocusNode.dispose();
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
          backgroundColor: const Color(0xFF0D0915),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: GoatPlatform.isTv ? 38 : null,
          title: Padding(
            padding: EdgeInsets.only(top: GoatPlatform.isTv ? 2.0 : 0),
            child: Text(isEditing ? l10n.editAccount : l10n.addAccount),
          ),
          leading: GoatPlatform.isTv
              ? Padding(
                  padding: const EdgeInsets.only(left: 20.0, top: 2.0),
                  child: TvFocusable(
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _isClosingSession ? null : _handleCloseAndPop,
                    child: const Center(child: Icon(Icons.arrow_back)),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _isClosingSession ? null : _handleCloseAndPop,
                ),
        ),
      body: SafeArea(
        minimum: EdgeInsets.symmetric(
          horizontal: GoatPlatform.isTv ? 32.0 : 0,
          vertical: 0,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: GoatPlatform.isTv ? 500 : (GoatPlatform.isDesktop ? 480 : 420)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: GoatPlatform.isTv ? 16.0 : 20.0,
                vertical: GoatPlatform.isTv ? 8.0 : (GoatPlatform.isDesktop ? 16.0 : 10.0),
              ),
              child: SingleChildScrollView(
                clipBehavior: Clip.hardEdge,
                child: isEditing
                    ? _buildManualForm(l10n)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mode Selector (Manual vs Remote)
                          if (GoatPlatform.isTv)
                            Row(
                              children: [
                                Expanded(
                                  child: TvFocusable(
                                    focusNode: _remoteTabFocusNode,
                                    autofocus: _selectedMode == AddAccountMode.remote,
                                    borderRadius: BorderRadius.circular(10),
                                    onPressed: () => _onModeChanged(AddAccountMode.remote),
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                          _manualTabFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          if (_selectedMode == AddAccountMode.remote) {
                                            _qrDoneFocusNode.requestFocus();
                                          } else {
                                            (_playlistType == PlaylistType.xtream ? _xtreamTypeFocusNode : _m3uTypeFocusNode).requestFocus();
                                          }
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: GoatPlatform.isTv ? 4 : 10, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedMode == AddAccountMode.remote
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFF1E1730),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedMode == AddAccountMode.remote
                                              ? const Color(0xFFB388FF)
                                              : Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.qr_code_2, size: 16, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              l10n.linkViaWeb,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: GoatPlatform.isTv ? 12 : 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TvFocusable(
                                    focusNode: _manualTabFocusNode,
                                    autofocus: _selectedMode == AddAccountMode.manual,
                                    borderRadius: BorderRadius.circular(10),
                                    onPressed: () => _onModeChanged(AddAccountMode.manual),
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                          _remoteTabFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          if (_selectedMode == AddAccountMode.remote) {
                                            _qrNewPinFocusNode.requestFocus();
                                          } else {
                                            (_playlistType == PlaylistType.xtream ? _xtreamTypeFocusNode : _m3uTypeFocusNode).requestFocus();
                                          }
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: GoatPlatform.isTv ? 4 : 10, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedMode == AddAccountMode.manual
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFF1E1730),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedMode == AddAccountMode.manual
                                              ? const Color(0xFFB388FF)
                                              : Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.keyboard_outlined, size: 16, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              l10n.manualSetup,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: GoatPlatform.isTv ? 12 : 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
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
                                backgroundColor: const Color(0xFF161026),
                                foregroundColor: Colors.white70,
                                selectedBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                selectedForegroundColor: const Color(0xFFB388FF),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                            ),
                          SizedBox(height: GoatPlatform.isTv ? 4 : 12),
                          _selectedMode == AddAccountMode.manual
                              ? _buildManualForm(l10n)
                              : _buildRemotePairingView(l10n),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildManualForm(AppLocalizations l10n) {
    final isDe = l10n.localeName == 'de';
    final fieldGap = GoatPlatform.isTv ? 8.0 : (GoatPlatform.isDesktop ? 14.0 : 10.0);
    final sectionGap = GoatPlatform.isTv ? 10.0 : (GoatPlatform.isDesktop ? 16.0 : 12.0);
    final buttonGap = GoatPlatform.isTv ? 10.0 : (GoatPlatform.isDesktop ? 22.0 : 16.0);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Playlist Type Selector
          if (GoatPlatform.isTv)
            Row(
              children: [
                Expanded(
                  child: TvFocusable(
                    focusNode: _xtreamTypeFocusNode,
                    focusScale: 1.0,
                    autofocus: widget.accountToEdit != null && _playlistType == PlaylistType.xtream,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => setState(() => _playlistType = PlaylistType.xtream),
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _m3uTypeFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.accountToEdit == null) {
                          _manualTabFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          _nameFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: GoatPlatform.isTv ? 4 : 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _playlistType == PlaylistType.xtream
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF1E1730),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _playlistType == PlaylistType.xtream
                              ? const Color(0xFFB388FF)
                              : Colors.white12,
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dns_outlined, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Xtream Codes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TvFocusable(
                    focusNode: _m3uTypeFocusNode,
                    focusScale: 1.0,
                    autofocus: widget.accountToEdit != null && _playlistType == PlaylistType.m3u,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => setState(() => _playlistType = PlaylistType.m3u),
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _xtreamTypeFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.accountToEdit == null) {
                          _manualTabFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          _nameFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: GoatPlatform.isTv ? 4 : 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _playlistType == PlaylistType.m3u
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF1E1730),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _playlistType == PlaylistType.m3u
                              ? const Color(0xFFB388FF)
                              : Colors.white12,
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.playlist_play_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('M3U URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
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
                backgroundColor: const Color(0xFF161026),
                foregroundColor: Colors.white70,
                selectedBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                selectedForegroundColor: const Color(0xFFB388FF),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
          SizedBox(height: fieldGap),
          TvTextField(
            controller: _playlistNameController,
            focusNode: _nameFocusNode,
            contentPadding: GoatPlatform.isTv ? const EdgeInsets.fromLTRB(10, 5, 10, 5) : null,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _urlFocusNode.requestFocus(),
            labelText: l10n.playlistName,
            hintText: _playlistType == PlaylistType.m3u ? l10n.m3uPlaylistNameHint : l10n.m3uPlaylistNameDefault,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
            ),
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
          SizedBox(height: fieldGap),
          TvTextField(
            controller: _serverUrlController,
            focusNode: _urlFocusNode,
            contentPadding: GoatPlatform.isTv ? const EdgeInsets.fromLTRB(10, 5, 10, 5) : null,
            keyboardType: TextInputType.url,
            textInputAction: _playlistType == PlaylistType.xtream ? TextInputAction.next : TextInputAction.done,
            onChanged: (val) {
              if (_playlistType != PlaylistType.m3u) return;
              final parsed = XtreamClient.tryParseXtreamFromM3uUrl(val);
              if (parsed == null) return;
              setState(() {
                _playlistType = PlaylistType.xtream;
                _serverUrlController.text = parsed.serverUrl;
                _usernameController.text = parsed.username;
                _passwordController.text = parsed.password;
              });
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isDe
                        ? 'Xtream-Zugangsdaten aus M3U-Link erkannt'
                        : 'Xtream credentials detected from M3U link',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onSubmitted: (_) => _playlistType == PlaylistType.xtream
                ? _userFocusNode.requestFocus()
                : _submitFocusNode.requestFocus(),
            labelText: _playlistType == PlaylistType.m3u ? l10n.m3uPlaylistUrl : l10n.serverUrl,
            hintText: _playlistType == PlaylistType.m3u ? l10n.m3uUrlHint : 'http://example.com:8080',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
            ),
            prefixIcon: const Icon(Icons.link),
            validator: (v) => v!.trim().isEmpty ? l10n.fieldRequired : null,
          ),
          if (_playlistType == PlaylistType.xtream) ...[
            SizedBox(height: fieldGap),
            TvTextField(
              controller: _usernameController,
              focusNode: _userFocusNode,
              contentPadding: GoatPlatform.isTv ? const EdgeInsets.fromLTRB(10, 5, 10, 5) : null,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passFocusNode.requestFocus(),
              labelText: l10n.username,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
              ),
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => (_playlistType == PlaylistType.xtream && v!.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            SizedBox(height: fieldGap),
            TvTextField(
              controller: _passwordController,
              focusNode: _passFocusNode,
              contentPadding: GoatPlatform.isTv ? const EdgeInsets.fromLTRB(10, 5, 10, 5) : null,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitFocusNode.requestFocus(),
              labelText: l10n.password,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              validator: (v) => (_playlistType == PlaylistType.xtream && v!.trim().isEmpty) ? l10n.fieldRequired : null,
            ),
            SizedBox(height: sectionGap),
            Text(
              isDe ? 'Inhalte synchronisieren' : 'Synchronize Content',
              style: TextStyle(
                fontSize: GoatPlatform.isTv ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: GoatPlatform.isTv ? 4 : 8),
            Row(
              children: [
                Expanded(
                  child: _buildScopeToggleChip(
                    label: l10n.liveTv,
                    icon: Icons.tv_rounded,
                    isSelected: _syncLiveTv,
                    onTap: () {
                      if (_syncLiveTv && !_syncMovies && !_syncSeries) return;
                      setState(() => _syncLiveTv = !_syncLiveTv);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildScopeToggleChip(
                    label: l10n.movies,
                    icon: Icons.movie_rounded,
                    isSelected: _syncMovies,
                    onTap: () {
                      if (_syncMovies && !_syncLiveTv && !_syncSeries) return;
                      setState(() => _syncMovies = !_syncMovies);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildScopeToggleChip(
                    label: l10n.series,
                    icon: Icons.video_library_rounded,
                    isSelected: _syncSeries,
                    onTap: () {
                      if (_syncSeries && !_syncLiveTv && !_syncMovies) return;
                      setState(() => _syncSeries = !_syncSeries);
                    },
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: buttonGap),
          TvFocusable(
            focusNode: _submitFocusNode,
            borderRadius: BorderRadius.circular(12),
            onPressed: _isLoading ? null : _submit,
            child: SizedBox(
              height: GoatPlatform.isTv ? 36 : 48,
              width: double.infinity,
              child: ElevatedButton(
                focusNode: FocusNode(canRequestFocus: false),
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _playlistType == PlaylistType.m3u ? l10n.connectM3uPlaylist : l10n.login,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeToggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(10),
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: GoatPlatform.isTv ? 4 : 7),
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
              icon,
              size: GoatPlatform.isTv ? 14 : 16,
              color: isSelected ? const Color(0xFFB388FF) : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: GoatPlatform.isTv ? 11.5 : 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
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
            if (GoatPlatform.isTv)
              TvFocusable(
                autofocus: true,
                borderRadius: BorderRadius.circular(10),
                onPressed: _initRemoteSession,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            else
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.scanWithPhone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        _buildQrCard(context),
        const SizedBox(height: 8),
        _buildPairingDetails(context, l10n),
      ],
    );
  }

  Widget _buildQrCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: QrImageView(
        data: _session!.qrUrl,
        version: QrVersions.auto,
        size: GoatPlatform.isTv ? 120 : 130,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPairingDetails(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact side-by-side Device ID & PIN container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left: Device ID
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.deviceId, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        _session!.deviceId,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      if (!GoatPlatform.isTv) ...[
                        const SizedBox(width: 4),
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
                    ],
                  ),
                ],
              ),
              Container(width: 1, height: 28, color: Colors.white12),
              // Right: PIN
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.pairingPin, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  const SizedBox(height: 2),
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
                      if (!GoatPlatform.isTv) ...[
                        const SizedBox(width: 4),
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
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Web portal + Timer row
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${l10n.orVisitWebsite} ', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                SelectableText(
                  RemoteSyncService.defaultPortalUrl,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 12, color: Colors.white60),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_remainingTime),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                if (!GoatPlatform.isTv) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.newPin,
                    icon: const Icon(Icons.refresh, size: 14),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _initRemoteSession,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_remoteSyncErrorMessage != null && !_playlistReceived) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _remoteSyncErrorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (GoatPlatform.isTv) ...[
          if (!_playlistReceived)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFB388FF).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB388FF)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.waitingForPlaylist,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB388FF),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 15, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Text(
                  l10n.localeName == 'de' ? 'Playlist empfangen!' : 'Playlist received!',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TvFocusable(
                focusNode: _qrDoneFocusNode,
                borderRadius: BorderRadius.circular(10),
                onPressed: _isClosingSession ? null : _handleCloseAndPop,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _qrNewPinFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _remoteTabFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: _playlistReceived
                        ? const Color(0xFF10B981)
                        : const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        l10n.done,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TvFocusable(
                focusNode: _qrNewPinFocusNode,
                borderRadius: BorderRadius.circular(10),
                onPressed: _initRemoteSession,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _qrDoneFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _manualTabFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1730),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        l10n.newPin,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Live Pulse Status converts into Done button in-place
          if (!_playlistReceived)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFB388FF).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB388FF)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.waitingForPlaylist,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB388FF),
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
      ],
    );
  }
}
