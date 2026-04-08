import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kiosk_application/core/services/database/database_helper.dart';
import 'package:kiosk_application/features/auth/models/user_model.dart';

void main() {
  // Setup sqflite_ffi for local tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    // We use a specific test database name to avoid clobbering real data if any
    // In a real CI/CD, we'd use in-memory: 'in_memory_db'
  });

  group('DatabaseHelper Unit Tests', () {
    test('Database initialization and basic connectivity', () async {
      final db = await dbHelper.database;
      expect(db.isOpen, isTrue);

      final result = await db.rawQuery('PRAGMA user_version');
      expect(result.first['user_version'], greaterThanOrEqualTo(10));
    });

    test('Patient CRUD Operations', () async {
      final testUser = User(
        id: 'test-uuid-1',
        firstName: 'Test',
        middleInitial: 'M',
        lastName: 'Patient',
        phoneNumber: '09001112222',
        pinCode: '123456',
        gender: 'Female',
        sitio: 'Test Sitio',
        dateOfBirth: DateTime(2000, 1, 1),
      );

      // Insert
      await dbHelper.insertPatient(testUser);

      // Fetch
      final retrieved = await dbHelper.getPatientById('test-uuid-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.firstName, 'Test');
      expect(retrieved.phoneNumber,
          '09001112222'); // Should be decrypted automatically

      // Update
      final updatedUser = testUser.copyWith(firstName: 'Updated');
      await dbHelper.updatePatient(updatedUser);
      final retrieved2 = await dbHelper.getPatientById('test-uuid-1');
      expect(retrieved2!.firstName, 'Updated');

      // Delete (Soft)
      await dbHelper.deletePatient('test-uuid-1');
      final retrieved3 = await dbHelper.getPatientById('test-uuid-1');
      expect(retrieved3, isNotNull); // It's a soft delete, so it exists
      expect(retrieved3!.isDeleted, isTrue);
    });

    test('Integrity check returns true for healthy DB', () async {
      final isHealthy = await dbHelper.checkDatabaseIntegrity();
      expect(isHealthy, isTrue);
    });
  });
}
