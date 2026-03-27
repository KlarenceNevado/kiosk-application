import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_models.dart';
import '../../../../core/services/database/database_helper.dart';
import '../../../../core/services/database/sync_service.dart';

class AdminRepository extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Announcement> _announcements = [];
  List<HealthActivity> _schedules = [];
  List<SystemAlert> _alerts = [];

  // Automated Alert Thresholds
  double _sysHigh = 140;
  double _sysLow = 90;
  double _hrHigh = 100;

  List<Announcement> get announcements => _announcements;
  List<HealthActivity> get schedules => _schedules;
  List<SystemAlert> get alerts => _alerts;

  double get sysHigh => _sysHigh;
  double get sysLow => _sysLow;
  double get hrHigh => _hrHigh;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  StreamSubscription? _announcementSub;
  StreamSubscription? _alertsSub;
  StreamSubscription? _schedulesSub;

  // This init method will now also subscribe to real-time changes
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _dbHelper.getAnnouncements(),
        _dbHelper.getSchedules(),
        _dbHelper.getAlerts(),
      ]);

      _announcements = results[0].map((m) => Announcement.fromMap(m)).toList();
      _schedules = results[1].map((m) => HealthActivity.fromMap(m)).toList();
      _alerts = results[2].map((m) => SystemAlert.fromMap(m)).toList();

      await _loadThresholds();
      
      // Listen to reactive DAO streams instead of manual Supabase channels
      _announcementSub = _dbHelper.systemDao.announcementStream.listen((list) {
        _announcements = list.map((m) => Announcement.fromMap(m)).toList();
        notifyListeners();
      });

      _alertsSub = _dbHelper.systemDao.alertStream.listen((list) {
        _alerts = list.map((m) => SystemAlert.fromMap(m)).toList();
        notifyListeners();
      });

      _schedulesSub = _dbHelper.systemDao.scheduleStream.listen((list) {
        _schedules = list.map((m) => HealthActivity.fromMap(m)).toList();
        notifyListeners();
      });
    } catch (e) {
      debugPrint("❌ AdminRepository Init Error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    _sysHigh = prefs.getDouble('alert_sys_high') ?? 140;
    _sysLow = prefs.getDouble('alert_sys_low') ?? 90;
    _hrHigh = prefs.getDouble('alert_hr_high') ?? 100;
  }

  Future<void> updateThresholds(
      {double? sysHigh, double? sysLow, double? hrHigh}) async {
    final prefs = await SharedPreferences.getInstance();
    if (sysHigh != null) {
      _sysHigh = sysHigh;
      await prefs.setDouble('alert_sys_high', sysHigh);
    }
    if (sysLow != null) {
      _sysLow = sysLow;
      await prefs.setDouble('alert_sys_low', sysLow);
    }
    if (hrHigh != null) {
      _hrHigh = hrHigh;
      await prefs.setDouble('alert_hr_high', hrHigh);
    }
    notifyListeners();
  }


  // Dispose method to cancel stream subscriptions
  @override
  void dispose() {
    _announcementSub?.cancel();
    _alertsSub?.cancel();
    _schedulesSub?.cancel();
    super.dispose();
  }

  // --- ANNOUNCEMENTS ---
  Future<void> fetchAnnouncements() async {
    final rawList = await _dbHelper.getAnnouncements();
    _announcements = rawList.map((m) => Announcement.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addAnnouncement({
    required String title,
    required String content,
    required String targetGroup,
  }) async {
    final announcement = Announcement(
      id: const Uuid().v4(),
      title: title,
      content: content,
      targetGroup: targetGroup,
      timestamp: DateTime.now(),
      isActive: true,
    );

    // OPTIMISTIC UPDATE: Add to local memory first
    _announcements.insert(0, announcement);
    notifyListeners();

    // PERSIST IN BACKGROUND
    unawaited(() async {
      try {
        final map = announcement.toMap();
        map['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await _dbHelper.insertAnnouncement(map);
        await SyncService().pushAnnouncement(
          id: announcement.id,
          title: announcement.title,
          content: announcement.content,
          targetGroup: announcement.targetGroup,
          timestamp: announcement.timestamp,
          isActive: announcement.isActive,
        );
        debugPrint(
            "✅ Background: Announcement '${announcement.title}' persisted and pushed.");
      } catch (e) {
        debugPrint("❌ Background: Failed to persist announcement: $e");
        // Rollback? Usually not needed for simple apps, but good to know
      }
    }());
  }

  Future<void> deleteAnnouncement(String id) async {
    // OPTIMISTIC UPDATE: Remove from memory
    final index = _announcements.indexWhere((a) => a.id == id);
    if (index != -1) {
      _announcements.removeAt(index);
      notifyListeners();
    }

    // PERSIST IN BACKGROUND
    unawaited(() async {
      try {
        await _dbHelper.deleteAnnouncement(id);
        // Supabase soft-deletion
        await SyncService().supabase.from('announcements').delete().eq('id', id);
        debugPrint("✅ Background: Announcement '$id' deleted.");
      } catch (e) {
        debugPrint("❌ Background: Failed to delete announcement: $e");
      }
    }());
  }

  Future<void> toggleAnnouncementStatus(
      Announcement announcement, bool isActive) async {
    // OPTIMISTIC UPDATE: Find and update in memory
    final index = _announcements.indexWhere((a) => a.id == announcement.id);
    if (index != -1) {
      _announcements[index] = Announcement(
        id: announcement.id,
        title: announcement.title,
        content: announcement.content,
        targetGroup: announcement.targetGroup,
        timestamp: announcement.timestamp,
        isActive: isActive,
        reactions: announcement.reactions,
      );
      notifyListeners();
    }

    // PERSIST IN BACKGROUND
    unawaited(() async {
      try {
        final map = announcement.toMap();
        map['is_active'] = isActive ? 1 : 0;
        map['is_synced'] = 0;
        map['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await _dbHelper.updateAnnouncement(map);

        await SyncService().pushAnnouncement(
          id: announcement.id,
          title: announcement.title,
          content: announcement.content,
          targetGroup: announcement.targetGroup,
          timestamp: announcement.timestamp,
          isActive: isActive,
        );
        debugPrint("✅ Background: Announcement status toggled.");
      } catch (e) {
        debugPrint("❌ Background: Failed to toggle announcement: $e");
      }
    }());
  }

  // --- SCHEDULES ---
  Future<void> fetchSchedules() async {
    final rawList = await _dbHelper.getSchedules();
    _schedules = rawList.map((m) => HealthActivity.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addSchedule({
    required String type,
    required DateTime date,
    required String location,
    required String assigned,
    required Color color,
  }) async {
    final schedule = HealthActivity(
      id: const Uuid().v4(),
      type: type,
      date: date,
      location: location,
      assigned: assigned,
      color: color,
    );

    // OPTIMISTIC UPDATE: Add to local memory
    _schedules.insert(0, schedule);
    notifyListeners();

    // PERSIST IN BACKGROUND
    unawaited(() async {
      try {
        await _dbHelper.insertSchedule(schedule.toMap());
        await SyncService().pushSchedule(
          id: schedule.id,
          type: schedule.type,
          date: schedule.date,
          location: schedule.location,
          assigned: schedule.assigned,
          colorValue: schedule.color.toARGB32(),
        );
        debugPrint(
            "✅ Background: Schedule '${schedule.type}' persisted and pushed.");
      } catch (e) {
        debugPrint("❌ Background: Failed to persist schedule: $e");
      }
    }());
  }

  Future<void> deleteSchedule(String id) async {
    // OPTIMISTIC UPDATE: Remove from memory
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index != -1) {
      _schedules.removeAt(index);
      notifyListeners();
    }

    // PERSIST IN BACKGROUND
    unawaited(() async {
      try {
        await _dbHelper.deleteSchedule(id);
        // Supabase soft-deletion
        await SyncService().supabase.from('schedules').update({
          'is_deleted': true,
          'updated_at': DateTime.now().toUtc().toIso8601String()
        }).eq('id', id);
        debugPrint("✅ Background: Schedule '$id' deleted.");
      } catch (e) {
        debugPrint("❌ Background: Failed to delete schedule: $e");
      }
    }());
  }

  // --- ALERTS ---
  Future<void> fetchAlerts() async {
    final rawList = await _dbHelper.getAlerts();
    _alerts = rawList.map((m) => SystemAlert.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addAlert({
    required String message,
    required String targetGroup,
    required bool isEmergency,
  }) async {
    final alert = SystemAlert(
      id: const Uuid().v4(),
      message: message,
      targetGroup: targetGroup,
      isEmergency: isEmergency,
      timestamp: DateTime.now(),
      isActive: true, // newly added
    );
    await _dbHelper.insertAlert(alert.toMap());

    // Mirror to Supabase Cloud
    unawaited(SyncService().supabase.from('alerts').upsert({
      'id': alert.id,
      'message': alert.message,
      'target_group': alert.targetGroup,
      'is_emergency': alert.isEmergency,
      'timestamp': alert.timestamp.toUtc().toIso8601String(),
      'is_active': alert.isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).catchError((e) {
      debugPrint("⚠️ Failed to push Alert to cloud: $e");
      return null;
    }));

    await fetchAlerts();
  }

  Future<void> deleteAlert(String id) async {
    // OPTIMISTIC UPDATE: Remove from memory
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alerts.removeAt(index);
      notifyListeners();
    }

    // PERSIST IN BACKGROUND
    unawaited(() async {
      try {
        await _dbHelper.deleteAlert(id);
        // Supabase hard-deletion triggers immediate Realtime removal for clients
        await SyncService().supabase.from('alerts').delete().eq('id', id);
        debugPrint("✅ Background: Alert '$id' hard deleted from cloud.");
      } catch (e) {
        debugPrint("❌ Background: Failed to delete alert: $e");
      }
    }());
  }
}
