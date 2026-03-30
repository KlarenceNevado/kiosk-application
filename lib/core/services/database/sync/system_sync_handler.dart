import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../security/notification_service.dart';
import 'sync_handler.dart';
import '../../system/sync_event_bus.dart';
import '../../system/app_environment.dart';

class SystemSyncHandler extends SyncHandler {
  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _schedulesChannel;

  Stream<void> get announcementStream => SyncEventBus.instance.announcementStream;
  Stream<Map<String, dynamic>> get newAnnouncementStream => SyncEventBus.instance.newAnnouncementStream;

  // Notice that alertStream was originally a Stream<Map<String,dynamic>>, let's map it via SyncEventBus
  Stream<void> get alertStream => SyncEventBus.instance.alertStream;
  Stream<Map<String, dynamic>> get newAlertStream => SyncEventBus.instance.newAlertStream;

  final _scheduleChangeController = StreamController<void>.broadcast();
  Stream<void> get scheduleStream => _scheduleChangeController.stream;

  SystemSyncHandler(super.supabase, [super.db]);

  @override
  Future<void> push() async {
    await Future.wait([
      pushAnnouncements(),
      pushAlerts(),
      pushSchedules(),
    ]);
  }

  @override
  Future<void> pull() async {
    await Future.wait([
      pullAnnouncements(),
      pullAlerts(),
      pullSchedules(),
    ]);
  }

  // --- ANNOUNCEMENTS ---

