import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kiosk_application/core/services/security/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mocking flutter_secure_storage channel
  const MethodChannel channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> storage = {};

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        final args = methodCall.arguments as Map<dynamic, dynamic>?;

        if (methodCall.method == 'read') {
          return storage[args?['key']];
        } else if (methodCall.method == 'write') {
          storage[args?['key'] as String] = args?['value'] as String;
          return null;
        } else if (methodCall.method == 'delete') {
          storage.remove(args?['key']);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          storage.clear();
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    storage.clear();
    dotenv.clean();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('EncryptionService Comprehensive Tests', () {
    test('Singleton returns same instance', () {
      final s1 = EncryptionService();
      final s2 = EncryptionService();
      expect(s1, equals(s2));
    });

    test('Loads Primary Shared Key from Mocked Env', () async {
      final service = EncryptionService();
      // Directly inject into env map for testing instead of using testLoad if it's missing
      dotenv.env
          .addAll({'DB_ENCRYPTION_KEY': 'super_secret_32_chars_long_key_!!!'});

      await service.init();

      const plainText = "Hello World";
      final encrypted = service.encryptData(plainText);
      expect(encrypted, contains(':')); // Primary uses IV prefix

      final decrypted = service.decryptData(encrypted);
      expect(decrypted, plainText);
    });

    test('Falls back to Legacy Key from SecureStorage if .env is missing',
        () async {
      final service = EncryptionService();
      // Ensure env is empty
      dotenv.env.clear();
      // Pre-populate legacy key in Mock storage
      storage['kiosk_secure_db_key_v1'] =
          'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA='; // Random 32-byte base64

      await service.init();

      const plainText = "Legacy Data";
      final encrypted = service.encryptData(plainText);
      final decrypted = service.decryptData(encrypted);
      expect(decrypted, plainText);
    });

    test('Encrypting empty string returns empty string', () async {
      final service = EncryptionService();
      await service.init();
      final encrypted = service.encryptData("");
      expect(encrypted, isEmpty);
      expect(encrypted, "");

      final decrypted = service.decryptData(encrypted);
      expect(decrypted, "");
    });

    test('Decrypting invalid base64 returns original text (fallback)',
        () async {
      final service = EncryptionService();
      await service.init();
      const invalidData = "InvalidBase64String!!";
      final result = service.decryptData(invalidData);
      expect(result, invalidData);
    });
  });
}
