import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'connection_manager.dart';
import 'sync/patient_sync_handler.dart';
import 'sync/vitals_sync_handler.dart';
import 'sync/system_sync_handler.dart';
import 'sync/chat_sync_handler.dart';
import '../system/file_storage_service.dart';
import 'database_helper.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/health_check/models/vital_signs_model.dart';
import 'package:kiosk_application/core/services/security/security_logger.dart';

class SyncService with WidgetsBindingObserver {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  late final PatientSyncHandler patientHandler;
  late final VitalsSyncHandler vitalsHandler;
  late final SystemSyncHandler systemHandler;
  late final ChatSyncHandler chatHandler;

  SyncService._internal() {
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    patientHandler = PatientSyncHandler(client);
    vitalsHandler = VitalsSyncHandler(client);
    systemHandler = SystemSyncHandler(client);
    chatHandler = ChatSyncHandler(client);
  }

  bool _isSyncing = false;
  Completer<void>? _syncMutex;

  SupabaseClient get supabase => Supabase.instance.client;

  // --- PUBLIC STREAMS (Delegated) ---
  Stream<void> get announcementStream => systemHandler.announcementStream;
  Stream<Map<String, dynamic>> get newAnnouncementStream => systemHandler.newAnnouncementStream;
  Stream<Map<String, dynamic>> get newVitalStream => vitalsHandler.newRecordStream;
  Stream<Map<String, dynamic>> get newAlertStream => systemHandler.newAlertStream;
  Stream<void> get scheduleStream => systemHandler.scheduleStream;
  Stream<void> get alertStream => systemHandler.alertStream;
  Stream<void> get patientStream => patientHandler.stream;
  Stream<void> get vitalsStream => vitalsHandler.stream;

  final List<Future<void> Function()> _syncCallbacks = [];

  void registerSyncCallback(Future<void> Function() callback) {
    if (!_syncCallbacks.contains(callback)) {
      _syncCallbacks.add(callback);
    }
  }

