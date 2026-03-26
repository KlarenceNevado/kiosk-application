abstract class ISystemRepository {
  Future<List<Map<String, dynamic>>> fetchAnnouncements({dynamic currentUser});
  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser});
  Future<void> reactToAnnouncement(String announcementId, String emoji, String userId);
  Future<void> syncNow({dynamic authRepo, dynamic historyRepo});

  // Reminders
  Future<List<Map<String, dynamic>>> getReminders(String userId);
  Future<int> insertReminder(Map<String, dynamic> reminder);
  Future<int> updateReminder(Map<String, dynamic> reminder);
}
