import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/i_system_repository.dart';

class WebSystemRepository implements ISystemRepository {
  final _supabase = Supabase.instance.client;

  // Managed controllers for broadcast streams
  final _announcementController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final _alertController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final _scheduleController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Status tracking
  bool _isAnnouncementsRealtimeOperational = false;
  bool _isAlertsRealtimeOperational = false;
  int _announcementRetryCount = 0;
  int _alertRetryCount = 0;

  // Polling timers
  Timer? _announcementPollingTimer;
  Timer? _alertPollingTimer;
  Timer? _announcementRetryTimer;
  Timer? _alertRetryTimer;

  WebSystemRepository() {
    _initStreams();
  }

  void _initStreams() {
    _setupRealtimeAnnouncements();
    _setupRealtimeAlerts();
    _setupRealtimeSchedules();
  }

  @override
  Stream<List<Map<String, dynamic>>> get announcementStream =>
      _announcementController.stream;

  @override
  Stream<List<Map<String, dynamic>>> get alertStream => _alertController.stream;

  @override
  Stream<List<Map<String, dynamic>>> get scheduleStream =>
      _scheduleController.stream;

  // ──────────────────────────────────────────────────────────────────────────
  // ANNOUNCEMENTS
  // ──────────────────────────────────────────────────────────────────────────

  void _setupRealtimeAnnouncements() {
    _announcementRetryTimer?.cancel();

    _supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .listen(
          (data) {
            _isAnnouncementsRealtimeOperational = true;
            _announcementRetryCount = 0;
            _stopAnnouncementPolling();

            final filtered = data
                .where(
                    (a) => a['is_deleted'] == false && a['is_active'] == true)
                .toList();
            _announcementController.add(filtered);
          },
          onError: (error) {
            _isAnnouncementsRealtimeOperational = false;
            debugPrint(
                "❌ [WebSystemRepository] Announcement Realtime Error: $error");

            _startAnnouncementPolling();
            _retryAnnouncementRealtime();
          },
          cancelOnError: false,
        );
  }

  void _retryAnnouncementRealtime() {
    if (_announcementRetryCount >= 5) {
      return; // Stop trying after 5 attempts, rely on polling
    }

    _announcementRetryCount++;
    final delay = Duration(seconds: 1 << _announcementRetryCount);

    _announcementRetryTimer = Timer(delay, () => _setupRealtimeAnnouncements());
  }

  void _startAnnouncementPolling() {
    if (_announcementPollingTimer != null) return;

    debugPrint(
        "⚡ [WebSystemRepository] Announcement REST polling active (30s).");
    _announcementPollingTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isAnnouncementsRealtimeOperational) {
        final data = await fetchAnnouncements();
        _announcementController.add(data);
      }
    });

    // Immediate fetch when polling starts
    fetchAnnouncements().then((data) => _announcementController.add(data));
  }

  void _stopAnnouncementPolling() {
    _announcementPollingTimer?.cancel();
    _announcementPollingTimer = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ALERTS
  // ──────────────────────────────────────────────────────────────────────────

  void _setupRealtimeAlerts() {
    _alertRetryTimer?.cancel();

    _supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .listen(
          (data) {
            _isAlertsRealtimeOperational = true;
            _alertRetryCount = 0;
            _stopAlertPolling();

            final filtered = data
                .where(
                    (a) => a['is_deleted'] == false && a['is_active'] == true)
                .toList();
            _alertController.add(filtered);
          },
          onError: (error) {
            _isAlertsRealtimeOperational = false;
            debugPrint("❌ [WebSystemRepository] Alert Realtime Error: $error");

            _startAlertPolling();
            _retryAlertRealtime();
          },
          cancelOnError: false,
        );
  }

  void _retryAlertRealtime() {
    if (_alertRetryCount >= 5) return;

    _alertRetryCount++;
    final delay = Duration(seconds: 1 << _alertRetryCount);

    _alertRetryTimer = Timer(delay, () => _setupRealtimeAlerts());
  }

  void _startAlertPolling() {
    if (_alertPollingTimer != null) return;

    debugPrint("⚡ [WebSystemRepository] Alert REST polling active (30s).");
    _alertPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isAlertsRealtimeOperational) {
        final data = await fetchAlerts();
        _alertController.add(data);
      }
    });

    fetchAlerts().then((data) => _alertController.add(data));
  }

  void _stopAlertPolling() {
    _alertPollingTimer?.cancel();
    _alertPollingTimer = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCHEDULES (Simple pass-through for now, or add polling if needed)
  // ──────────────────────────────────────────────────────────────────────────

  void _setupRealtimeSchedules() {
    _supabase.from('schedules').stream(primaryKey: ['id']).listen(
      (data) {
        final filtered = data.where((a) => a['is_deleted'] == false).toList();
        _scheduleController.add(filtered);
      },
      onError: (error) {
        debugPrint("❌ [WebSystemRepository] Schedule Stream Error: $error");
      },
      cancelOnError: false,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAnnouncements(
      {dynamic currentUser}) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_deleted', false)
          .eq('is_active', true)
          .order('timestamp', ascending: false);

      List<Map<String, dynamic>> filtered =
          List<Map<String, dynamic>>.from(response);

      if (currentUser != null) {
        final int age = currentUser.age;
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])
                  ?.toString()
                  .toUpperCase() ??
              'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
          if (target == 'SENIORS' && age >= 60) return true;
          if (target == 'CHILDREN' && age <= 12) return true;
          return false;
        }).toList();
      }
      return filtered;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    try {
      final response = await _supabase
          .from('alerts')
          .select()
          .eq('is_deleted', false)
          .eq('is_active', true)
          .order('timestamp', ascending: false);

      List<Map<String, dynamic>> filtered =
          List<Map<String, dynamic>>.from(response);

      if (currentUser != null) {
        final int age = currentUser.age;
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])
                  ?.toString()
                  .toUpperCase() ??
              'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
          if (target == 'SENIORS' && age >= 60) return true;
          if (target == 'CHILDREN' && age <= 12) return true;
          return false;
        }).toList();
      }
      return filtered;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> reactToAnnouncement(
      String announcementId, String emoji, String userId) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select('reactions')
          .eq('id', announcementId)
          .single();
      Map<String, dynamic> reactions = {};
      if (response['reactions'] is Map) {
        reactions = Map<String, dynamic>.from(response['reactions']);
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

      await _supabase
          .from('announcements')
          .update({'reactions': reactions}).eq('id', announcementId);
    } catch (_) {}
  }

  @override
  Future<void> syncNow({dynamic authRepo, dynamic historyRepo}) async {
    if (historyRepo != null &&
        authRepo != null &&
        authRepo.currentUser != null) {
      await historyRepo.loadUserHistory(authRepo.currentUser.id);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders(String userId) async => [];

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async => 1;

  @override
  Future<int> updateReminder(Map<String, dynamic> reminder) async => 1;
}
