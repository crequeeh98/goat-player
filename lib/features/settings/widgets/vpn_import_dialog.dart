import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import '../../../core/vpn/wireguard_service.dart';

class VpnImportDialog extends ConsumerStatefulWidget {
  const VpnImportDialog({super.key});

  @override
  ConsumerState<VpnImportDialog> createState() => _VpnImportDialogState();
}

class _VpnImportDialogState extends ConsumerState<VpnImportDialog> {
  final _confController = TextEditingController();
  bool _isConnecting = false;
  String? _error;

  @override
  void dispose() {
    _confController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final vpn = ref.read(wireguardServiceProvider);
      await vpn.connect(_confController.text);
      
      // Wait up to 10 seconds for the state to become connected
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final stage = ref.read(vpnStageProvider).value;
        if (stage == VpnStage.connected) {
          return; // The build method will handle setting _isConnecting = false
        }
      }
      
      if (mounted) {
        setState(() {
          _error = 'Connection timed out. Check your config and Private Key.';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      final vpn = ref.read(wireguardServiceProvider);
      await vpn.disconnect();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageAsync = ref.watch(vpnStageProvider);
    final stage = stageAsync.value;
    final isConnected = stage == VpnStage.connected;
    
    // Automatically clear the loading state when connected
    if (_isConnecting && isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _error = null; // Clear any old errors if we successfully connected
          });
        }
      });
    }

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.importWireguard),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected) ...[
              const Icon(Icons.security, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('VPN is currently connected.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ]
            ] else ...[
              Text(AppLocalizations.of(context)!.pasteConfContent),
              const SizedBox(height: 16),
              TextField(
                controller: _confController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '[Interface]\nPrivateKey = ...\n...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ]
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        if (isConnected)
          ElevatedButton(
            onPressed: _disconnect,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          )
        else
          ElevatedButton(
            onPressed: _isConnecting ? null : _connect,
            child: _isConnecting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(AppLocalizations.of(context)!.connect),
          ),
      ],
    );
  }
}
