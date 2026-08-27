class VpnConfigParser {
  static Map<String, String> parse(String confContent) {
    final Map<String, String> config = {};
    
    final lines = confContent.split('\n');
    String currentSection = '';

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1);
        continue;
      }

      final parts = line.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        
        // For wireguard_flutter, we often need specific keys mapped
        if (currentSection == 'Interface') {
          if (key == 'PrivateKey') config['privateKey'] = value;
          if (key == 'Address') config['address'] = value;
          if (key == 'DNS') config['dns'] = value;
        } else if (currentSection == 'Peer') {
          if (key == 'PublicKey') config['publicKey'] = value;
          if (key == 'Endpoint') config['endpoint'] = value;
          if (key == 'AllowedIPs') config['allowedIPs'] = value;
        }
      }
    }
    return config;
  }
}