  void startSyncLoop() {
    debugPrint("🔄 SyncService: Starting sync loop and real-time listeners...");
    _attemptSync();

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _attemptSync();
    });

    // Subscriptions
    systemHandler.subscribeAll();
    patientHandler.subscribe((_) {});
    vitalsHandler.subscribe((_) {});
    chatHandler.subscribe();

    ConnectionManager().statusStream.listen((status) {
      if (status == ConnectionStatus.online) {
        _attemptSync();
      }
    });
  }

  Future<void> fullSyncForUser(String userId) async {
    SecurityLogger.info("Starting EAGER FULL SYNC for user ID: $userId");
    await _withSyncMutex(() async {
      try {
        await patientHandler.pull();
        await systemHandler.pull();
        await vitalsHandler.pull();
        await _cacheFilesInBackground();
      } catch (e) {
        debugPrint("❌ SyncService: Full Sync Error: $e");
      }
    });
  }

  /// Forces a push of ALL local records to the cloud, regardless of is_synced status.
  /// This ensures that "previous" data from other devices/versions is unified in the latest cloud.
  Future<void> forcePushAll() async {
    SecurityLogger.info("🚀 Starting FORCE PUSH ALL for system unification...");
    await _withSyncMutex(() async {
      try {
        // 1. Fetch all local patients
        final patients = await DatabaseHelper.instance.getPatients();
        for (final p in patients) {
          await patientHandler.createPatient(p);
        }

        // 2. Fetch all local vitals
        final vitals = await DatabaseHelper.instance.getAllRecords();
        for (final v in vitals) {
          // We use _upsertVitalSign which is private, let's make a public one or use create
          await vitalsHandler.createVitalSign(v);
        }

        debugPrint("✅ SyncService: Force Push All complete.");
      } catch (e) {
        debugPrint("❌ SyncService: Force Push Error: $e");
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attemptSync();
      systemHandler.subscribeAll();
      patientHandler.subscribe((_) {});
      vitalsHandler.subscribe((_) {});
    }
  }

  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
    systemHandler.unsubscribeAll();
    patientHandler.unsubscribe();
    vitalsHandler.unsubscribe();
  }

  void triggerSync() => _attemptSync();

  Future<void> _attemptSync() async {
    if (_isSyncing) {
      return;
    }
    await _withSyncMutex(() async {
      // Ensure DB is initialized before handlers access DAOs
      await DatabaseHelper.instance.database;

      if (ConnectionManager().currentStatus != ConnectionStatus.online) {
        return;
      }
      try {
        await _syncPendingRecords();
      } catch (e) {
        debugPrint("❌ Sync Loop Error: $e");
      }
    });
  }

  Future<void> _syncPendingRecords() async {
    _isSyncing = true;
    try {
      for (final callback in _syncCallbacks) {
        await callback();
      }

      // Parallel Push
      await Future.wait([
        patientHandler.push(),
        vitalsHandler.push(),
        systemHandler.push(),
        chatHandler.push(),
      ]);

      // Parallel Pull
      await Future.wait([
        patientHandler.pull(),
        vitalsHandler.pull(),
        systemHandler.pull(),
      ]);

      await _cacheFilesInBackground();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _cacheFilesInBackground() async {
    try {
      // Ensure DB is initialized
      await DatabaseHelper.instance.database;

      final db = await DatabaseHelper.instance.database;
      // Vitals Reports
      final List<Map<String, dynamic>> vr = await db.query('vitals', where: 'report_url IS NOT NULL AND report_path IS NULL');
      for (final row in vr) {
        final file = await FileStorageService().getCachedFile(row['report_url']);
        if (file != null) {
          await db.update('vitals', {'report_path': file.path}, where: 'id = ?', whereArgs: [row['id']]);
        }
      }
      // Announcements
      final List<Map<String, dynamic>> ar = await db.query('announcements', where: 'media_url IS NOT NULL AND media_path IS NULL');
      for (final row in ar) {
        final file = await FileStorageService().getCachedFile(row['media_url']);
        if (file != null) {
          await db.update('announcements', {'media_path': file.path}, where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    } catch (_) {}
  }

  Future<T> _withSyncMutex<T>(Future<T> Function() action) async {
    while (_syncMutex != null) {
      await _syncMutex!.future;
    }
    _syncMutex = Completer<void>();
    try {
      return await action();
    } finally {
      final m = _syncMutex;
      _syncMutex = null;
      m?.complete();
    }
  }

  // --- DELEGATION: PATIENTS ---
  Future<User?> createPatient(User user) => patientHandler.createPatient(user);
  Future<bool> updatePatient(User user) => patientHandler.updatePatient(user);
  Future<bool> deletePatient(String userId) => patientHandler.deletePatient(userId);
  Future<List<User>> searchPatients(String query) => patientHandler.searchPatients(query);
  Future<User?> authenticatePatient(String phone, String pin) => patientHandler.authenticatePatient(phone, pin);
  Future<List<User>> fetchDependents(String parentId) => patientHandler.fetchDependents(parentId);
  Future<List<Map<String, dynamic>>> findPatient(String name, String phone) => patientHandler.findPatient(name, phone);

  // --- DELEGATION: VITALS ---
  Future<void> createVitalSign(VitalSigns vital) => vitalsHandler.createVitalSign(vital);
  Future<void> updateVitalSign(VitalSigns vital) => vitalsHandler.updateVitalSign(vital);
  Future<List<VitalSigns>> fetchPatientVitalsLocal(String userId) => vitalsHandler.fetchPatientVitalsLocal(userId);
  Future<List<VitalSigns>> fetchPatientVitals(String userId) => vitalsHandler.fetchPatientVitals(userId);
  Future<void> syncFamilyVitals(List<String> ids) => vitalsHandler.syncFamilyVitals(ids);

  // --- DELEGATION: SYSTEM ---
  Future<void> pushAnnouncement({required String id, required String title, required String content, required String targetGroup, required DateTime timestamp, required bool isActive}) =>
      systemHandler.pushAnnouncement(id: id, title: title, content: content, targetGroup: targetGroup, timestamp: timestamp, isActive: isActive);

  Future<void> deleteAnnouncement(String id) => systemHandler.deleteAnnouncement(id);

  Future<void> pushSchedule({required String id, required String type, required DateTime date, required String location, required String assigned, required int colorValue}) =>
      systemHandler.pushSchedule(id: id, type: type, date: date, location: location, assigned: assigned, colorValue: colorValue);

  Future<void> deleteScheduleCloud(String id) => systemHandler.deleteScheduleCloud(id);

  Future<void> reactToAnnouncement(String id, String emoji, String userId) => systemHandler.reactToAnnouncement(id, emoji, userId);

  Future<List<Map<String, dynamic>>> fetchAnnouncements({dynamic currentUser}) async {
    await DatabaseHelper.instance.database;
    return systemHandler.fetchAnnouncements(currentUser: currentUser);
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    await DatabaseHelper.instance.database;
    return systemHandler.fetchAlerts(currentUser: currentUser);
  }

  Future<void> forceDownSyncAndRefresh(var authRepo, var historyRepo, {bool triggerStream = true}) async {
    await _withSyncMutex(() async {
      await Future.wait([patientHandler.pull(), vitalsHandler.pull(), systemHandler.pull()]);
      if (authRepo != null) {
        await authRepo.refreshUsers();
      }
      if (historyRepo != null) {
        await historyRepo.loadAllHistory();
      }
    });
  }
}
