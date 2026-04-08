import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../security/notification_service.dart';
import 'sync_handler.dart';
import '../../system/sync_event_bus.dart';
import '../database_helper.dart';

class SystemSyncHandler extends SyncHandler {
  final bool isBackground;

  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _schedulesChannel;

  Stream<List<Map<String, dynamic>>> get announcementStream =>
      dbHelper.systemDao.announcementStream;
  Stream<Map<String, dynamic>> get newAnnouncementStream =>
      SyncEventBus.instance.newAnnouncementStream;

  Stream<List<Map<String, dynamic>>> get alertStream =>
      dbHelper.systemDao.alertStream;
  Stream<Map<String, dynamic>> get newAlertStream =>
      SyncEventBus.instance.newAlertStream;

  Stream<List<Map<String, dynamic>>> get scheduleStream =>
      dbHelper.systemDao.scheduleStream;

  SystemSyncHandler(SupabaseClient supabase,
      {this.isBackground = false, DatabaseHelper? db})
      : super(supabase, db);

  @override
  Future<void> push() async {
    // Standard system push (only for Admin apps)
    // Most system tables are read-only for patients.
  }

  @override
  Future<void> pull() async {
    await _withRetry(() async {
      await pullAnnouncements();
      await pullAlerts();
      await pullSchedules();
    });
  }

  Future<void> pullAnnouncements() async {
    // REASON FOR CHANGE: Full Parity Sync ensures 100% parity by fetching the full active set.
    // Announcements are low-volume data, and differential sync (updated_at) was causing staleness.
    final cloudData = await supabase
        .from('announcements')
        .select()
        .filter('is_deleted', 'eq', false)
        .order('updated_at', ascending: true);

    final List<String> cloudIds = [];

    for (var row in cloudData) {
      final id = row['id'];
      cloudIds.add(id);

      // OS-LEVEL NOTIFICATION LOGIC:
      // If the announcement is new or was previously hidden but is now active:
      final existing = await dbHelper.systemDao.getAnnouncementById(id);
      final wasActive = existing != null &&
          (existing['is_active'] == 1 || existing['is_active'] == true);
      final isNowActive = (row['is_active'] == 1 || row['is_active'] == true);
      final isArchived =
          (row['is_archived'] == 1 || row['is_archived'] == true);

      if (isNowActive && !isArchived) {
        if (existing == null || !wasActive) {
          final target = (row['target_group'] ?? row['targetGroup'])
                  ?.toString()
                  .toUpperCase() ??
              'ALL';
          final title = row['title'] ?? "New Announcement";
          final body = row['content'] ?? "Tap to view details";

          if (target == 'BROADCAST_ALL') {
            NotificationService().showSystemAlertNotification(
                title: "🚨 URGENT: $title", body: body);
          } else {
            NotificationService()
                .showAnnouncementNotification(title: title, body: body);
          }
        }
      }

      await dbHelper.systemDao.insertAnnouncement({
        ...row,
        'is_synced': 1,
      });
    }

    // PURGE LOGIC: Any local announcement NOT in the current cloud pull
    // must be removed locally to ensure parity with the Cloud.
    final localAnnouncements = await dbHelper.systemDao.getAnnouncements();
    for (var ann in localAnnouncements) {
      final id = ann['id'];
      if (!cloudIds.contains(id)) {
        debugPrint("🗑️ [FullParity] Purging stale local announcement: $id");
        await dbHelper.systemDao.deleteAnnouncementPermanently(id);
      }
    }

    await _updateLastSync(
        'announcements', DateTime.now().toUtc().toIso8601String());
    dbHelper.systemDao.refreshAnnouncements();
    SyncEventBus.instance.triggerAnnouncementUpdate();
  }

  Future<void> pullAlerts() async {
    final db = await dbHelper.database;
    int localCount = 0;
    try {
      final countResult = await db.rawQuery('SELECT COUNT(*) FROM alerts');
      localCount = Sqflite.firstIntValue(countResult) ?? 0;
    } catch (_) {}

    final lastSync = await _getLastSync('alerts');
    var query = supabase.from('alerts').select();
    if (lastSync != null && localCount > 0) {
      query = query.gt('updated_at', lastSync);
    }

    final cloudData = await query.order('updated_at', ascending: true);
    String? latestTimestamp;

    for (var row in cloudData) {
      final exists = await dbHelper.systemDao.getAlertById(row['id']);
      if (exists == null) {
        NotificationService().showInstantNotification(
          id: row['id'].hashCode,
          title: "🚨 URGENT ALERT",
          body: row['message'] ?? "New alert received.",
        );
      }
      await dbHelper.systemDao.insertAlert({
        ...row,
        'is_synced': 1,
      });
      latestTimestamp = row['updated_at'];
    }
    if (latestTimestamp != null) {
      await _updateLastSync('alerts', latestTimestamp);
    }
    dbHelper.systemDao.refreshAlerts();
    SyncEventBus.instance.triggerAlertUpdate();
  }

