import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  late encrypt.Key _key;
  encrypt.Encrypter? _encrypter;
  final _storage = const FlutterSecureStorage();
  static const String _keyIdentifier = 'kiosk_secure_db_key_v1';

  /// Initializes the encryption service.
  /// Must be called before any encryption/decryption.
  Future<void> init() async {
    if (_encrypter != null) return;

    try {
      String? encodedKey = await _storage.read(key: _keyIdentifier);

      if (encodedKey == null) {
        // Generate a new secure 32-byte key
        _key = encrypt.Key.fromSecureRandom(32);
        final base64Key = _key.base64;

        // Save it securely
        await _storage.write(key: _keyIdentifier, value: base64Key);
        debugPrint("🔐 Encryption initialized with NEW secure key.");
      } else {
        // Load existing key
        _key = encrypt.Key.fromBase64(encodedKey);
        debugPrint("🔐 Encryption initialized with EXISTING secure key.");
      }

      _encrypter = encrypt.Encrypter(encrypt.AES(_key));
    } catch (e) {
      debugPrint("CRITICAL: Encryption Init Failed: $e");

      // Fallback to static for emergency offline mode, but log heavily
      _key =
          encrypt.Key.fromUtf8('IslaVerdeKioskFixedKey2026!!!!!!'); // 32 chars
      _encrypter = encrypt.Encrypter(encrypt.AES(_key));
      debugPrint(
          "🔐 WARNING: Falling back to static key due to storage failure.");
    }
  }

  /// Encrypts plain text and bundles IV
  String encryptData(String plainText) {
    if (_encrypter == null) {
      throw Exception("EncryptionService not initialized. Call init() first.");
    }
    if (plainText.isEmpty) return plainText;

    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);
      // Format: iv_base64:ciphertext_base64
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint("Encryption Error: $e");
      return plainText;
    }
  }

  /// Decrypts data bundled with its IV
  String decryptData(String encryptedPayload) {
    if (_encrypter == null) {
      throw Exception("EncryptionService not initialized. Call init() first.");
    }
    if (encryptedPayload.isEmpty) return encryptedPayload;

    try {
      // Legacy check: If no colon, it might be the old static IV format, or plaintext
      if (!encryptedPayload.contains(':')) {
        // Migration: Attempt decrypt with old static IV
        try {
          final legacyIv = encrypt.IV.fromLength(16);
          return _encrypter!.decrypt64(encryptedPayload, iv: legacyIv);
        } catch (e) {
          return encryptedPayload; // Might just be plaintext or unrecoverable
        }
      }

      final parts = encryptedPayload.split(':');
      if (parts.length != 2) return encryptedPayload;

      final ivBase64 = parts[0];
      final ciphertextBase64 = parts[1];

      final iv = encrypt.IV.fromBase64(ivBase64);
      return _encrypter!.decrypt64(ciphertextBase64, iv: iv);
    } catch (e) {
      debugPrint("Decryption Error: $e");
      return encryptedPayload;
    }
  }

  /// Returns the raw key bytes as a string for HMAC operations.
  String getSecureKey() {
    return _key.base64;
  }
}
