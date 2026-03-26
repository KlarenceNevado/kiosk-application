import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  /// Primary encrypter (Shared key from .env)
  encrypt.Encrypter? _primaryEncrypter;
  
  /// Legacy encrypter (Device-specific key from SecureStorage)
  encrypt.Encrypter? _legacyEncrypter;
  
  encrypt.Key? _primaryKey;
  
  final _storage = const FlutterSecureStorage();
  static const String _keyIdentifier = 'kiosk_secure_db_key_v1';

  /// Initializes the encryption service.
  /// Loads both the shared environment key and the legacy device key.
  Future<void> init() async {
    if (_primaryEncrypter != null) return;

    try {
      // 1. Load Primary Shared Key (from .env)
      final envKey = dotenv.env['DB_ENCRYPTION_KEY'];
      if (envKey != null && envKey.isNotEmpty && envKey.length >= 32) {
        _primaryKey = encrypt.Key.fromUtf8(envKey.substring(0, 32));
        _primaryEncrypter = encrypt.Encrypter(encrypt.AES(_primaryKey!));
        debugPrint("🔐 Encryption: Primary Shared Key loaded.");
      }

      // 2. Load Legacy Device Key (from SecureStorage)
      String? encodedLegacyKey = await _storage.read(key: _keyIdentifier);
      if (encodedLegacyKey != null) {
        final legacyKey = encrypt.Key.fromBase64(encodedLegacyKey);
        _legacyEncrypter = encrypt.Encrypter(encrypt.AES(legacyKey));
        debugPrint("🔐 Encryption: Legacy Device Key loaded for migration.");
      }

      // 3. Fallback/Initial Setup Logic
      if (_primaryEncrypter == null) {
        if (encodedLegacyKey == null) {
          // No Shared Key and No Legacy Key -> Generate a new local key
          final newKey = encrypt.Key.fromSecureRandom(32);
          await _storage.write(key: _keyIdentifier, value: newKey.base64);
          _primaryKey = newKey;
          _primaryEncrypter = encrypt.Encrypter(encrypt.AES(_primaryKey!));
          debugPrint("🔐 Encryption: No keys found. Generated new local key.");
        } else {
          // No Shared Key but Legacy Key exists -> Use Legacy as Primary
          _primaryKey = encrypt.Key.fromBase64(encodedLegacyKey);
          _primaryEncrypter = _legacyEncrypter;
          debugPrint("🔐 Encryption: Using existing local key as primary.");
        }
      }
    } catch (e) {
      debugPrint("CRITICAL: Encryption Init Failed: $e");
      // Safety fallback
      final safetyKey = encrypt.Key.fromUtf8('IslaVerdeKioskFixedKey2026!!!!!!'); 
      _primaryKey = safetyKey;
      _primaryEncrypter = encrypt.Encrypter(encrypt.AES(safetyKey));
    }
  }

  /// Encrypts data using the PRIMARY key.
  String encryptData(String plainText) {
    if (_primaryEncrypter == null) {
      throw Exception("EncryptionService not initialized. Call init() first.");
    }
    if (plainText.isEmpty) return plainText;

    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = _primaryEncrypter!.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint("Encryption Error: $e");
      return plainText;
    }
  }

  /// Decrypts data using the Primary key, falling back to Legacy key if needed.
  String decryptData(String encryptedPayload) {
    if (_primaryEncrypter == null) {
      throw Exception("EncryptionService not initialized. Call init() first.");
    }
    if (encryptedPayload.isEmpty) return encryptedPayload;

    try {
      // Basic IV check
      if (!encryptedPayload.contains(':')) {
        return _tryLegacyDecryptRaw(encryptedPayload);
      }

      final parts = encryptedPayload.split(':');
      if (parts.length != 2) return encryptedPayload;

      final iv = encrypt.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];

      // 1. Try Primary Decryption
      try {
        return _primaryEncrypter!.decrypt64(ciphertext, iv: iv);
      } catch (e) {
        // 2. Try Legacy Decryption if primary fails
        if (_legacyEncrypter != null) {
          try {
            return _legacyEncrypter!.decrypt64(ciphertext, iv: iv);
          } catch (_) {
            return encryptedPayload; // Silent failure: both encrypters failed
          }
        }
        return encryptedPayload; // Silent failure: primary failed and no legacy
      }
    } catch (e) {
      // Final safety net - ensures no crash or log spam
      return encryptedPayload;
    }
  }

  /// Handles legacy data with static IV or missing markers
  String _tryLegacyDecryptRaw(String payload) {
    final legacyIv = encrypt.IV.fromLength(16);
    try {
      return _primaryEncrypter!.decrypt64(payload, iv: legacyIv);
    } catch (e) {
      if (_legacyEncrypter != null) {
        try {
          return _legacyEncrypter!.decrypt64(payload, iv: legacyIv);
        } catch (_) {}
      }
      return payload;
    }
  }

  /// Returns the raw primary key bytes as a string.
  String getSecureKey() {
    return _primaryKey?.base64 ?? "";
  }
}
