import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'vpn_config_parser.dart';

final wireguardServiceProvider = Provider<WireguardService>((ref) {
  return WireguardService();
});

final vpnStageProvider = StreamProvider<VpnStage>((ref) {
  return WireGuardFlutter.instance.vpnStageSnapshot.asBroadcastStream();
});

class WireguardService {
  final _wireguard = WireGuardFlutter.instance;
  bool _isInitialized = false;
  
  Stream<VpnStage> get vpnStageSnapshot => _wireguard.vpnStageSnapshot;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _wireguard.initialize(interfaceName: 'goatplayer_vpn');
      _isInitialized = true;
    } catch (e) {
      // Ignore if already initialized
      _isInitialized = true;
    }
  }

  Future<void> connect(String confContent) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (confContent.trim().isEmpty) {
      throw Exception('Configuration cannot be empty.');
    }
    if (!confContent.contains('[Interface]') || !confContent.contains('[Peer]')) {
      throw Exception('Invalid WireGuard configuration format.');
    }
    
    final config = VpnConfigParser.parse(confContent);
    
    // Attempt to stop any stuck previous instance, then wait to ensure it fully shuts down
    try {
      await _wireguard.stopVpn();
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (_) {}
    
    try {
      await _wireguard.startVpn(
        serverAddress: config['endpoint'] ?? '',
        wgQuickConfig: confContent,
        providerBundleIdentifier: 'com.example.goatplayer.vpn',
      );
    } catch (e) {
      throw Exception('Failed to connect to VPN: $e');
    }
  }

  Future<void> disconnect() async {
    if (!_isInitialized) return;
    try {
      await _wireguard.stopVpn();
    } catch (e) {
      throw Exception('Failed to disconnect from VPN: $e');
    }
  }
}
