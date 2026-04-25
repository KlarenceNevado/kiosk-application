import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:kiosk_application/core/services/database/sync/resident_sync_handler.dart';
import 'package:kiosk_application/features/auth/models/user_model.dart';
import '../mocks/test_mocks.dart';

void main() {
  late ResidentSyncHandler handler;
  late MockSupabaseClient mockSupabase;
  late MockDatabaseHelper mockDb;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockDb = MockDatabaseHelper();
    handler = ResidentSyncHandler(mockSupabase, mockDb);
  });

  group('ResidentSyncHandler Unit Tests', () {
    final testUser = User(
      id: 'uuid-1234',
      firstName: 'John',
      middleInitial: 'M',
      lastName: 'Doe',
      phoneNumber: '09123456789',
      pinCode: '123456',
      gender: 'Male',
      sitio: 'Purok 1',
      dateOfBirth: DateTime(1990, 1, 1),
      username: 'h260001',
    );

    test('push() ignores records with blocked IDs', () async {
      // Setup
      when(() => mockDb.getBlockedRecords('patients'))
          .thenAnswer((_) async => ['uuid-1234']);
      when(() => mockDb.getUnsyncedPatients())
          .thenAnswer((_) async => [testUser]);

      // Execute
      await handler.push();

      // Verify: upsert should NOT be called because ID is blocked
      verifyNever(() => mockSupabase.from('patients'));
    });

    test('push() successfully upserts unsynced resident', () async {
      // Setup
      when(() => mockDb.getBlockedRecords('patients'))
          .thenAnswer((_) async => []);
      when(() => mockDb.getUnsyncedPatients())
          .thenAnswer((_) async => [testUser]);

      // Mocking Encrypt (BaseDao/DatabaseHelper helper)
      when(() => mockDb.encrypt(any())).thenReturn('encrypted_data');

      // Mock Supabase chain: supabase.from('patients').upsert(...)
      final mockPostgrest = _MockSupabaseQueryBuilder();
      final mockFilter = _MockPostgrestFilterBuilder();
      when(() => mockSupabase.from('patients')).thenReturn(mockPostgrest);
      when(() => mockPostgrest.upsert(any())).thenReturn(mockFilter);
      when(() => mockFilter.then(any())).thenAnswer((invocation) {
        final callback = invocation.positionalArguments[0] as Function;
        return callback(null);
      });

      // Mock DB mark as synced
      when(() => mockDb.insertPatient(any())).thenAnswer((_) async => 1);
      when(() => mockDb.clearSyncMetadata('patients', any()))
          .thenAnswer((_) async {});
      when(() => mockDb.markBatchAsSynced('patients', any()))
          .thenAnswer((_) async {});

      // Execute
      await handler.push();

      // Verify
      verify(() => mockPostgrest.upsert(any())).called(1);
      verify(() => mockDb.markBatchAsSynced('patients', ['uuid-1234']))
          .called(1);
    });

    test('createResident() handles legacy local_ IDs by skipping cloud push',
        () async {
      final legacyUser = testUser.copyWith(id: 'local_123');

      when(() => mockDb.insertPatient(any())).thenAnswer((_) async => 1);

      final result = await handler.createResident(legacyUser);

      expect(result?.isSynced, isTrue);
      verifyNever(() => mockSupabase.from('patients'));
    });
  });
}

// Helper mock for Supabase fluent API
class _MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class _MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}
