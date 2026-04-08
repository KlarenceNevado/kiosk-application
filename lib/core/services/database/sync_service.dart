import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'connection_manager.dart';
import 'sync/patient_sync_handler.dart';
import 'sync/vitals_sync_handler.dart';
import 'sync/system_sync_handler.dart';
import 'sync/chat_sync_handler.dart';
import 'sync/log_sync_handler.dart';
import '../system/file_storage_service.dart';
import 'database_helper.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/health_check/models/vital_signs_model.dart';
import '../system/app_environment.dart';
import '../system/power_manager_service.dart';
import 'package:kiosk_application/core/services/security/security_logger.dart';

class SyncService with WidgetsBindingObserver {
  SyncService._internal({
    PatientSyncHandler? pHandler,
    VitalsSyncHandler? vHandler,
    SystemSyncHandler? sHandler,
    ChatSyncHandler? cHandler,
    LogSyncHandler? lHandler,
  }) {
    // In unit tests, we may provide all handlers to bypass Supabase initialization
    if (pHandler != null &&
        vHandler != null &&
        sHandler != null &&
        cHandler != null &&
        lHandler != null) {
      patientHandler = pHandler;
      vitalsHandler = vHandler;
      systemHandler = sHandler;
      chatHandler = cHandler;
      logHandler = lHandler;
    } else {
      final client = Supabase.instance.client;
      patientHandler = pHandler ?? PatientSyncHandler(client);
      vitalsHandler = vHandler ?? VitalsSyncHandler(client);
      systemHandler = sHandler ?? SystemSyncHandler(client);
      chatHandler = cHandler ?? ChatSyncHandler(client);
      logHandler = lHandler ?? LogSyncHandler(client);
    }
  }

  /// FOR TESTING ONLY: Reset the singleton with mock handlers
  @visibleForTesting
  static void setMockInstance(SyncService mock) {
    _instance = mock;
  }

  @visibleForTesting
  static SyncService createMocked({
    required PatientSyncHandler p,
    required VitalsSyncHandler v,
    required SystemSyncHandler s,
    required ChatSyncHandler c,
  }) {
    return SyncService._internal(
      pHandler: p,
      vHandler: v,
      sHandler: s,
      cHandler: c,
    );
  }

  static SyncService? _instance;
  factory SyncService() => _instance ??= SyncService._internal();

  late final PatientSyncHandler patientHandler;
  late final VitalsSyncHandler vitalsHandler;
  late final SystemSyncHandler systemHandler;
  late final ChatSyncHandler chatHandler;
  late final LogSyncHandler logHandler;

  bool _isSyncing = false;
  Completer<void>? _syncMutex;
  String? _userId;

  SupabaseClient get supabase => Supabase.instance.client;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  final _syncStatusController = StreamController<DateTime?>.broadcast();
  Stream<DateTime?> get lastSyncStream => _syncStatusController.stream;

  // --- PUBLIC STREAMS (Delegated) ---
  Stream<List<Map<String, dynamic>>> get announcementStream =>
      systemHandler.announcementStream;
  Stream<Map<String, dynamic>> get newAnnouncementStream =>
      systemHandler.newAnnouncementStream;
  Stream<Map<String, dynamic>> get newVitalStream =>
      vitalsHandler.newRecordStream;
  Stream<Map<String, dynamic>> get newAlertStream =>
      systemHandler.newAlertStream;
  Stream<List<Map<String, dynamic>>> get scheduleStream =>
      systemHandler.scheduleStream;
  Stream<List<Map<String, dynamic>>> get alertStream =>
      systemHandler.alertStream;
  Stream<void> get patientStream => patientHandler.stream;
  Stream<void> get vitalsStream => vitalsHandler.stream;

  final List<Future<void> Function()> _syncCallbacks = [];

  void registerSyncCallback(Future<void> Function() callback) {
    if (!_syncCallbacks.contains(callback)) {
      _syncCallbacks.add(callback);
    }
  }

  void startSyncLoop() {
    WidgetsBinding.instance.addObserver(this);
    debugPrint("🔄 SyncService: Starting sync loop and real-time listeners...");
    _attemptSync();
    _listenToPowerMode();

    // PWA Optimization: High-frequency sync for Web to provide 'near-realtime' feel
    const syncInterval = kIsWeb ? Duration(seconds: 10) : Duration(minutes: 1);

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (timer) async {
      await _attemptSync();
    });

