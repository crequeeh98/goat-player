import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'dart:io' show Platform;
import '../../../core/vpn/wireguard_service.dart';
import '../../../../core/settings/locale_controller.dart';

class VpnImportDialog extends ConsumerStatefulWidget {
  const VpnImportDialog({super.key});

  @override
  ConsumerState<VpnImportDialog> createState() => _VpnImportDialogState();
}

class _VpnImportDialogState extends ConsumerState<VpnImportDialog> {
  final _confController = TextEditingController();
  bool _isConnecting = false;
  String? _error;
  bool _hasSavedConfig = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString('wireguard_conf');
    if (saved != null && saved.trim().isNotEmpty) {
      _confController.text = saved.trim();
      _hasSavedConfig = true;
    }
  }

  @override
  void dispose() {
    _confController.dispose();
    super.dispose();
  }

  void _saveConfig(String val) {
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = val.trim();
    if (trimmed.isNotEmpty) {
      prefs.setString('wireguard_conf', trimmed);
      setState(() => _hasSavedConfig = true);
    } else {
      prefs.remove('wireguard_conf');
      setState(() => _hasSavedConfig = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _confController.text = data.text!.trim();
        _error = null;
      });
      _saveConfig(data.text!);
    }
  }

  void _clearConfig() {
    setState(() {
      _confController.clear();
      _hasSavedConfig = false;
      _error = null;
    });
    ref.read(sharedPreferencesProvider).remove('wireguard_conf');
  }

  Future<void> _connect() async {
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final confText = _confController.text.trim();
    if (confText.isEmpty) {
      setState(() => _error = isDe ? 'Bitte fügen Sie zuerst eine WireGuard-Konfiguration ein.' : 'Please paste a WireGuard config first.');
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    _saveConfig(confText);

    try {
      final vpn = ref.read(wireguardServiceProvider);
      await vpn.connect(confText);
      
      // Wait up to 10 seconds for the state to become connected
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final stage = ref.read(vpnStageProvider).value;
        if (stage == VpnStage.connected) {
          return;
        }
      }
      
      if (mounted) {
        setState(() {
          _error = isDe
              ? 'Verbindungs-Timeout. Überprüfen Sie Ihre Konfigurationsdaten und Zugriffsrechte.'
              : 'Connection timed out. Check your config, keys, and admin rights.';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (Platform.isWindows && msg.contains('5')) {
          msg = isDe
              ? 'Administratorrechte erforderlich. Bitte starten Sie die App als Administrator, um WireGuard unter Windows zu aktivieren.'
              : 'Administrator rights required. Please run app as Administrator to activate WireGuard on Windows.';
        }
        setState(() {
          _error = msg;
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
    final isDe = Localizations.localeOf(context).languageCode == 'de';
    final stageAsync = ref.watch(vpnStageProvider);
    final stage = stageAsync.value;
    final isConnected = stage == VpnStage.connected;
    
    // Automatically clear the loading state when connected
    if (_isConnecting && isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _error = null;
          });
        }
      });
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF18181A),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppLocalizations.of(context)!.importWireguard, style: const TextStyle(fontSize: 18)),
          if (_hasSavedConfig && !isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    isDe ? 'Gespeichert' : 'Config Saved',
                    style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isConnected) ...[
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.security, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      isDe ? 'WireGuard VPN ist verbunden' : 'WireGuard VPN is Connected',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.pasteConfContent,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste, size: 15),
                    label: Text(isDe ? 'Einfügen' : 'Paste', style: const TextStyle(fontSize: 12)),
                  ),
                  if (_confController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Colors.white38),
                      tooltip: isDe ? 'Löschen' : 'Clear config',
                      onPressed: _clearConfig,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confController,
                maxLines: 8,
                onChanged: _saveConfig,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                decoration: InputDecoration(
                  hintText: '[Interface]\nPrivateKey = ...\nAddress = ...\n\n[Peer]\nPublicKey = ...\nEndpoint = ...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF101012),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.info_outline, size: 13, color: Colors.white38),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isDe
                          ? 'Hinweis: Viele IPTV-Server blockieren bekannte VPN-Server-IPs. Testen Sie bei Problemen einen anderen VPN-Standort.'
                          : 'Note: Many IPTV providers block known commercial VPN server IPs. If streams do not load, test a different VPN location.',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
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
            child: Text(AppLocalizations.of(context)!.disconnect, style: const TextStyle(color: Colors.white)),
          )
        else
          ElevatedButton.icon(
            onPressed: _isConnecting ? null : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: _isConnecting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.power_settings_new, size: 18),
            label: Text(_isConnecting ? (isDe ? 'Verbinde...' : 'Connecting...') : (isDe ? 'VPN Verbinden' : 'Connect VPN')),
          ),
      ],
    );
  }
}
