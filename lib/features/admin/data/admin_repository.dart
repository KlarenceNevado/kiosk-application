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

    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().pushAnnouncement(
          id: announcement.id,
          title: announcement.title,
          content: announcement.content,
          targetGroup: announcement.targetGroup,
          timestamp: announcement.timestamp,
          isActive: announcement.isActive,
        );
        debugPrint("✅ Admin: Announcement '${announcement.title}' queued for sync.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to queue announcement: $e");
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

    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().deleteAnnouncement(id);
        debugPrint("✅ Admin: Announcement '$id' marked for deletion sync.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to mark announcement for deletion: $e");
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

    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().pushAnnouncement(
          id: announcement.id,
          title: announcement.title,
          content: announcement.content,
          targetGroup: announcement.targetGroup,
          timestamp: announcement.timestamp,
          isActive: isActive,
        );
        debugPrint("✅ Admin: Announcement status toggle queued.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to queue toggle: $e");
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

    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().pushSchedule(
          id: schedule.id,
          type: schedule.type,
          date: schedule.date,
          location: schedule.location,
          assigned: schedule.assigned,
          colorValue: schedule.color.toARGB32(),
        );
        debugPrint("✅ Admin: Schedule '${schedule.id}' queued for sync.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to queue schedule: $e");
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

    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().deleteScheduleCloud(id);
        debugPrint("✅ Admin: Schedule '$id' marked for deletion sync.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to mark schedule for deletion: $e");
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
    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().pushAlert(
          id: alert.id,
          message: alert.message,
          targetGroup: alert.targetGroup,
          isEmergency: alert.isEmergency,
          timestamp: alert.timestamp,
          isActive: alert.isActive,
        );
        debugPrint("✅ Admin: Alert queued for sync.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to queue alert: $e");
      }
    }());
    
    await fetchAlerts();
  }

  Future<void> deleteAlert(String id) async {
    // OPTIMISTIC UPDATE: Remove from memory
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alerts.removeAt(index);
      notifyListeners();
    }

    // PERSIST VIA SYNC SERVICE (Local-First)
    unawaited(() async {
      try {
        await SyncService().deleteAlert(id);
        debugPrint("✅ Admin: Alert '$id' marked for deletion sync.");
      } catch (e) {
        debugPrint("❌ Admin: Failed to mark alert for deletion: $e");
      }
    }());
  }
}