    // Subscriptions
    final activeId = _getCurrentUserId();
    systemHandler.subscribeAll();
    patientHandler.subscribe((_) => patientHandler.pull());
    vitalsHandler.subscribe((_) => vitalsHandler.pull());

    chatHandler.subscribe(activeId);

    _connectionSubscription?.cancel();
    _connectionSubscription = ConnectionManager().statusStream.listen((status) {
      if (status == ConnectionStatus.online) {
        _attemptSync();
      }
    });
  }

  Timer? _syncTimer;
  StreamSubscription? _connectionSubscription;

  /// Full cleanup of all sync loops and real-time channels.
  /// CRITICAL: Must be called on Logout to prevent data leaks.
  void reset() {
    debugPrint("🛑 SyncService: Resetting and unsubscribing all listeners...");
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    stopListening(); // Removes WidgetsBinding observer and unsubscribes most handlers
    chatHandler.unsubscribe();

    _isSyncing = false;
    _syncMutex = null;
    _syncCallbacks.clear();
  }

  void _listenToPowerMode() {
    PowerManagerService().modeStream.listen((mode) {
      debugPrint(
          "🔄 SyncService: Power mode changed to $mode. Adjusting interval...");
      _syncTimer?.cancel();

      Duration interval;
      switch (mode) {
        case PowerMode.active:
          interval =
              kIsWeb ? const Duration(seconds: 10) : const Duration(minutes: 1);
          break;
        case PowerMode.eco:
          interval = const Duration(minutes: 15);
          break;
        case PowerMode.deepSleep:
          interval = const Duration(minutes: 60); // Very rare sync
          break;
      }

      _syncTimer = Timer.periodic(interval, (_) => _attemptSync());
    });
  }

  /// Restarts the entire sync engine for a new user session.
  void restartSync([String? userId]) {
    _userId = userId;
    reset();
    startSyncLoop();
  }

  Future<void> fullSyncForUser(String userId) async {
    SecurityLogger.info("Starting EAGER FULL SYNC for user ID: $userId");
    await _withSyncMutex(() async {
      try {
        await patientHandler.pull();
        await systemHandler.pull();
        await vitalsHandler.pull();
        await chatHandler.pull(userId);
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
      patientHandler.subscribe((_) => patientHandler.pull());
      vitalsHandler.subscribe((_) => vitalsHandler.pull());
    }
  }

  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
    systemHandler.unsubscribeAll();
    patientHandler.unsubscribe();
    vitalsHandler.unsubscribe();
  }

  Future<void> triggerSync() => _attemptSync();

  Future<void> _attemptSync() async {
    if (_isSyncing) {
      return;
    }
    await _withSyncMutex(() async {
      // 1. Database Initialization (Skip on Web as it's not supported)
      // Initialize database locally first (Now supported on all platforms including Web)
      try {
        await DatabaseHelper.instance.database;
      } catch (e) {
        debugPrint("⚠️ SyncService: Local Database Init Failed: $e");
        // On non-Web, we might still want to proceed if it's just a transient error,
        // but usually DB failure is fatal for local persistence.
      }

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

      // Parallel Push: Only Admin pushes system tables
      await Future.wait([
        patientHandler.push(),
        vitalsHandler.push(),
        if (AppEnvironment().isDesktopAdmin) systemHandler.push(),
        chatHandler.push(),
        // Only push logs if we have a valid session (Proper fix for 42501 RLS noise)
        if (Supabase.instance.client.auth.currentSession != null)
          logHandler.push(),
      ]);

      // Parallel Pull
      final activeId = _getCurrentUserId();
      await Future.wait([
        patientHandler.pull(),
        vitalsHandler.pull(),
        systemHandler.pull(),
        chatHandler.pull(activeId),
      ]);

      await _cacheFilesInBackground();
      
      _lastSyncTime = DateTime.now();
      _syncStatusController.add(_lastSyncTime);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _cacheFilesInBackground() async {
    if (kIsWeb) return; // Browsers handle their own caching

    try {
      // Ensure DB is initialized
      await DatabaseHelper.instance.database;

      final db = await DatabaseHelper.instance.database;
      // Vitals Reports
      final List<Map<String, dynamic>> vr = await db.query('vitals',
          where: 'report_url IS NOT NULL AND report_path IS NULL');
      for (final row in vr) {
        final file =
            await FileStorageService().getCachedFile(row['report_url']);
        if (file != null) {
          await db.update('vitals', {'report_path': file.path},
              where: 'id = ?', whereArgs: [row['id']]);
        }
      }
      // Announcements
      final List<Map<String, dynamic>> ar = await db.query('announcements',
          where: 'media_url IS NOT NULL AND media_path IS NULL');
      for (final row in ar) {
        final file = await FileStorageService().getCachedFile(row['media_url']);
        if (file != null) {
          await db.update('announcements', {'media_path': file.path},
              where: 'id = ?', whereArgs: [row['id']]);
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
  Future<bool> deletePatient(String userId) =>
      patientHandler.deletePatient(userId);
  Future<List<User>> searchPatients(String query) =>
      patientHandler.searchPatients(query);
  Future<User?> authenticatePatient(String phone, String pin) =>
      patientHandler.authenticatePatient(phone, pin);
  Future<List<User>> fetchDependents(String parentId) =>
      patientHandler.fetchDependents(parentId);
  Future<List<Map<String, dynamic>>> findPatient(String name, String phone) =>
      patientHandler.findPatient(name, phone);

  // --- DELEGATION: VITALS ---
  Future<void> createVitalSign(VitalSigns vital) =>
      vitalsHandler.createVitalSign(vital);
  Future<void> updateVitalSign(VitalSigns vital) =>
      vitalsHandler.updateVitalSign(vital);
  Future<List<VitalSigns>> fetchPatientVitalsLocal(String userId) =>
      vitalsHandler.fetchPatientVitalsLocal(userId);
  Future<List<VitalSigns>> fetchPatientVitals(String userId) =>
      vitalsHandler.fetchPatientVitals(userId);
  Future<void> syncFamilyVitals(List<String> ids) =>
      vitalsHandler.syncFamilyVitals(ids);

  // --- DELEGATION: SYSTEM ---
  Future<void> pushAnnouncement(
          {required String id,
          required String title,
          required String content,
          required String targetGroup,
          required DateTime timestamp,
          required bool isActive,
          bool isArchived = false}) =>
      systemHandler.pushAnnouncement(
          id: id,
          title: title,
          content: content,
          targetGroup: targetGroup,
          timestamp: timestamp,
          isActive: isActive,
          isArchived: isArchived);

  Future<void> deleteAnnouncement(String id) =>
      systemHandler.deleteAnnouncement(id);

  Future<void> pushSchedule(
          {required String id,
          required String type,
          required DateTime date,
          required String location,
          required String assigned,
          required int colorValue}) =>
      systemHandler.pushSchedule(
          id: id,
          type: type,
          date: date,
          location: location,
          assigned: assigned,
          colorValue: colorValue);

  Future<void> deleteScheduleCloud(String id) =>
      systemHandler.deleteScheduleCloud(id);

  Future<void> pushAlert({
    required String id,
    required String message,
    required String targetGroup,
    required bool isEmergency,
    required DateTime timestamp,
    required bool isActive,
    String? targetUserId,
  }) =>
      systemHandler.pushAlert(
        id: id,
        message: message,
        targetGroup: targetGroup,
        isEmergency: isEmergency,
        timestamp: timestamp,
        isActive: isActive,
        targetUserId: targetUserId,
      );

  Future<void> deleteAlert(String id) => systemHandler.deleteAlert(id);

  Future<void> reactToAnnouncement(String id, String emoji, String userId) =>
      systemHandler.reactToAnnouncement(id, emoji, userId);

  Future<List<Map<String, dynamic>>> fetchAnnouncements(
      {dynamic currentUser}) async {
    await DatabaseHelper.instance.database;
    return systemHandler.fetchAnnouncements(currentUser: currentUser);
  }

  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    await DatabaseHelper.instance.database;
    return systemHandler.fetchAlerts(currentUser: currentUser);
  }

  Future<void> forceDownSyncAndRefresh(var authRepo, var historyRepo,
      {bool triggerStream = true}) async {
    await _withSyncMutex(() async {
      await Future.wait(
          [patientHandler.pull(), vitalsHandler.pull(), systemHandler.pull()]);
      if (authRepo != null) {
        await authRepo.refreshUsers();
      }
      if (historyRepo != null) {
        await historyRepo.loadAllHistory();
      }
    });
  }

  /// Resolves the current user ID by checking Supabase Native Auth
  /// and falling back to the local database session (for PWA compatibility).
  String? _getCurrentUserId() {
    // 2. Check Native Supabase Auth (Crucial for RLS identification)
    final nativeId = Supabase.instance.client.auth.currentUser?.id;
    if (nativeId != null) return nativeId;

    // 3. Explicitly set ID fallback
    if (_userId != null) return _userId;

    return null;
  }
}