  Future<void> pullSchedules([String? userId]) async {
    final currentUserId = userId ?? supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final db = await dbHelper.database;
    int localCount = 0;
    try {
      final countResult = await db.rawQuery('SELECT COUNT(*) FROM schedules');
      localCount = Sqflite.firstIntValue(countResult) ?? 0;
    } catch (_) {}

    final lastSync = await _getLastSync('schedules');
    var query = supabase
        .from('schedules')
        .select(); // Removed patient_id filter as it doesn't exist in Supabase/Local schema
    if (lastSync != null && localCount > 0) {
      query = query.gt('updated_at', lastSync);
    }

    final cloudData = await query.order('updated_at', ascending: true);
    String? latestTimestamp;

    for (var row in cloudData) {
      await dbHelper.systemDao.insertSchedule({
        ...row,
        'is_synced': 1,
      });
      latestTimestamp = row['updated_at'];
    }
    if (latestTimestamp != null) {
      await _updateLastSync('schedules', latestTimestamp);
    }
    dbHelper.systemDao.refreshSchedules();
  }

  // --- PUBLIC CRUDS (For Admin & Interactive Reactions) ---

  Future<void> pushAnnouncement(
      {required String id,
      required String title,
      required String content,
      required String targetGroup,
      required DateTime timestamp,
      required bool isActive,
      bool isArchived = false}) async {
    final data = {
      'id': id,
      'title': title,
      'content': content,
      'target_group': targetGroup,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive,
      'is_archived': isArchived,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await supabase.from('announcements').upsert(data);
  }

  Future<void> deleteAnnouncement(String id) async {
    // SECURITY & SYNC: Use Soft Delete so other devices fetch the removal via pullAnnouncements.
    await supabase.from('announcements').update({
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', id);
  }

  Future<void> pushSchedule(
      {required String id,
      required String type,
      required DateTime date,
      required String location,
      required String assigned,
      required int colorValue}) async {
    // Admin Logic
  }

  Future<void> deleteScheduleCloud(String id) async {
    // SECURITY & SYNC: Use Soft Delete so other devices fetch the removal via pullSchedules.
    await supabase.from('schedules').update({
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', id);
  }

  Future<void> pushAlert({
    required String id,
    required String message,
    required String targetGroup,
    required bool isEmergency,
    required DateTime timestamp,
    required bool isActive,
    String? targetUserId,
  }) async {
    final data = {
      'id': id,
      'message': message,
      'target_group': targetGroup,
      'is_emergency': isEmergency,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive,
      'target_user_id': targetUserId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await supabase.from('alerts').upsert(data);
  }

  Future<void> deleteAlert(String id) async {
    // SECURITY & SYNC: Use Soft Delete so other devices fetch the removal via pullAlerts.
    await supabase.from('alerts').update({
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', id);
  }

  Future<void> reactToAnnouncement(
      String id, String emoji, String userId) async {
    try {
      final data = await supabase
          .from('announcements')
          .select('reactions')
          .eq('id', id)
          .single();
      Map<String, dynamic> reactions = data['reactions'] != null
          ? Map<String, dynamic>.from(data['reactions'])
          : {};

      List<dynamic> users =
          reactions[emoji] != null ? List<dynamic>.from(reactions[emoji]) : [];
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      reactions[emoji] = users;

      await supabase
          .from('announcements')
          .update({'reactions': reactions}).eq('id', id);
    } catch (e) {
      debugPrint("❌ reactToAnnouncement Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements(
      {dynamic currentUser}) async {
    return await dbHelper.systemDao.getAnnouncements();
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    return await dbHelper.systemDao.getAlerts();
  }

  // --- SUBSCRIPTIONS ---

  void subscribeAll() {
    subscribeAnnouncements();
    subscribeAlerts();
    subscribeSchedules();
  }

  void subscribeAnnouncements() {
    if (_announcementsChannel != null) return;
    _announcementsChannel = supabase
        .channel('public:announcements_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id']?.toString();
              if (id != null) {
                unawaited(dbHelper.systemDao.hardDeleteAnnouncement(id));
              }
            } else {
              unawaited(pullAnnouncements());
            }
            SyncEventBus.instance.triggerAnnouncementUpdate();
          },
        )
        .subscribe();
  }

  void subscribeAlerts() {
    if (_alertsChannel != null) return;
    _alertsChannel = supabase
        .channel('public:alerts_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id']?.toString();
              if (id != null) {
                unawaited(dbHelper.systemDao.hardDeleteAlert(id));
              }
            } else {
              unawaited(pullAlerts());
            }
            SyncEventBus.instance.triggerAlertUpdate();
          },
        )
        .subscribe();
  }

  void subscribeSchedules([String? userId]) {
    if (_schedulesChannel != null) return;
    final currentUserId = userId ?? supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    _schedulesChannel = supabase
        .channel('public:schedules_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, schema: 'public', table: 'schedules',
          // filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: currentUserId), // Removed as patient_id column is missing
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id']?.toString();
              if (id != null) {
                unawaited(dbHelper.systemDao.hardDeleteSchedule(id));
              }
            } else {
              try {
                unawaited(pullSchedules(currentUserId));
              } catch (e) {
                debugPrint("❌ pullSchedules Error: $e");
              }
            }
          },
        )
        .subscribe();
  }

  void unsubscribeAll() {
    _announcementsChannel?.unsubscribe();
    _alertsChannel?.unsubscribe();
    _schedulesChannel?.unsubscribe();
    _announcementsChannel = null;
    _alertsChannel = null;
    _schedulesChannel = null;
  }

  // --- HELPERS ---

  Future<String?> _getLastSync(String table) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_$table');
  }

  Future<void> _updateLastSync(String table, String? timestamp) async {
    if (timestamp == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$table', timestamp);
  }

  Future<void> _withRetry(Future<void> Function() action,
      {int maxAttempts = 3}) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        await action();
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
  }
}
