import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:kiosk_application/core/services/database/database_helper.dart';
import 'package:kiosk_application/core/services/database/sync_service.dart';
import 'package:kiosk_application/core/services/security/notification_service.dart';
import 'package:kiosk_application/core/services/security/encryption_service.dart';
import 'package:kiosk_application/core/services/system/initialization_service.dart';
import 'package:kiosk_application/core/services/security/admin_security_service.dart';
import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/auth/models/user_model.dart';
import 'package:kiosk_application/features/user_history/domain/i_history_repository.dart';

// REUSABLE MOCKS
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockSyncService extends Mock implements SyncService {}
class MockNotificationService extends Mock implements NotificationService {}
class MockEncryptionService extends Mock implements EncryptionService {}
class MockInitializationService extends Mock implements InitializationService {}
class MockAdminSecurityService extends Mock implements AdminSecurityService {}
class MockAuthRepository extends Mock implements IAuthRepository {}
class MockHistoryRepository extends Mock implements IHistoryRepository {}

void main() {
  // Register fallback values if needed for mocktail
  registerFallbackValue(User(
    id: 'fallback',
    firstName: '',
    middleInitial: '',
    lastName: '',
    sitio: '',
    phoneNumber: '',
    pinCode: '',
    gender: '',
    dateOfBirth: DateTime(1900, 1, 1),
  ));
}

// CUSTOM MOCK RESPONSES HELPERS
mixin MockResponseHelper {
  void mockSuccess(Mock mock, String method, dynamic data) {
    // pattern for mock responses
  }
}
