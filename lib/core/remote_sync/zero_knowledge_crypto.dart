import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

class ZeroKnowledgePairingCrypto {
  static const String saltPrefix = 'GOATPlayer_Pairing_Salt_';
  static const int iterations = 10000;

  /// Derives an AES-GCM 256-bit encryption key from the PIN and Device ID via PBKDF2-HMAC-SHA256
  static Uint8List deriveKey(String pin, String deviceId) {
    final salt = '$saltPrefix${deviceId.trim().toUpperCase()}';
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = Pbkdf2Parameters(
      utf8.encode(salt) as Uint8List,
      iterations,
      32,
    );
    derivator.init(params);
    return derivator.process(utf8.encode(pin.trim()) as Uint8List);
  }

  /// Decrypts an incoming sync_action payload using AES-256-GCM.
  /// If the payload is unencrypted (legacy action), returns it unmodified.
  static Map<String, dynamic> decryptSyncAction(
    Map<String, dynamic> actionMap,
    String pin,
    String deviceId,
  ) {
    if (actionMap['encrypted'] != true ||
        actionMap['data'] == null ||
        actionMap['iv'] == null) {
      return actionMap; // Legacy unencrypted action - zero breakage
    }

    try {
      final key = deriveKey(pin, deviceId);
      final ivHex = actionMap['iv'].toString().trim();
      final dataHex = actionMap['data'].toString().trim();

      final iv = _hexToBytes(ivHex);
      final cipherWithTag = _hexToBytes(dataHex);

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
      cipher.init(false, params); // false = decrypt

      final decryptedBytes = cipher.process(cipherWithTag);
      final jsonStr = utf8.decode(decryptedBytes);
      final parsed = jsonDecode(jsonStr);

      if (parsed is Map<String, dynamic>) {
        return parsed;
      } else if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
      return actionMap;
    } catch (e) {
      debugPrint('[RemoteSync] Failed to decrypt zero-knowledge sync_action: $e');
      return actionMap;
    }
  }

  /// Encrypts an outgoing sync_action payload using AES-256-GCM
  static Map<String, dynamic> encryptSyncAction(
    Map<String, dynamic> plainAction,
    String pin,
    String deviceId,
  ) {
    try {
      final key = deriveKey(pin, deviceId);
      final random = SecureRandom('Fortuna')..seed(KeyParameter(Uint8List(32)));
      final iv = random.nextBytes(12);

      final jsonBytes = utf8.encode(jsonEncode(plainAction)) as Uint8List;

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
      cipher.init(true, params); // true = encrypt

      final cipherWithTag = cipher.process(jsonBytes);

      return {
        'encrypted': true,
        'action_id': plainAction['action_id'],
        'iv': _bytesToHex(iv),
        'data': _bytesToHex(cipherWithTag),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('[RemoteSync] Failed to encrypt zero-knowledge sync_action: $e');
      return plainAction;
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
