import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../security/notification_service.dart';
import 'sync_handler.dart';
import '../../system/sync_event_bus.dart';
import '../../system/app_environment.dart';
import '../database_helper.dart';

class SystemSyncHandler extends SyncHandler {
  final bool isBackground;
  
  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _schedulesChannel;

  Stream<List<Map<String, dynamic>>> get announcementStream => dbHelper.systemDao.announcementStream;
  Stream<Map<String, dynamic>> get newAnnouncementStream => SyncEventBus.instance.newAnnouncementStream;

  Stream<List<Map<String, dynamic>>> get alertStream => dbHelper.systemDao.alertStream;
  Stream<Map<String, dynamic>> get newAlertStream => SyncEventBus.instance.newAlertStream;

  Stream<List<Map<String, dynamic>>> get scheduleStream => dbHelper.systemDao.scheduleStream;

  SystemSyncHandler(SupabaseClient supabase, {this.isBackground = false, DatabaseHelper? db}) : super(supabase, db);

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
    final lastSync = await _getLastSync('announcements');
    var query = supabase.from('announcements').select();
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync);
    }

    final cloudData = await query.order('updated_at', ascending: true);
    String? latestTimestamp;

    for (var row in cloudData) {
      final exists = await dbHelper.systemDao.getAnnouncementById(row['id']);
      await dbHelper.systemDao.insertAnnouncement({
        ...row,
        'is_synced': 1,
      });
      if (exists == null) {
        final isArchived = (row['is_archived'] == true || row['isArchived'] == true);
        if (!isArchived) {
          _handleNewAnnouncementNotification(row);
        }
      }
      latestTimestamp = row['updated_at'];
    }
    if (latestTimestamp != null) {
      await _updateLastSync('announcements', latestTimestamp);
    }
    dbHelper.systemDao.refreshAnnouncements();
    SyncEventBus.instance.triggerAnnouncementUpdate();
  }

  Future<void> pullAlerts() async {
    final lastSync = await _getLastSync('alerts');
    var query = supabase.from('alerts').select();
    if (lastSync != null) {
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

    final lastSync = await _getLastSync('schedules');
    var query = supabase.from('schedules').select().eq('patient_id', currentUserId);
    if (lastSync != null) {
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

  Future<void> pushAnnouncement({required String id, required String title, required String content, required String targetGroup, required DateTime timestamp, required bool isActive}) async {
    final data = {
      'id': id,
      'title': title,
      'content': content,
      'target_group': targetGroup,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await supabase.from('announcements').upsert(data);
  }

  Future<void> deleteAnnouncement(String id) async {
    await supabase.from('announcements').delete().eq('id', id);
  }

  Future<void> pushSchedule({required String id, required String type, required DateTime date, required String location, required String assigned, required int colorValue}) async {
     // Admin Logic
  }

  Future<void> deleteScheduleCloud(String id) async {
    await supabase.from('schedules').delete().eq('id', id);
  }

  Future<void> pushAlert({required String id, required String message, required String targetGroup, required bool isEmergency, required DateTime timestamp, required bool isActive}) async {
    final data = {
      'id': id,
      'message': message,
      'target_group': targetGroup,
      'is_emergency': isEmergency,
      'timestamp': timestamp.toIso8601String(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await supabase.from('alerts').upsert(data);
  }

  Future<void> deleteAlert(String id) async {
    await supabase.from('alerts').delete().eq('id', id);
  }

  Future<void> reactToAnnouncement(String id, String emoji, String userId) async {
    try {
      final data = await supabase.from('announcements').select('reactions').eq('id', id).single();
      Map<String, dynamic> reactions = data['reactions'] != null ? Map<String, dynamic>.from(data['reactions']) : {};
      
      List<dynamic> users = reactions[emoji] != null ? List<dynamic>.from(reactions[emoji]) : [];
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      reactions[emoji] = users;
      
      await supabase.from('announcements').update({'reactions': reactions}).eq('id', id);
    } catch (e) {
      debugPrint("❌ reactToAnnouncement Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements({dynamic currentUser}) async {
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
    _announcementsChannel = supabase.channel('public:announcements_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'announcements',
      callback: (payload) {
        SyncEventBus.instance.triggerAnnouncementUpdate();
        unawaited(pullAnnouncements());
      },
    ).subscribe();
  }

  void subscribeAlerts() {
    if (_alertsChannel != null) return;
    _alertsChannel = supabase.channel('public:alerts_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'alerts',
      callback: (payload) {
        SyncEventBus.instance.triggerAlertUpdate();
        unawaited(pullAlerts());
      },
    ).subscribe();
  }

  void subscribeSchedules([String? userId]) {
    if (_schedulesChannel != null) return;
    final currentUserId = userId ?? supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    _schedulesChannel = supabase.channel('public:schedules_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'schedules',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: currentUserId),
      callback: (payload) {
        unawaited(pullSchedules(currentUserId));
      },
    ).subscribe();
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

  Future<void> _withRetry(Future<void> Function() action, {int maxAttempts = 3}) async {
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

  void _handleNewAnnouncementNotification(Map<String, dynamic> row) {
    if (AppEnvironment().isDesktopAdmin) return;
    
    final isArchived = (row['is_archived'] == true || row['isArchived'] == true);
    if (isArchived) return;

    // QUIET MODE: Never notify if we are in the UI isolate
    if (!isBackground) return;

    final target = (row['target_group'] ?? row['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
    final title = row['title'] ?? "New Announcement";
    final body = row['content'] ?? "Tap to view details";

    if (target == 'BROADCAST_ALL') {
      NotificationService().showSystemAlertNotification(title: "🚨 URGENT: $title", body: body);
    } else {
      NotificationService().showAnnouncementNotification(title: title, body: body);
    }
  }
}
