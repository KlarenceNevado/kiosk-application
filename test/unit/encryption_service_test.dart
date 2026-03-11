import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
        final args = methodCall.arguments as Map<dynamic, dynamic>;

        if (methodCall.method == 'read') {
          return storage[args['key']];
        } else if (methodCall.method == 'write') {
          storage[args['key'] as String] = args['value'] as String;
          return null;
        } else if (methodCall.method == 'delete') {
          storage.remove(args['key']);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('EncryptionService Tests', () {
    test('Singleton returns same instance', () {
      final s1 = EncryptionService();
      final s2 = EncryptionService();
      expect(s1, equals(s2));
    });

    test('Init generates key and encrypt/decrypt works', () async {
      final service = EncryptionService();
      await service.init();

      const plainText = "Sensitive Patient Data 123";

      final encrypted = service.encryptData(plainText);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(plainText));

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
