import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_handler.dart';

class SystemSyncHandler extends SyncHandler {
  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _schedulesChannel;

  final _announcementChangeController = StreamController<void>.broadcast();
  Stream<void> get announcementStream => _announcementChangeController.stream;

  final _newAnnouncementController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newAnnouncementStream => _newAnnouncementController.stream;

  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  final _newAlertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newAlertStream => _newAlertController.stream;

  final _scheduleChangeController = StreamController<void>.broadcast();
  Stream<void> get scheduleStream => _scheduleChangeController.stream;

  SystemSyncHandler(super.supabase);

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
      for (final row in unsynced) {
        await supabase.from('announcements').upsert({
          'id': row['id'],
          'title': row['title'],
          'content': row['content'],
          'target_group': row['target_group'],
          'timestamp': row['timestamp'],
          'is_active': row['is_active'] == 1,
          'is_deleted': row['is_deleted'] == 1,
          'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        });
        await dbHelper.systemDao.clearSyncMetadata('announcements', row['id']);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Announcements Push Error: $e");
    }
  }

  Future<void> pullAnnouncements() async {
    try {
      final lastSync = await _getLastSync('announcements');
      var query = supabase.from('announcements').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudData = await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      for (var row in cloudData) {
        await dbHelper.systemDao.insertAnnouncement({
          ...row,
          'is_synced': 1,
        });
        latestTimestamp = row['updated_at'];
      }
      if (latestTimestamp != null) {
        await _updateLastSync('announcements', latestTimestamp);
        _announcementChangeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Announcements Pull Error: $e");
    }
  }

  // --- ALERTS ---

  Future<void> pushAlerts() async {
    try {
      final unsynced = await dbHelper.systemDao.getUnsyncedAlerts();
      for (final row in unsynced) {
        await supabase.from('alerts').upsert({
          'id': row['id'],
          'message': row['message'],
          'target_group': row['target_group'],
          'is_emergency': row['is_emergency'] == 1,
          'timestamp': row['timestamp'],
          'is_deleted': row['is_deleted'] == 1,
          'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        });
        await dbHelper.systemDao.clearSyncMetadata('alerts', row['id']);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Alerts Push Error: $e");
    }
  }

  Future<void> pullAlerts() async {
    try {
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
        _alertController.add({'type': 'sync'});
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Alerts Pull Error: $e");
    }
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
          'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
        });
        await dbHelper.systemDao.clearSyncMetadata('schedules', row['id']);
      }
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Schedules Push Error: $e");
    }
  }

  Future<void> pullSchedules() async {
    try {
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
    } catch (e) {
      debugPrint("❌ SystemSyncHandler: Schedules Pull Error: $e");
    }
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
      await supabase.from('announcements').upsert({
        'id': id,
        'title': title,
        'content': content,
        'target_group': targetGroup,
        'timestamp': timestamp.toIso8601String(),
        'is_active': isActive,
      });
      await dbHelper.systemDao.clearSyncMetadata('announcements', id);
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Announcement push failed. $e");
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await supabase.from('announcements').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Announcement delete failed. $e");
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
      await supabase.from('schedules').upsert({
        'id': id,
        'type': type,
        'date': date.toIso8601String(),
        'location': location,
        'assigned': assigned,
        'color_value': colorValue,
      });
      await dbHelper.systemDao.clearSyncMetadata('schedules', id);
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Schedule push failed. $e");
    }
  }

  Future<void> deleteScheduleCloud(String id) async {
    try {
      await supabase.from('schedules').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint("⚠️ SystemSyncHandler: Schedule delete failed. $e");
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

      _announcementChangeController.add(null);

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
      var filtered = all.where((a) => a['is_deleted'] != 1 && a['is_deleted'] != true).toList();

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
    _announcementsChannel = _subscribe('announcements', (payload) {
      pullAnnouncements();
      _announcementChangeController.add(null);
      if (payload.newRecord.isNotEmpty) {
        _newAnnouncementController.add(payload.newRecord);
      }
    });

    _alertsChannel = _subscribe('alerts', (payload) {
      pullAlerts();
      _alertController.add({'type': 'sync'});
      if (payload.newRecord.isNotEmpty) {
        _newAlertController.add(payload.newRecord);
      }
    });

    _schedulesChannel = _subscribe('schedules', (payload) {
      pullSchedules();
      _scheduleChangeController.add(null);
    });
  }

  RealtimeChannel _subscribe(String table, void Function(PostgresChangePayload payload) onData) {
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
}