  Future<void> pushAnnouncements() async {
    try {
      final unsynced = await dbHelper.systemDao.getUnsyncedAnnouncements();
      final List<String> syncedIds = [];
      for (final row in unsynced) {
        await supabase.from('announcements').upsert({
          'id': row['id'],
          'title': row['title'],
          'content': row['content'],
          'target_group': row['target_group'],
          'timestamp': row['timestamp'],
          'is_active': row['is_active'] == 1,
          'is_deleted': row['is_deleted'] == 1,
          'updated_at': row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        });
        syncedIds.add(row['id']);
        await dbHelper.systemDao.clearSyncMetadata('announcements', row['id']);
      }
      if (syncedIds.isNotEmpty) {
        await dbHelper.markBatchAsSynced('announcements', syncedIds);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Announcements Push Error: $e");
    }
  }

  Future<void> pullAnnouncements() async {
    await _withRetry(() async {
      // 1. PARITY PURGE: Remove records that no longer exist in the cloud
      final cloudIdsData = await supabase.from('announcements').select('id');
      final cloudIds = cloudIdsData.map((row) => row['id'].toString()).toSet();
      
      final localAnnouncements = await dbHelper.systemDao.getAnnouncements();
      for (final local in localAnnouncements) {
        final id = local['id'].toString();
        if (!cloudIds.contains(id)) {
          await dbHelper.systemDao.hardDeleteAnnouncement(id);
          debugPrint("🧹 Parity Purge: Removed ghost announcement $id");
        }
      }

      // 2. INCREMENTAL PULL: Fetch new/updated records
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
          _handleNewAnnouncementNotification(row);
        }
        latestTimestamp = row['updated_at'];
      }
      if (latestTimestamp != null) {
        await _updateLastSync('announcements', latestTimestamp);
      }
      
      // Always trigger update to ensure parity changes are reflected
      SyncEventBus.instance.triggerAnnouncementUpdate();
    });
  }

  // --- ALERTS ---

  Future<void> pushAlerts() async {
    try {
      final unsynced = await dbHelper.systemDao.getUnsyncedAlerts();
      if (unsynced.isEmpty) return;
      
      final List<String> syncedIds = [];
      for (final row in unsynced) {
        try {
          await supabase.from('alerts').upsert({
            'id': row['id'],
            'message': row['message'],
            'target_group': row['target_group'],
            'is_emergency': row['is_emergency'] == 1,
            'is_active': row['is_active'] == 1 || row['is_active'] == true,
            'timestamp': row['timestamp'],
            'is_deleted': row['is_deleted'] == 1,
            'updated_at': row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          });
          syncedIds.add(row['id']);
          await dbHelper.systemDao.clearSyncMetadata('alerts', row['id']);
        } on PostgrestException catch (e) {
          if (e.code == '42501') {
            // RLS policy violation — mark as synced to stop retrying
            debugPrint("⚠️ Alerts: RLS policy blocked push for ${row['id']}. Marking synced to prevent retry.");
            syncedIds.add(row['id']);
          } else {
            debugPrint("❌ SystemSyncHandler: Alert push error: $e");
          }
        }
      }
      if (syncedIds.isNotEmpty) {
        await dbHelper.markBatchAsSynced('alerts', syncedIds);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Alerts Push Error: $e");
    }
  }

  Future<void> pullAlerts() async {
    await _withRetry(() async {
      // 1. PARITY PURGE
      final cloudIdsData = await supabase.from('alerts').select('id');
      final cloudIds = cloudIdsData.map((row) => row['id'].toString()).toSet();
      
      final localAlerts = await dbHelper.systemDao.getAlerts();
      for (final local in localAlerts) {
        final id = local['id'].toString();
        if (!cloudIds.contains(id)) {
          await dbHelper.systemDao.hardDeleteAlert(id);
          debugPrint("🧹 Parity Purge: Removed ghost alert $id");
        }
      }

      // 2. INCREMENTAL PULL
      final lastSync = await _getLastSync('alerts');
      var query = supabase.from('alerts').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudData = await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      for (var row in cloudData) {
        await dbHelper.systemDao.insertAlert({
          ...row,
          'is_synced': 1,
        });
        latestTimestamp = row['updated_at'];
      }
      if (latestTimestamp != null) {
        await _updateLastSync('alerts', latestTimestamp);
      }
      
      SyncEventBus.instance.triggerAlertUpdate();
    });
  }

  // --- SCHEDULES ---

  Future<void> pushSchedules() async {
    try {
      final unsynced = await dbHelper.systemDao.getUnsyncedSchedules();
      for (final row in unsynced) {
        await supabase.from('schedules').upsert({
          'id': row['id'],
          'type': row['type'],
          'date': row['date'],
          'location': row['location'],
          'assigned': row['assigned'],
          'color_value': row['color_value'],
          'is_deleted': row['is_deleted'] == 1,
          'updated_at': row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        });
        await dbHelper.systemDao.clearSyncMetadata('schedules', row['id']);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Schedules Push Error: $e");
    }
  }

  Future<void> pullSchedules() async {
    await _withRetry(() async {
      final lastSync = await _getLastSync('schedules');
      var query = supabase.from('schedules').select();
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
        _scheduleChangeController.add(null);
      }
    });
  }

  // --- PUBLIC MANIPULATION ---

  Future<void> pushAnnouncement({
    required String id,
    required String title,
    required String content,
    required String targetGroup,
    required DateTime timestamp,
    required bool isActive,
  }) async {
    try {
      // 1. LOCAL FIRST: Persist to DAO with is_synced = 0
      await dbHelper.systemDao.insertAnnouncement({
        'id': id,
        'title': title,
        'content': content,
        'target_group': targetGroup,
        'timestamp': timestamp.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      // 2. TRIGGER UI: Dao.insertAnnouncement already calls refreshAnnouncements()
      
      // 3. CLOUD SYNC: Trigger immediate push in background
      unawaited(pushAnnouncements());
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Announcement local persist failed. $e");
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      // 1. LOCAL FIRST: Mark as deleted and unsynced
      await dbHelper.systemDao.deleteAnnouncement(id);
      
      // 2. CLOUD SYNC: Trigger immediate push in background
      unawaited(pushAnnouncements());
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Announcement local delete failed. $e");
    }
  }

  Future<void> pushSchedule({
    required String id,
    required String type,
    required DateTime date,
    required String location,
    required String assigned,
    required int colorValue,
  }) async {
    try {
      // 1. LOCAL FIRST
      await dbHelper.systemDao.insertSchedule({
        'id': id,
        'type': type,
        'date': date.toIso8601String(),
        'location': location,
        'assigned': assigned,
        'color_value': colorValue,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      // 2. CLOUD SYNC
      unawaited(pushSchedules());
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Schedule local persist failed. $e");
    }
  }

  Future<void> deleteScheduleCloud(String id) async {
    try {
      // 1. LOCAL FIRST (Soft Delete)
      await dbHelper.systemDao.deleteSchedule(id);
      
      // 2. CLOUD SYNC
      unawaited(pushSchedules());
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Schedule local delete failed. $e");
    }
  }

  // --- ALERTS MANIPULATION ---

  Future<void> pushAlert({
    required String id,
    required String message,
    required String targetGroup,
    required bool isEmergency,
    required DateTime timestamp,
    required bool isActive,
  }) async {
    try {
      // 1. LOCAL FIRST
      await dbHelper.systemDao.insertAlert({
        'id': id,
        'message': message,
        'target_group': targetGroup,
        'is_emergency': isEmergency ? 1 : 0,
        'timestamp': timestamp.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      // 2. CLOUD SYNC
      unawaited(pushAlerts());
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Alert local persist failed. $e");
    }
  }

  Future<void> deleteAlert(String id) async {
    try {
      // 1. LOCAL FIRST (Hard delete from cloud often preferred for Alerts to stop noise)
      await dbHelper.systemDao.deleteAlert(id);
      
      // 2. CLOUD SYNC
      unawaited(pushAlerts());
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Alert local delete failed. $e");
    }
  }

  Future<void> reactToAnnouncement(String announcementId, String emoji, String userId) async {
    try {
      final localData = await dbHelper.systemDao.getAnnouncementById(announcementId);
      if (localData == null) return;

      Map<String, dynamic> reactions = {};
      if (localData['reactions'] is String) {
        try {
          reactions = json.decode(localData['reactions']);
        } catch (_) {}
      } else if (localData['reactions'] is Map) {
        reactions = Map<String, dynamic>.from(localData['reactions']);
      }

      List<dynamic> users = List<dynamic>.from(reactions[emoji] ?? []);
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }

      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }

      await dbHelper.systemDao.updateAnnouncement({
        'id': announcementId,
        'reactions': json.encode(reactions),
      });

      SyncEventBus.instance.triggerAnnouncementUpdate();

      // Background Cloud Sync
      unawaited(() async {
        try {
          await supabase.from('announcements').update({'reactions': reactions}).eq('id', announcementId);
        } catch (_) {}
      }());
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: reactToAnnouncement Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements({dynamic currentUser}) async {
    try {
      final all = await dbHelper.systemDao.getAnnouncements();
      var filtered = all.where((a) {
        final isDeleted = a['is_deleted'] == 1 || a['is_deleted'] == true;
        final isActive = a['is_active'] == 1 || a['is_active'] == true || a['isActive'] == 1 || a['isActive'] == true;
        return !isDeleted && isActive;
      }).toList();

      if (currentUser != null) {
        final int age = currentUser.age;
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') {
            return true;
          }
          if (target == 'SENIORS' && age >= 60) {
            return true;
          }
          if (target == 'CHILDREN' && age <= 12) {
            return true;
          }
          return false;
        }).toList();
      }

      filtered.sort((a, b) {
        final targetA = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
        final targetB = (b['target_group'] ?? b['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
        
        final isUrgentA = targetA == 'BROADCAST_ALL';
        final isUrgentB = targetB == 'BROADCAST_ALL';

        if (isUrgentA && !isUrgentB) return -1;
        if (!isUrgentA && isUrgentB) return 1;

        final dtA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final dtB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return dtB.compareTo(dtA);
      });

      return filtered.map((a) {
        final processed = Map<String, dynamic>.from(a);
        if (processed['reactions'] is String) {
          try {
            processed['reactions'] = json.decode(processed['reactions']);
          } catch (_) {
            processed['reactions'] = {};
          }
        }
        return processed;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    try {
      final all = await dbHelper.systemDao.getAlerts();
      var filtered = all.where((a) {
        final isDeleted = a['is_deleted'] == 1 || a['is_deleted'] == true;
        final isActive = a['is_active'] == 1 || a['is_active'] == true || a['isActive'] == 1 || a['isActive'] == true;
        return !isDeleted && isActive;
      }).toList();

      if (currentUser != null) {
        final int age = currentUser.age;
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') {
            return true;
          }
          if (target == 'SENIORS' && age >= 60) {
            return true;
          }
          if (target == 'CHILDREN' && age <= 12) {
            return true;
          }
          return false;
        }).toList();
      }

      filtered.sort((a, b) {
        final dtA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final dtB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return dtB.compareTo(dtA);
      });

      return filtered;
    } catch (e) {
      return [];
    }
  }

  // --- REAL-TIME SUBSCRIPTIONS ---

  void subscribeAll() {
    _announcementsChannel = _subscribe('announcements', (payload) async {
      debugPrint("📢 Realtime: Announcement change detected: ${payload.eventType}");
      
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null) {
          await dbHelper.systemDao.hardDeleteAnnouncement(id);
          SyncEventBus.instance.triggerAnnouncementUpdate();
        }
        return;
      }

      // OPTIMIZATION: Inject payload directly into DB to bypass RLS pull filters for soft-deletes
      if (payload.newRecord.isNotEmpty) {
        await dbHelper.systemDao.insertAnnouncement({...payload.newRecord, 'is_synced': 1});
        SyncEventBus.instance.triggerNewAnnouncement(payload.newRecord);
        _handleNewAnnouncementNotification(payload.newRecord);
      } else if (payload.oldRecord.isNotEmpty) {
        await pullAnnouncements();
      }
      
      SyncEventBus.instance.triggerAnnouncementUpdate();
    });

    _alertsChannel = _subscribe('alerts', (payload) async {
      debugPrint("📢 Realtime: Alert change detected: ${payload.eventType}");
      
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null) {
          await dbHelper.systemDao.hardDeleteAlert(id);
          SyncEventBus.instance.triggerAlertUpdate();
        }
        return;
      }

      if (payload.newRecord.isNotEmpty) {
        // Direct injection to trigger reactive DAO stream
        await dbHelper.systemDao.insertAlert({...payload.newRecord, 'is_synced': 1});
        SyncEventBus.instance.triggerNewAlert(payload.newRecord);
      }
      
      SyncEventBus.instance.triggerAlertUpdate();
    });

    _schedulesChannel = _subscribe('schedules', (payload) async {
      debugPrint("📢 Realtime: Schedule change detected: ${payload.eventType}");
      
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null) {
          await dbHelper.systemDao.deleteSchedule(id); // Using existing delete logic
          SyncEventBus.instance.triggerScheduleUpdate();
        }
        return;
      }

      if (payload.newRecord.isNotEmpty) {
        await dbHelper.systemDao.insertSchedule({...payload.newRecord, 'is_synced': 1});
        SyncEventBus.instance.triggerScheduleUpdate();
      }
    });
  }

  RealtimeChannel _subscribe(String table, void Function(dynamic payload) onData) {
    return supabase
        .channel('public:${table}_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: onData,
        )
        .subscribe();
  }

  void unsubscribeAll() {
    _announcementsChannel?.unsubscribe();
    _alertsChannel?.unsubscribe();
    _schedulesChannel?.unsubscribe();
  }

  void _handleNewAnnouncementNotification(Map<String, dynamic> row) {
    // SECURITY: Admins do not need to be notified of their own announcements via push logic
    if (AppEnvironment().isDesktopAdmin) return;

    final target = (row['target_group'] ?? row['targetGroup'])?.toString() ?? 'all';
    final title = row['title'] ?? "New Announcement";
    final body = row['content'] ?? "Tap to view details";

    if (target.toUpperCase() == 'BROADCAST_ALL') {
      NotificationService().showSystemAlertNotification(
        title: "🚨 URGENT: $title",
        body: body,
      );
    } else {
      NotificationService().showAnnouncementNotification(
        title: title,
        body: body,
      );
    }
  }

  // --- PRIVATE HELPERS ---

  Future<String?> _getLastSync(String table) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_$table');
  }

  Future<void> _updateLastSync(String table, String? timestamp) async {
    if (timestamp == null) {
      return;
    }
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
        if (attempts >= maxAttempts) {
          debugPrint("❌ SystemSyncHandler: Operation failed after $maxAttempts attempts: $e");
          rethrow;
        }
        debugPrint("⚠️ SystemSyncHandler: Attempt $attempts failed ($e). Retrying...");
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
  }
}
