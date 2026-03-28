import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kiosk_application/core/services/database/sync_service.dart';
import 'package:kiosk_application/core/services/database/sync/patient_sync_handler.dart';
import 'package:kiosk_application/core/services/database/sync/vitals_sync_handler.dart';
import 'package:kiosk_application/core/services/database/sync/system_sync_handler.dart';
import 'package:kiosk_application/core/services/database/sync/chat_sync_handler.dart';

class MockPatientHandler extends Mock implements PatientSyncHandler {}
class MockVitalsHandler extends Mock implements VitalsSyncHandler {}
class MockSystemHandler extends Mock implements SystemSyncHandler {}
class MockChatHandler extends Mock implements ChatSyncHandler {}

class MockAuthRepo extends Mock {}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncService syncService;
  late MockPatientHandler mockPatient;
  late MockVitalsHandler mockVitals;
  late MockSystemHandler mockSystem;
  late MockChatHandler mockChat;

  setUp(() {
    // Use the newly created factory for testing
    mockPatient = MockPatientHandler();
    mockVitals = MockVitalsHandler();
    mockSystem = MockSystemHandler();
    mockChat = MockChatHandler();

    // Use the newly created factory for testing
    syncService = SyncService.createMocked(
      p: mockPatient,
      v: mockVitals,
      s: mockSystem,
      c: mockChat,
    );
    
    // Inject into singleton for tests that might use SyncService()
    SyncService.setMockInstance(syncService);
  });

  group('SyncService Orchestration Tests', () {
    test('triggerSync() calls push and pull on all handlers', () async {
      // Setup successful completions
      when(() => mockPatient.push()).thenAnswer((_) async {});
      when(() => mockPatient.pull()).thenAnswer((_) async {});
      when(() => mockVitals.push()).thenAnswer((_) async {});
      when(() => mockVitals.pull()).thenAnswer((_) async {});
      when(() => mockSystem.pull()).thenAnswer((_) async {});
      when(() => mockChat.push()).thenAnswer((_) async {});

      // Execute
      await syncService.triggerSync();

      // Verify orchestration
      verify(() => mockPatient.push()).called(1);
      verify(() => mockVitals.push()).called(1);
      verify(() => mockChat.push()).called(1);
      
      verify(() => mockPatient.pull()).called(1);
      verify(() => mockVitals.pull()).called(1);
      verify(() => mockSystem.pull()).called(1);
    });

    test('fullSyncForUser() coordinates pulls', () async {
      when(() => mockPatient.pull()).thenAnswer((_) async {});
      when(() => mockSystem.pull()).thenAnswer((_) async {});
      when(() => mockVitals.pull()).thenAnswer((_) async {});

      await syncService.fullSyncForUser('user-123');

      verify(() => mockPatient.pull()).called(1);
      verify(() => mockSystem.pull()).called(1);
      verify(() => mockVitals.pull()).called(1);
    });
  });
}
