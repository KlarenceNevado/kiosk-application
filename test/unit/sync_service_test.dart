import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kiosk_application/core/services/database/sync_service.dart';
import 'package:kiosk_application/core/services/database/sync/resident_sync_handler.dart';
import 'package:kiosk_application/core/services/database/sync/vitals_sync_handler.dart';
import 'package:kiosk_application/core/services/database/sync/system_sync_handler.dart';
import 'package:kiosk_application/core/services/database/sync/chat_sync_handler.dart';

class MockResidentHandler extends Mock implements ResidentSyncHandler {}

class MockVitalsHandler extends Mock implements VitalsSyncHandler {}

class MockSystemHandler extends Mock implements SystemSyncHandler {}

class MockChatHandler extends Mock implements ChatSyncHandler {}

class MockAuthRepo extends Mock {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncService syncService;
  late MockResidentHandler mockResident;
  late MockVitalsHandler mockVitals;
  late MockSystemHandler mockSystem;
  late MockChatHandler mockChat;

  setUp(() {
    // Use the newly created factory for testing
    mockResident = MockResidentHandler();
    mockVitals = MockVitalsHandler();
    mockSystem = MockSystemHandler();
    mockChat = MockChatHandler();

    // Use the newly created factory for testing
    syncService = SyncService.createMocked(
      p: mockResident,
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
      when(() => mockResident.push()).thenAnswer((_) async {});
      when(() => mockResident.pull()).thenAnswer((_) async {});
      when(() => mockVitals.push()).thenAnswer((_) async {});
      when(() => mockVitals.pull()).thenAnswer((_) async {});
      when(() => mockSystem.pull()).thenAnswer((_) async {});
      when(() => mockChat.push()).thenAnswer((_) async {});

      // Execute
      await syncService.triggerSync();

      // Verify orchestration
      verify(() => mockResident.push()).called(1);
      verify(() => mockVitals.push()).called(1);
      verify(() => mockChat.push()).called(1);

      verify(() => mockResident.pull()).called(1);
      verify(() => mockVitals.pull()).called(1);
      verify(() => mockSystem.pull()).called(1);
    });

    test('fullSyncForUser() coordinates pulls', () async {
      when(() => mockResident.pull()).thenAnswer((_) async {});
      when(() => mockSystem.pull()).thenAnswer((_) async {});
      when(() => mockVitals.pull()).thenAnswer((_) async {});

      await syncService.fullSyncForUser('user-123');

      verify(() => mockResident.pull()).called(1);
      verify(() => mockSystem.pull()).called(1);
      verify(() => mockVitals.pull()).called(1);
    });
  });
}
