import '../domain/i_system_repository.dart';
import '../services/database/sync_service.dart';
import '../services/database/database_helper.dart';
import '../../features/auth/domain/i_auth_repository.dart';
import '../../features/user_history/domain/i_history_repository.dart';

class LocalSystemRepository implements ISystemRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchAnnouncements({dynamic currentUser}) async {
    return await SyncService().fetchAnnouncements(currentUser: currentUser);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    return await SyncService().fetchAlerts(currentUser: currentUser);
  }

  @override
  Future<void> reactToAnnouncement(String announcementId, String emoji, String userId) async {
    await SyncService().reactToAnnouncement(announcementId, emoji, userId);
  }

  @override
  Future<void> syncNow({dynamic authRepo, dynamic historyRepo}) async {
    if (authRepo is IAuthRepository && historyRepo is IHistoryRepository) {
      await SyncService().forceDownSyncAndRefresh(authRepo, historyRepo, triggerStream: true);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders(String userId) async {
    return await DatabaseHelper.instance.getReminders(userId);
  }

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    return await DatabaseHelper.instance.insertReminder(reminder);
  }

  @override
  Future<int> updateReminder(Map<String, dynamic> reminder) async {
    return await DatabaseHelper.instance.updateReminder(reminder);
  }
}
