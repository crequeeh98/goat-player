import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  test('Dart PBKDF2 matches Node/WebCrypto test vector', () {
    const pin = '839201';
    const salt = 'GOATPlayer_Pairing_Salt_GP-1234-ABCD';
    const iterations = 10000;

    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = Pbkdf2Parameters(
      utf8.encode(salt) as Uint8List,
      iterations,
      32,
    );
    derivator.init(params);
    final keyBytes = derivator.process(utf8.encode(pin) as Uint8List);

    final hexStr = _bytesToHex(keyBytes);
    expect(hexStr, equals('e4c25802dfd662199dc78ea6e8763c99e237783398060d9e881022190d224005'));
  });

  test('Dart GCMBlockCipher decrypts WebCrypto AES-GCM ciphertext', () {
    final key = _hexToBytes('e4c25802dfd662199dc78ea6e8763c99e237783398060d9e881022190d224005');
    final iv = _hexToBytes('0102030405060708090a0b0c');
    final cipherWithTag = _hexToBytes('64c42309626001e80cbec363b2ab3e26d4b180f6de8d3a62003fc2ee2a454a4844feaf79');

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
    cipher.init(false, params); // false = decrypt

    final decrypted = cipher.process(cipherWithTag);
    final plainText = utf8.decode(decrypted);

    expect(plainText, equals('Hello Zero Knowledge'));
  });
}
