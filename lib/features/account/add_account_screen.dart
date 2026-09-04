import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:drift/drift.dart' as drift;
import 'package:qr_flutter/qr_flutter.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/remote_sync/remote_sync_service.dart';

enum AddAccountMode { manual, remote }

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

  PairingSession? _session;
  bool _isLoadingSession = false;
  String? _sessionError;
  StreamSubscription<Account>? _remoteSubscription;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _playlistReceived = false;

  @override
  void initState() {
    super.initState();
    if (widget.accountToEdit != null) {
      _playlistNameController.text = widget.accountToEdit!.playlistName ?? '';
      _serverUrlController.text = widget.accountToEdit!.serverUrl;
      _usernameController.text = widget.accountToEdit!.username;
      _passwordController.text = widget.accountToEdit!.password;
    }
  }

  void _onModeChanged(AddAccountMode mode) {
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
      final syncService = ref.read(remoteSyncServiceProvider);
      final session = await syncService.startPairingSession();

      _remoteSubscription?.cancel();
      _countdownTimer?.cancel();

      _remoteSubscription = syncService.listenForLinkedPlaylist(session.deviceId).listen(
        (newAccount) {
          if (!mounted) return;
          setState(() => _playlistReceived = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.playlistReceived),
              backgroundColor: Colors.green,
            ),
          );
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) {
              Navigator.pop(context, newAccount);
            }
          });
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

  @override
  void dispose() {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editAccount : l10n.addAccount),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: isEditing
                ? _buildManualForm(l10n)
                : Column(
                    children: [
                      // Mode Selector (Manual vs Remote)
                      SegmentedButton<AddAccountMode>(
                        segments: [
                          ButtonSegment(
                            value: AddAccountMode.manual,
                            icon: const Icon(Icons.keyboard_outlined),
                            label: Text(l10n.manualSetup),
                          ),
                          ButtonSegment(
                            value: AddAccountMode.remote,
                            icon: const Icon(Icons.qr_code_2),
                            label: Text(l10n.linkViaWeb),
                          ),
                        ],
                        selected: {_selectedMode},
                        onSelectionChanged: (set) => _onModeChanged(set.first),
                        style: SegmentedButton.styleFrom(
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
    );
  }

  Widget _buildManualForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _playlistNameController,
            decoration: InputDecoration(
              labelText: l10n.playlistName,
              hintText: 'My IPTV',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: l10n.serverUrl,
              hintText: 'http://example.com:8080',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link),
            ),
            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: l10n.username,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
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
            validator: (v) => v!.trim().isEmpty ? 'Required' : null,
          ),
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
                      l10n.login,
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

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            l10n.scanWithPhone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: _session!.qrUrl,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Device ID & PIN Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.deviceId, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    Text(
                      _session!.deviceId,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.pairingPin, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _session!.pin,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Web portal address
          Text(
            l10n.orVisitWebsite,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 3),
          SelectableText(
            RemoteSyncService.defaultPortalUrl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 12),

          // Expiry & Refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 15, color: Colors.white60),
              const SizedBox(width: 6),
              Text(
                '${l10n.pinExpiresIn}: ${_formatDuration(_remainingTime)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.newPin,
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _initRemoteSession,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Pulse Status
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _playlistReceived ? Colors.green.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _playlistReceived ? Colors.green : Colors.purple.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_playlistReceived)
                  const Icon(Icons.check_circle, size: 16, color: Colors.green)
                else
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                  ),
                const SizedBox(width: 8),
                Text(
                  _playlistReceived ? l10n.playlistReceived : l10n.waitingForPlaylist,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _playlistReceived ? Colors.green : Colors.purpleAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
