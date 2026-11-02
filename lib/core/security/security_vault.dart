import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';

class SecurityVault {
  static const String _prefVaultKey = 'goat_security_vault_key_v1';
  static const String _encPrefix = 'enc:v1:';

  static enc.Key? _cachedKey;

  /// Initializes or retrieves the device-specific 256-bit AES master key
  static Future<enc.Key> getMasterKey([SharedPreferences? prefs]) async {
    if (_cachedKey != null) return _cachedKey!;

    final sp = prefs ?? await SharedPreferences.getInstance();
    var rawB64 = sp.getString(_prefVaultKey);

    if (rawB64 == null || rawB64.isEmpty) {
      final random = Random.secure();
      final keyBytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        keyBytes[i] = random.nextInt(256);
      }
      rawB64 = base64Encode(keyBytes);
      await sp.setString(_prefVaultKey, rawB64);
    }

    _cachedKey = enc.Key.fromBase64(rawB64);
    return _cachedKey!;
  }

  /// Deterministic fallback key if prefs not ready yet
  static enc.Key getFallbackKey() {
    if (_cachedKey != null) return _cachedKey!;
    return enc.Key.fromUtf8('GOATPlayer_SecVault_Key_2026_X!');
  }

  /// Encrypts plaintext string using AES-256-CBC with a random IV
  static String encrypt(String plainText, [enc.Key? customKey]) {
    if (plainText.isEmpty || plainText.startsWith(_encPrefix)) {
      return plainText;
    }
    try {
      final key = customKey ?? _cachedKey ?? getFallbackKey();
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return '$_encPrefix${iv.base64}:${encrypted.base64}';
    } catch (e) {
      // In case of unexpected error, return original plainText to guarantee zero breakage
      return plainText;
    }
  }

  /// Decrypts ciphertext string. If not starting with enc:v1:, returns original string seamlessly.
  static String decrypt(String cipherText, [enc.Key? customKey]) {
    if (!cipherText.startsWith(_encPrefix)) {
      return cipherText; // Legacy plaintext account - zero breakage
    }
    try {
      final payload = cipherText.substring(_encPrefix.length);
      final parts = payload.split(':');
      if (parts.length != 2) return cipherText;

      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);
      final key = customKey ?? _cachedKey ?? getFallbackKey();
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      // Graceful fallback to avoid app crash
      return cipherText;
    }
  }

  /// Clears cache (useful for testing)
  static void resetCacheForTesting([enc.Key? key]) {
    _cachedKey = key;
  }
}
