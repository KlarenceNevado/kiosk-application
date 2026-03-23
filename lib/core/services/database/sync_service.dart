import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../../features/auth/models/user_model.dart';
import '../../../features/health_check/models/vital_signs_model.dart';
import '../../../features/chat/models/chat_message.dart';
import 'database_helper.dart';
import 'connection_manager.dart';
import '../system/file_storage_service.dart';
import 'dart:math' as math;
import 'package:kiosk_application/core/services/security/security_logger.dart';

class SyncService with WidgetsBindingObserver {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal() {
    // Add lifecycle observer immediately on internal creation
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isSyncing = false;
  Completer<void>? _syncMutex; // Mutex to serialize sync calls

  // Lazy access — only call Supabase.instance.client when needed, not at construction time.
  SupabaseClient get supabase => Supabase.instance.client;

  // --- REAL-TIME BROADCASTS ---
  final _announcementChangeController = StreamController<void>.broadcast();
  Stream<void> get announcementStream => _announcementChangeController.stream;

  final _newAnnouncementController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newAnnouncementStream =>
      _newAnnouncementController.stream;

  final _newVitalController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newVitalStream => _newVitalController.stream;

  final _newAlertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newAlertStream => _newAlertController.stream;

  RealtimeChannel? _mobileAnnouncementsChannel;
  RealtimeChannel? _mobileAlertsChannel;
  RealtimeChannel? _mobileSchedulesChannel;
  RealtimeChannel? _patientsChannel;
  RealtimeChannel? _vitalsChannel;

  // STREAM CONTROLLERS
  final _scheduleChangeController = StreamController<void>.broadcast();
  Stream<void> get scheduleStream => _scheduleChangeController.stream;

  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  final _patientChangeController = StreamController<void>.broadcast();
  Stream<void> get patientStream => _patientChangeController.stream;

  final _vitalsChangeController = StreamController<void>.broadcast();
  Stream<void> get vitalsStream => _vitalsChangeController.stream;
  // --- NEW: CALLBACKS FOR BACKGROUND SWEEPING ---
  final List<Future<void> Function()> _syncCallbacks = [];

  void registerSyncCallback(Future<void> Function() callback) {
    if (!_syncCallbacks.contains(callback)) {
      _syncCallbacks.add(callback);
    }
  }

  void startSyncLoop() {
    debugPrint("🔄 SyncService: Starting sync loop and real-time listeners...");
    
    // 0. Immediate Sync on Startup
    _attemptSync();

    // 1. Periodic check & Heartbeat
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      debugPrint("🕒 SyncService: Heartbeat and periodic sync starting...");
      await _attemptSync();

      // Check Realtime health - only re-subscribe if needed (e.g. status is not joined)
      _checkAndRestoreSubscribers();
    });

    // 2. Initial Cloud Subscriptions
    _subscribeToCloudAnnouncements();
    _subscribeToCloudAlerts();
    _subscribeToCloudSchedules();
    _subscribeToCloudPatients();
    _subscribeToCloudVitals();

    // 3. Reactive check on network change — Use ConnectionManager
    ConnectionManager().statusStream.listen((status) {
      if (status == ConnectionStatus.online) {
        debugPrint("🌐 SyncService: Network restored. Attempting recovery sync...");
        _attemptSync();
        _checkAndRestoreSubscribers(force: true);
      }
    });

    debugPrint("ℹ️ SyncService: Connectivity monitoring delegated to ConnectionManager.");
  }

  /// NEW: Eager Full Sync for a specific user (Mobile App requirement)
  /// Pulls all relevant data for offline availability immediately.
  Future<void> fullSyncForUser(String userId) async {
    SecurityLogger.info("Starting EAGER FULL SYNC for user ID: $userId");
    await _withSyncMutex(() async {
      try {
        // 1. Pulldown Patients (all, including dependents)
        await _syncDownPatients(useMutex: false);
        
        // 2. Fetch all unique patient IDs involved (family/dependents)
        final db = await DatabaseHelper.instance.database;
        final familyData = await db.query('patients');
        final List<String> familyIds = familyData.map((e) => e['id'] as String).toList();
        
        // 3. Pulldown Family Vitals
        if (familyIds.isNotEmpty) {
          await syncFamilyVitals(familyIds);
        }
        
        // 4. Pulldown Announcements
        await _syncDownAnnouncements(useMutex: false);
        
        // 5. Pulldown Alerts
        await _syncDownAlerts(useMutex: false);
        
        // 6. Pulldown Schedules
        await _syncDownSchedules(useMutex: false);
        
        debugPrint("✅ SyncService: Eager Full Sync Complete.");
      } catch (e) {
        debugPrint("❌ SyncService: Full Sync Error: $e");
      }
    });
  }

  void _subscribeToCloudAnnouncements() {
    _subscribeWithRetry(
      channelName: 'public:announcements_mobile',
      tableName: 'announcements',
      onData: (payload) async {
        debugPrint("☁️ Real-time Cloud Change: Announcements");
        await _syncDownAnnouncements(useMutex: true);
      },
      setChannel: (ch) => _mobileAnnouncementsChannel = ch,
    );
  }

  void _subscribeToCloudAlerts() {
    _subscribeWithRetry(
      channelName: 'public:alerts_mobile',
      tableName: 'alerts',
      onData: (payload) async {
        debugPrint("☁️ Real-time Cloud Change: Alerts");
        await _syncDownAlerts(useMutex: true);
        if (payload.newRecord.isNotEmpty) {
          _alertController.add(payload.newRecord);
        }
      },
      setChannel: (ch) => _mobileAlertsChannel = ch,
    );
  }

  void _subscribeToCloudSchedules() {
    _subscribeWithRetry(
      channelName: 'public:schedules_mobile',
      tableName: 'schedules',
      onData: (payload) async {
        debugPrint("☁️ Real-time Cloud Change: Schedules");
        await _syncDownSchedules(useMutex: true);
        _scheduleChangeController.add(null);
      },
      setChannel: (ch) => _mobileSchedulesChannel = ch,
    );
  }

  void _subscribeToCloudPatients() {
    _subscribeWithRetry(
      channelName: 'public:patients_realtime',
      tableName: 'patients',
      onData: (payload) async {
        debugPrint("☁️ Real-time Cloud Change: Patients");
        await _syncDownPatients(useMutex: true);
        _patientChangeController.add(null);
      },
      setChannel: (ch) => _patientsChannel = ch,
    );
  }

  void _subscribeToCloudVitals() {
    _subscribeWithRetry(
      channelName: 'public:vitals_realtime',
      tableName: 'vitals',
      onData: (payload) async {
        debugPrint("☁️ Real-time Cloud Change: Vitals");
        await _syncDownVitals(useMutex: true);
        _vitalsChangeController.add(null);
      },
      setChannel: (ch) => _vitalsChannel = ch,
    );
  }

  // --- RESILIENCE HELPER WITH EXPONENTIAL BACKOFF ---
  void _subscribeWithRetry({
    required String channelName,
    required String tableName,
    required void Function(PostgresChangePayload payload) onData,
    required Function(RealtimeChannel?) setChannel,
    int attempt = 0,
  }) {
    // Safety: Unsubscribe old channel before creating a new one
    _safeUnsubscribe(tableName);

    if (ConnectionManager().currentStatus == ConnectionStatus.offline) {
      debugPrint("📡 Realtime ($tableName): Offline. Deferring subscription...");
      return;
    }

    try {
      final client = Supabase.instance.client;
      final channel = client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: tableName,
            callback: onData,
          )
          .subscribe((status, [error]) {
        debugPrint("📡 Realtime ($tableName): Status is $status");

        if (status == RealtimeSubscribeStatus.channelError || 
            status == RealtimeSubscribeStatus.closed) {
          
          if (error != null) {
            debugPrint("❌ Realtime Error ($tableName): $error");
            
            // Exponential Backoff Strategy
            final nextAttempt = attempt + 1;
            // Delay: 2^attempt * 2 seconds, capped at 60 seconds
            final delaySeconds = math.min(math.pow(2, attempt) * 2, 60.0).toDouble();
            
            debugPrint("🔄 Realtime ($tableName): Retrying in ${delaySeconds.toInt()}s (Attempt $nextAttempt)...");
            
            Future.delayed(Duration(seconds: delaySeconds.toInt()), () {
              // Ensure we are still relevant (avoid multiple parallel retry loops)
              _subscribeWithRetry(
                channelName: channelName,
                tableName: tableName,
                onData: onData,
                setChannel: setChannel,
                attempt: nextAttempt,
              );
            });
          }
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          // Reset attempts on successful connection
          debugPrint("✅ Realtime ($tableName): Subscribed successfully.");
        }
      });
      
      setChannel(channel);
    } catch (e) {
      debugPrint("❌ Realtime Setup Fail ($tableName): $e");
    }
  }

  // Helper to safely unsubscribe old channels
  void _safeUnsubscribe(String tableName) {
    if (tableName == 'announcements') {
      _mobileAnnouncementsChannel?.unsubscribe();
      _mobileAnnouncementsChannel = null;
    } else if (tableName == 'alerts') {
      _mobileAlertsChannel?.unsubscribe();
      _mobileAlertsChannel = null;
    } else if (tableName == 'schedules') {
      _mobileSchedulesChannel?.unsubscribe();
      _mobileSchedulesChannel = null;
    } else if (tableName == 'patients') {
      _patientsChannel?.unsubscribe();
      _patientsChannel = null;
    } else if (tableName == 'vitals') {
      _vitalsChannel?.unsubscribe();
      _vitalsChannel = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("🌅 App Resumed/Woken Up. Triggering rapid sync refresh...");
      _attemptSync();
      // Only re-subscribe if needed, or force a reset to clear "zombie" connections
      _subscribeToCloudAnnouncements();
      _subscribeToCloudAlerts();
      _subscribeToCloudSchedules();
      _subscribeToCloudPatients();
      _subscribeToCloudVitals();
    }
  }

  void stopListening() {
    debugPrint("🛑 SyncService: Stopping all real-time listeners...");
    WidgetsBinding.instance.removeObserver(this);
    _mobileAnnouncementsChannel?.unsubscribe();
    _mobileAnnouncementsChannel = null;
    _mobileAlertsChannel?.unsubscribe();
    _mobileAlertsChannel = null;
    _mobileSchedulesChannel?.unsubscribe();
    _mobileSchedulesChannel = null;
    _patientsChannel?.unsubscribe();
    _patientsChannel = null;
    _vitalsChannel?.unsubscribe();
    _vitalsChannel = null;
  }

  /// NEW: Intelligent reconnection — only re-subscribes if the connection is dead/missing.
  /// This prevents redundant network chatter every 5 minutes while maintaining reliability.
  void _checkAndRestoreSubscribers({bool force = false}) {
    if (ConnectionManager().currentStatus == ConnectionStatus.offline) return;
    
    debugPrint("🔍 SyncService: Auditing Realtime health...");

    if (force || _mobileAnnouncementsChannel == null) {
      debugPrint("♻️ Restoring Announcements Channel...");
      _subscribeToCloudAnnouncements();
    }
    if (force || _mobileAlertsChannel == null) {
      debugPrint("♻️ Restoring Alerts Channel...");
      _subscribeToCloudAlerts();
    }
    if (force || _mobileSchedulesChannel == null) {
      debugPrint("♻️ Restoring Schedules Channel...");
      _subscribeToCloudSchedules();
    }
    if (force || _patientsChannel == null) {
      debugPrint("♻️ Restoring Patients Channel...");
      _subscribeToCloudPatients();
    }
    if (force || _vitalsChannel == null) {
      debugPrint("♻️ Restoring Vitals Channel...");
      _subscribeToCloudVitals();
    }
  }

  // --- DELTA-SYNC HELPERS ---
  Future<String?> _getLastSync(String table) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_$table');
  }

  Future<void> _updateLastSync(String table, String? timestamp) async {
    if (timestamp == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$table', timestamp);
  }

  void triggerSync() {
    debugPrint("🚀 SyncService: Manual sync trigger received.");
    _attemptSync();
  }

  Future<void> _attemptSync() async {
    if (_isSyncing) return;

    // Safety check: Don't sync if configuration is missing or invalid
    try {
      Supabase.instance.client;
      // We'll trust our hardcoded fallbacks in main_kiosk.dart
    } catch (_) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    await _withSyncMutex(() async {
      if (ConnectionManager().currentStatus != ConnectionStatus.online) {
        debugPrint("📡 SyncService: Offline. Skipping sync attempt.");
        return;
      }

      debugPrint("📡 [System Dataset] Starting Sync Operation...");
      try {
        await _syncPendingRecords(); // Sync local -> cloud
        
        // Final Sync Telemetry for operational stability analysis
        stopwatch.stop();
        debugPrint("📊 [System Dataset] Sync Latency: ${stopwatch.elapsedMilliseconds}ms | Status: SUCCESS");
      } catch (e) {
        stopwatch.stop();
        debugPrint("📊 [System Dataset] Sync Retry Latency: ${stopwatch.elapsedMilliseconds}ms | Status: FAILED (Retry Scheduled)");
      }
    });
  }

  Future<void> _syncPendingRecords() async {
    _isSyncing = true;

    try {
      debugPrint("🔄 Syncing pending offline records to Supabase...");

      // 1. Sweep Registered Callbacks
      for (final callback in _syncCallbacks) {
        await callback();
      }

      // 2. Parallel Upward Sync (Local -> Cloud)
      await Future.wait([
        _syncPatients().catchError((e) => debugPrint("Patients Up fail: $e")),
        _syncAnnouncements().catchError((e) => debugPrint("Announcements Up fail: $e")),
        _syncAlerts().catchError((e) => debugPrint("Alerts Up fail: $e")),
        _syncSchedules().catchError((e) => debugPrint("Schedules Up fail: $e")),
        _syncVitals().catchError((e) => debugPrint("Vitals Up fail: $e")),
        _syncChatMessages().catchError((e) => debugPrint("Chat Up fail: $e")),
      ]);

      // 3. Downward Sync (Cloud -> Local)
      await Future.wait([
        _syncDownPatients(useMutex: false).catchError((e) => debugPrint("Patients Down Fail: $e")),
        _syncDownVitals(useMutex: false).catchError((e) => debugPrint("Vitals Down Fail: $e")),
        _syncDownAlerts(useMutex: false).catchError((e) => debugPrint("Alerts Down Fail: $e")),
        _syncDownSchedules(useMutex: false).catchError((e) => debugPrint("Schedules Down Fail: $e")),
        _syncDownAnnouncements(useMutex: false).catchError((e) => debugPrint("Announcements Down Fail: $e")),
      ]);

      // 4. Background File Caching
      await _cacheFilesInBackground();
    } catch (e) {
      debugPrint("❌ Sync Loop Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _cacheFilesInBackground() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Cache Report PDFs
      final List<Map<String, dynamic>> vitalsWithUrl = await db.query(
        'vitals',
        where: 'report_url IS NOT NULL AND report_path IS NULL',
      );
      for (final row in vitalsWithUrl) {
        final file = await FileStorageService().getCachedFile(row['report_url']);
        if (file != null) {
          await db.update('vitals', {'report_path': file.path},
              where: 'id = ?', whereArgs: [row['id']]);
        }
      }

      // 2. Cache Announcement Media
      final List<Map<String, dynamic>> announcementsWithUrl = await db.query(
        'announcements',
        where: 'media_url IS NOT NULL AND media_path IS NULL',
      );
      for (final row in announcementsWithUrl) {
        final file = await FileStorageService().getCachedFile(row['media_url']);
        if (file != null) {
          await db.update('announcements', {'media_path': file.path},
              where: 'id = ?', whereArgs: [row['id']]);
        }
      }

      // 3. Cache Chat Media
      final List<Map<String, dynamic>> chatsWithUrl = await db.query(
        'chat_messages',
        where: 'media_url IS NOT NULL AND media_path IS NULL',
      );
      for (final row in chatsWithUrl) {
        final file = await FileStorageService().getCachedFile(row['media_url']);
        if (file != null) {
          await db.update('chat_messages', {'media_path': file.path},
              where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Background Caching Error: $e");
    }
  }

  Future<void> _syncPatients() async {
    try {
      final blockedIds = await DatabaseHelper.instance.getBlockedRecords('patients');
      final unsynced = await DatabaseHelper.instance.getUnsyncedPatients();
      if (unsynced.isEmpty) return;

      final List<String> syncedIds = [];
      for (final user in unsynced) {
        if (blockedIds.contains(user.id)) {
          debugPrint("🚫 SyncService: Skipping blocked patient ${user.id}");
          continue;
        }

        try {
          final updatedUser = await createPatient(user);
          if (updatedUser != null && updatedUser.isSynced) {
            syncedIds.add(updatedUser.id);
            await DatabaseHelper.instance.clearSyncMetadata('patients', updatedUser.id);
          } else {
            await DatabaseHelper.instance.updateSyncMetadata(
              tableName: 'patients',
              recordId: user.id,
              error: 'Push failed',
              incrementRetry: true,
            );
            final meta = await DatabaseHelper.instance.getSyncMetadata('patients', user.id);
            if ((meta?['retry_count'] ?? 0) >= 5) {
              await DatabaseHelper.instance.updateSyncMetadata(tableName: 'patients', recordId: user.id, block: true);
            }
          }
        } catch (e) {
          await DatabaseHelper.instance.updateSyncMetadata(
            tableName: 'patients',
            recordId: user.id,
            error: e.toString(),
            incrementRetry: true,
          );
        }
      }

      if (syncedIds.isNotEmpty) {
        await DatabaseHelper.instance.markBatchAsSynced('patients', syncedIds);
        _patientChangeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ _syncPatients Error: $e");
    }
  }

  Future<void> _syncVitals() async {
    try {
      final blockedIds = await DatabaseHelper.instance.getBlockedRecords('vitals');
      final unsyncedVitals = await DatabaseHelper.instance.getUnsyncedRecords();
      if (unsyncedVitals.isEmpty) return;

      // Parallelize individual record pushes
      final results = await Future.wait(unsyncedVitals.map((vital) async {
        if (blockedIds.contains(vital.id)) return null;

        try {
          final success = await _upsertVitalSign(vital);
          if (success) {
            await DatabaseHelper.instance.clearSyncMetadata('vitals', vital.id);
            return vital.id;
          } else {
            await DatabaseHelper.instance.updateSyncMetadata(
              tableName: 'vitals',
              recordId: vital.id,
              error: 'Push failed',
              incrementRetry: true,
            );
            final meta = await DatabaseHelper.instance.getSyncMetadata('vitals', vital.id);
            if ((meta?['retry_count'] ?? 0) >= 5) {
              await DatabaseHelper.instance.updateSyncMetadata(tableName: 'vitals', recordId: vital.id, block: true);
            }
            return null;
          }
        } catch (e) {
           await DatabaseHelper.instance.updateSyncMetadata(tableName: 'vitals', recordId: vital.id, error: e.toString(), incrementRetry: true);
           return null;
        }
      }));

      final syncedIds = results.whereType<String>().toList();
      if (syncedIds.isNotEmpty) {
        await DatabaseHelper.instance.markBatchAsSynced('vitals', syncedIds);
        _vitalsChangeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ _syncVitals Error: $e");
    }
  }

  Future<void> _syncAnnouncements() async {
    try {
      final blockedIds = await DatabaseHelper.instance.getBlockedRecords('announcements');
      final unsynced = await DatabaseHelper.instance.getUnsyncedAnnouncements();
      if (unsynced.isEmpty) return;

      final List<String> syncedIds = [];
      for (final row in unsynced) {
        if (blockedIds.contains(row['id'])) continue;

        try {
          await supabase.from('announcements').upsert({
            'id': row['id'],
            'title': row['title'],
            'content': row['content'],
            'target_group': row['targetGroup'],
            'timestamp': row['timestamp'],
            'is_active': row['isActive'] == 1,
            'is_deleted': row['is_deleted'] == 1,
            'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
          });
          syncedIds.add(row['id'] as String);
          await DatabaseHelper.instance.clearSyncMetadata('announcements', row['id']);
        } catch (e) {
          await DatabaseHelper.instance.updateSyncMetadata(
            tableName: 'announcements',
            recordId: row['id'],
            error: e.toString(),
            incrementRetry: true,
          );
          final meta = await DatabaseHelper.instance.getSyncMetadata('announcements', row['id']);
          if ((meta?['retry_count'] ?? 0) >= 5) {
            await DatabaseHelper.instance.updateSyncMetadata(tableName: 'announcements', recordId: row['id'], block: true);
          }
        }
      }

      if (syncedIds.isNotEmpty) {
        await DatabaseHelper.instance.markBatchAsSynced('announcements', syncedIds);
        _announcementChangeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ _syncAnnouncements Error: $e");
    }
  }

  Future<void> _syncAlerts() async {
    try {
      final blockedIds = await DatabaseHelper.instance.getBlockedRecords('alerts');
      final unsynced = await DatabaseHelper.instance.getUnsyncedAlerts();
      if (unsynced.isEmpty) return;

      final List<String> syncedIds = [];
      for (final row in unsynced) {
        if (blockedIds.contains(row['id'])) continue;

        try {
          await supabase.from('alerts').upsert({
            'id': row['id'],
            'message': row['message'],
            'target_group': row['targetGroup'],
            'is_emergency': row['isEmergency'] == 1,
            'timestamp': row['timestamp'],
            'is_deleted': row['is_deleted'] == 1,
            'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
          });
          syncedIds.add(row['id'] as String);
          await DatabaseHelper.instance.clearSyncMetadata('alerts', row['id']);
        } catch (e) {
          await DatabaseHelper.instance.updateSyncMetadata(
            tableName: 'alerts',
            recordId: row['id'],
            error: e.toString(),
            incrementRetry: true,
          );
          final meta = await DatabaseHelper.instance.getSyncMetadata('alerts', row['id']);
          if ((meta?['retry_count'] ?? 0) >= 5) {
            await DatabaseHelper.instance.updateSyncMetadata(tableName: 'alerts', recordId: row['id'], block: true);
          }
        }
      }

      if (syncedIds.isNotEmpty) {
        await DatabaseHelper.instance.markBatchAsSynced('alerts', syncedIds);
        _alertController.add({'type': 'sync'});
      }
    } catch (e) {
      debugPrint("❌ _syncAlerts Error: $e");
    }
  }

  Future<void> _syncSchedules() async {
    try {
      final blockedIds = await DatabaseHelper.instance.getBlockedRecords('schedules');
      final unsynced = await DatabaseHelper.instance.getUnsyncedSchedules();
      if (unsynced.isEmpty) return;

      final List<String> syncedIds = [];
      for (final row in unsynced) {
        if (blockedIds.contains(row['id'])) continue;

        try {
          await supabase.from('schedules').upsert({
            'id': row['id'],
            'type': row['type'],
            'date': row['date'],
            'location': row['location'],
            'assigned': row['assigned'],
            'color_value': row['colorValue'],
            'is_deleted': row['is_deleted'] == 1,
            'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
          });
          syncedIds.add(row['id'] as String);
          await DatabaseHelper.instance.clearSyncMetadata('schedules', row['id']);
        } catch (e) {
          await DatabaseHelper.instance.updateSyncMetadata(
            tableName: 'schedules',
            recordId: row['id'],
            error: e.toString(),
            incrementRetry: true,
          );
          final meta = await DatabaseHelper.instance.getSyncMetadata('schedules', row['id']);
          if ((meta?['retry_count'] ?? 0) >= 5) {
            await DatabaseHelper.instance.updateSyncMetadata(tableName: 'schedules', recordId: row['id'], block: true);
          }
        }
      }

      if (syncedIds.isNotEmpty) {
        await DatabaseHelper.instance.markBatchAsSynced('schedules', syncedIds);
        _scheduleChangeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ _syncSchedules Error: $e");
    }
  }

  Future<void> _syncChatMessages() async {
    try {
      final blockedIds = await DatabaseHelper.instance.getBlockedRecords('chat_messages');
      final unsynced = await DatabaseHelper.instance.getUnsyncedChatMessages();
      if (unsynced.isEmpty) return;

      final List<String> syncedIds = [];
      for (final row in unsynced) {
        if (blockedIds.contains(row['id'])) continue;

        try {
          final reactionsRaw = row['reactions'];
          Map<String, dynamic> reactions = {};
          if (reactionsRaw is String) {
            try {
              reactions = jsonDecode(reactionsRaw);
            } catch (_) {}
          } else if (reactionsRaw is Map) {
            reactions = Map<String, dynamic>.from(reactionsRaw);
          }

          final ChatMessage message = ChatMessage.fromMap({...row, 'reactions': reactions});
          debugPrint("🚀 Syncing Chat Message to Cloud: ID=${message.id}, SenderID=${message.senderId}, ReceiverID=${message.receiverId}");
          
          // E2EE: Encrypt message content before pushing to Supabase
          final Map<String, dynamic> supabaseData = message.toSupabaseMap();
          supabaseData['content'] = DatabaseHelper.instance.encrypt(message.content);
          supabaseData['message'] = supabaseData['content']; // Redundant column support
          
          await supabase.from('chat_messages').upsert(supabaseData);
          syncedIds.add(row['id'] as String);
          await DatabaseHelper.instance.clearSyncMetadata('chat_messages', row['id']);
          debugPrint("✅ Background Sync: Chat message pushed.");
        } catch (e) {
          await DatabaseHelper.instance.updateSyncMetadata(
            tableName: 'chat_messages',
            recordId: row['id'],
            error: e.toString(),
            incrementRetry: true,
          );
          final meta = await DatabaseHelper.instance.getSyncMetadata('chat_messages', row['id']);
          if ((meta?['retry_count'] ?? 0) >= 5) {
            await DatabaseHelper.instance.updateSyncMetadata(tableName: 'chat_messages', recordId: row['id'], block: true);
          }
        }
      }

      if (syncedIds.isNotEmpty) {
        await DatabaseHelper.instance.markBatchAsSynced('chat_messages', syncedIds);
      }
    } catch (e) {
      debugPrint("❌ _syncChatMessages Error: $e");
    }
  }

  // A more robust mutex pattern: ensure only one "write" operation runs at a time.
  Future<T> _withSyncMutex<T>(Future<T> Function() action) async {
    while (_syncMutex != null) {
      debugPrint("⏳ Sync Mutex: Waiting for current operation to finish...");
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

  // Callable from UI to force a download and immediately reload the interface
  Future<void> forceDownSyncAndRefresh(var authRepo, var historyRepo,
      {bool triggerStream = true}) async {
    await _withSyncMutex(() async {
      _isSyncing = true;
      debugPrint("🔄 Triggering forced manual downward sync from Cloud...");

      try {
        await _syncDownPatients(useMutex: false)
            .catchError((e) => debugPrint("❌ Sync Patients Fail: $e"));

        if (authRepo != null) {
          await authRepo.refreshUsers();
        }

        await _syncDownVitals(useMutex: false)
            .catchError((e) => debugPrint("❌ Sync Vitals Fail: $e"));
        if (historyRepo != null) {
          await historyRepo.loadAllHistory();
        }

        await _syncDownAnnouncements(
                triggerStream: triggerStream, useMutex: false)
            .catchError((e) => debugPrint("❌ Sync Announcements Fail: $e"));

        await _syncDownAlerts(useMutex: false)
            .catchError((e) => debugPrint("❌ Sync Alerts Fail: $e"));

        await _syncDownSchedules(useMutex: false)
            .catchError((e) => debugPrint("❌ Sync Schedules Fail: $e"));

        debugPrint("✅ Forced sync complete.");
      } catch (e) {
        debugPrint("❌ Forced sync crashed: $e");
      } finally {
        _isSyncing = false;
      }
    });
  }

  // --- DOWNWARD SYNC MECHANICS ---
  Future<void> _syncDownPatients({bool useMutex = true}) async {
    if (useMutex) {
      return await _withSyncMutex(() => _syncDownPatients(useMutex: false));
    }
    try {
      final lastSync = await _getLastSync('patients');
      var query = supabase.from('patients').select();

      if (lastSync != null) {
        // Add 5-minute overlap to handle clock skew/jitters
        final overlapTime = DateTime.parse(lastSync).subtract(const Duration(minutes: 5));
        query = query.gt('updated_at', overlapTime.toIso8601String());
      }

      final cloudPatients = await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      if (cloudPatients.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final batch = db.batch();

        for (var row in cloudPatients) {
          final preparedRow = _prepareRowForSqlite(row);
          batch.insert('patients', preparedRow,
              conflictAlgorithm: ConflictAlgorithm.replace);
          latestTimestamp = row['updated_at'];
        }

        await batch.commit(noResult: true);
      }

      if (latestTimestamp != null) {
        await _updateLastSync('patients', latestTimestamp);
        _patientChangeController.add(null);
      }

      debugPrint(
          "⬇️ Delta-Sync: Processed ${cloudPatients.length} Patients from Cloud.");
    } catch (e) {
      debugPrint("Patient Download Error: $e");
    }
  }

  Future<void> _syncDownVitals({bool useMutex = true}) async {
    if (useMutex) {
      return await _withSyncMutex(() => _syncDownVitals(useMutex: false));
    }
    try {
      final lastSync = await _getLastSync('vitals');
      var query = supabase.from('vitals').select(
          'id, user_id, timestamp, heart_rate, systolic_bp, diastolic_bp, oxygen, temperature, bmi, bmi_category, status, remarks, follow_up_action, updated_at, is_deleted');

      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudVitals = await query.order('updated_at', ascending: true);
      String? latestTimestamp;
      bool anyNewVitals = false;
      Map<String, dynamic>? latestNew;

      if (cloudVitals.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final batch = db.batch();

        for (var row in cloudVitals) {
          // Check if NEW for notification
          final exists = await DatabaseHelper.instance.getVitalSignById(row['id']);
          if (exists == null) {
            anyNewVitals = true;
            latestNew = row;
          }
          final vitalMap = {
            'id': row['id'],
            'user_id': row['user_id'],
            'timestamp': row['timestamp'],
            // Data from cloud is ALREADY encrypted. Pass raw to avoid double-encryption.
            'heart_rate': row['heart_rate'],
            'systolic_bp': row['systolic_bp'],
            'diastolic_bp': row['diastolic_bp'],
            'oxygen': row['oxygen'],
            'temperature': row['temperature'],
            'bmi': row['bmi'],
            'bmi_category': row['bmi_category'],
            'status': row['status'],
            'remarks': row['remarks'],
            'follow_up_action': row['follow_up_action'],
            'updated_at': row['updated_at'],
            'is_deleted': row['is_deleted'] == true ? 1 : 0,
            'is_synced': 1
          };

          batch.insert('vitals', vitalMap,
              conflictAlgorithm: ConflictAlgorithm.replace);
          latestTimestamp = row['updated_at'];
        }
        await batch.commit(noResult: true);
      }

      if (latestTimestamp != null) {
        await _updateLastSync('vitals', latestTimestamp);
        _vitalsChangeController.add(null);
        if (anyNewVitals && latestNew != null) {
          _newVitalController.add(latestNew);
        }
      }

      debugPrint(
          "⬇️ Delta-Sync: Mirrored ${cloudVitals.length} Vitals into local storage.");
    } catch (e) {
      debugPrint("Vitals Download Error: $e");
    }
  }

  Future<void> _syncDownAlerts({bool useMutex = true}) async {
    if (useMutex) {
      return await _withSyncMutex(() => _syncDownAlerts(useMutex: false));
    }
    try {
      final lastSync = await _getLastSync('alerts');
      var query = supabase.from('alerts').select(
          'id, message, target_group, is_emergency, timestamp, updated_at, is_deleted');

      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudAlerts = await query.order('updated_at', ascending: true);
      String? latestTimestamp;
      bool anyNewAlerts = false;
      Map<String, dynamic>? latestNew;

      for (var row in cloudAlerts) {
        // Check if NEW for notification
        final exists = await DatabaseHelper.instance.getAlertById(row['id']);
        if (exists == null) {
          anyNewAlerts = true;
          latestNew = row;
        }

        await DatabaseHelper.instance.insertAlert({
          'id': row['id'],
          'message': row['message'],
          'target_group': row['target_group'],
          'is_emergency':
              (row['is_emergency'] == true || row['is_emergency'] == 1) ? 1 : 0,
          'timestamp': row['timestamp'],
          'updated_at': row['updated_at'],
          'is_deleted': row['is_deleted'] == true ? 1 : 0,
          'is_synced': 1,
        });
        latestTimestamp = row['updated_at'];
      }

      if (latestTimestamp != null) {
        await _updateLastSync('alerts', latestTimestamp);
        _alertController.add({'type': 'sync'}); // Notify listeners of new cloud data
        if (anyNewAlerts && latestNew != null) {
          _newAlertController.add(latestNew);
        }
      }

      debugPrint(
          "⬇️ Delta-Sync: Mirrored ${cloudAlerts.length} Alerts into Local Database.");
    } catch (e) {
      debugPrint("Alerts Download Error: $e");
    }
  }

  Future<void> _syncDownSchedules({bool useMutex = true}) async {
    if (useMutex) {
      return await _withSyncMutex(() => _syncDownSchedules(useMutex: false));
    }
    try {
      final lastSync = await _getLastSync('schedules');
      var query = supabase.from('schedules').select(
          'id, type, date, location, assigned, color_value, updated_at, is_deleted');

      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudSchedules = await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      for (var row in cloudSchedules) {
        await DatabaseHelper.instance.insertSchedule({
          'id': row['id'],
          'type': row['type'],
          'date': row['date'],
          'location': row['location'],
          'assigned': row['assigned'] ?? 'Unassigned',
          'color_value': row['color_value'] ?? 0xFF000000,
          'updated_at': row['updated_at'],
          'is_deleted': row['is_deleted'] == true ? 1 : 0,
          'is_synced': 1,
        });
        latestTimestamp = row['updated_at'];
      }

      if (latestTimestamp != null) {
        await _updateLastSync('schedules', latestTimestamp);
        _scheduleChangeController.add(null); // Notify listeners of new cloud data
      }

      debugPrint(
          "⬇️ Delta-Sync: Mirrored ${cloudSchedules.length} Schedules into Local Database.");
    } catch (e) {
      if (e.toString().contains('PGRST205')) {
        debugPrint(
            "⚠️ Schedules table missing in Supabase. Skipping sync until created.");
      } else {
        debugPrint("Schedules Download Error: $e");
      }
    }
  }

  Future<void> _syncDownAnnouncements(
      {bool triggerStream = true, bool useMutex = true}) async {
    if (useMutex) {
      return await _withSyncMutex(() => _syncDownAnnouncements(
          triggerStream: triggerStream, useMutex: false));
    }
    bool anyNewAnnouncement = false;
    bool anyUpdate = false;
    Map<String, dynamic>? latestNew;

    try {
      final lastSync = await _getLastSync('announcements');
      var query = supabase.from('announcements').select(
          'id, title, content, target_group, timestamp, is_active, reactions, updated_at, is_deleted');

      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudAnnouncements =
          await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      for (var row in cloudAnnouncements) {
        final id = row['id'];
        final bool isActiveInCloud =
            row['is_active'] == true || row['is_active'] == 1;
        final bool isDeletedInCloud =
            row['is_deleted'] == true || row['is_deleted'] == 1;

        // Check if it's NEW before inserting
        final exists = await DatabaseHelper.instance.getAnnouncementById(id);
        if (exists == null && !isDeletedInCloud) {
          anyNewAnnouncement = true;
          latestNew = row;
        } else if (exists != null && !isDeletedInCloud) {
          anyUpdate = true;
        }

        await DatabaseHelper.instance.insertAnnouncement({
          'id': id,
          'title': row['title'] ?? 'No Title',
          'content': row['content'] ?? '',
          'target_group': row['target_group'] ?? 'all',
          'timestamp': row['timestamp'] ?? DateTime.now().toIso8601String(),
          'isActive': isActiveInCloud ? 1 : 0, // Preserve archived state
          'updated_at': row['updated_at'],
          'is_deleted': isDeletedInCloud ? 1 : 0,
          'is_synced': 1,
          'reactions':
              row['reactions'] != null ? json.encode(row['reactions']) : null,
        });
        latestTimestamp = row['updated_at'];
      }

      if (latestTimestamp != null) {
        await _updateLastSync('announcements', latestTimestamp);
      }

      debugPrint(
          "⬇️ Delta-Sync: Processed ${cloudAnnouncements.length} cloud announcements.");
    } catch (e) {
      debugPrint("❌ Announcements Sync Error: $e");
    } finally {
      if (triggerStream &&
          (anyNewAnnouncement || anyUpdate || latestNew != null)) {
        debugPrint("🔔 SyncService: Broadcasting announcement change to UI.");
        _announcementChangeController.add(null);
        if (anyNewAnnouncement && latestNew != null) {
          _newAnnouncementController.add(latestNew);
        }
      }
    }
  }

  // UPSERT Helper for Vitals Cloud Push
  Future<bool> _upsertVitalSign(VitalSigns vital) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final Map<String, dynamic> supabaseData = {
        'id': vital.id,
        'user_id': vital.userId,
        'timestamp': vital.timestamp.toIso8601String(),
        // Encrypt sensitive metrics with community-aligned secure key
        'heart_rate': dbHelper.encrypt(vital.heartRate),
        'systolic_bp': dbHelper.encrypt(vital.systolicBP),
        'diastolic_bp': dbHelper.encrypt(vital.diastolicBP),
        'oxygen': dbHelper.encrypt(vital.oxygen),
        'temperature': dbHelper.encrypt(vital.temperature),
        'bmi': vital.bmi,
        'status': vital.status,
        'remarks': vital.remarks,
      };
      await supabase.from('vitals').upsert(supabaseData);
      return true;
    } catch (e) {
      debugPrint("❌ Cloud Vitals Push Fail: $e");
      return false;
    }
  }

  Future<User?> createPatient(User user) async {
    final dbHelper = DatabaseHelper.instance;
    // Map dart camelCase to Supabase SQL snake_case
    final Map<String, dynamic> supabaseData = {
      'id': user.id,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'middle_initial': user.middleInitial,
      'sitio': user.sitio,
      'phone_number': dbHelper.encrypt(user.phoneNumber), // E2EE: Phone Number
      'pin_code': dbHelper.encrypt(user.pinCode), // E2EE Sync: PIN for Mobile Auth
      'date_of_birth': user.dateOfBirth.toIso8601String(),
      'gender': user.gender,
      'parent_id': user.parentId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      SecurityLogger.info("Pushing patient to Supabase", pii: user.fullName);
      await supabase.from('patients').upsert(supabaseData);

      final syncedUser = user.copyWith(
        isSynced: true,
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertPatient(syncedUser);
      SecurityLogger.info("Patient synced successfully", pii: user.fullName);
      return syncedUser;
    } catch (e) {
      SecurityLogger.error("Supabase push failed for patient", error: e);
      debugPrint("📦 Data attempted: $supabaseData");

      // Check for specific error hints
      if (e.toString().contains('403')) {
        debugPrint(
            "⚠️ Permission/RLS Denied. Check Supabase 'patients' table policies.");
      }

      final offlineUser = user.copyWith(isSynced: false);
      await DatabaseHelper.instance.insertPatient(offlineUser);
      return offlineUser;
    }
  }

  Future<bool> updatePatient(User user) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final Map<String, dynamic> supabaseData = {
        'first_name': user.firstName,
        'last_name': user.lastName,
        'middle_initial': user.middleInitial,
        'sitio': user.sitio,
        'phone_number': dbHelper.encrypt(user.phoneNumber), // E2EE
        'pin_code': dbHelper.encrypt(user.pinCode), // E2EE
        'date_of_birth': user.dateOfBirth.toIso8601String(),
        'gender': user.gender,
        'parent_id': user.parentId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('patients').update(supabaseData).eq('id', user.id);
      await DatabaseHelper.instance
          .updatePatient(user.copyWith(isSynced: true));
      SecurityLogger.info("Patient update synced", pii: user.fullName);
      return true;
    } catch (e) {
      debugPrint("⚠️ Patient update failed (Offline). $e");
      await DatabaseHelper.instance
          .updatePatient(user.copyWith(isSynced: false));
      return false;
    }
  }

  // Delete patient from Supabase
  Future<bool> deletePatient(String userId) async {
    try {
      // REMOVED: Cloud update for is_deleted as column is missing in Supabase schema
      // await supabase.from('patients').update({'is_deleted': true}).eq('id', userId);
      
      await DatabaseHelper.instance.deletePatient(userId);
      debugPrint("✅ Patient soft-deleted locally: $userId (Cloud delete skipped due to schema)");
      return true;
    } catch (e) {
      debugPrint("⚠️ Local delete failed: $e");
      return false;
    }
  }

  // Check if patient exists in Supabase
  Future<List<Map<String, dynamic>>> findPatient(
      String nameInput, String phoneNumber) async {
    try {
      // 1. Fetch strictly by phone number
      final data = await supabase
          .from('patients')
          .select()
          .eq('phone_number', phoneNumber);

      // 2. Filter locally to match name variants
      return data.where((row) {
        final first = row['first_name']?.toString().toLowerCase() ?? '';
        final last = row['last_name']?.toString().toLowerCase() ?? '';
        final middle = row['middle_initial']?.toString().toLowerCase() ?? '';

        final input = nameInput.toLowerCase().trim();

        if (input == first || input == last) return true;

        final fullName1 = "$first $last".toLowerCase();
        final fullName2 = "$first $middle $last"
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        final fullName3 = "$first $middle. $last"
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');

        return input == fullName1 ||
            input == fullName2 ||
            input == fullName3 ||
            input == "$last, $first".toLowerCase() ||
            input == "$last, $first $middle".toLowerCase();
      }).toList();
    } catch (e) {
      debugPrint("⚠️ Patient cloud lookup failed: $e");
      return [];
    }
  }

  // Mobile App Autocomplete Search (Hybrid: Cloud + Local Fallback)
  Future<List<User>> searchPatients(String query) async {
    if (query.isEmpty) return [];
    try {
      // 1. Fetch from Local Database first (Immediate/Offline)
      final db = await DatabaseHelper.instance.database;
      final localData = await db.query(
        'patients',
        where: 'first_name LIKE ? OR last_name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 10,
      );
      final List<User> localUsers =
          localData.map((json) => User.fromMap(json)).toList();

      // 2. Fetch from Supabase Cloud (Background/Network)
      final cloudData = await supabase
          .from('patients')
          .select()
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%')
          .limit(10);
      final List<User> cloudUsers =
          cloudData.map((json) => User.fromMap(json)).toList();

      // 3. Merge and Deduplicate by ID
      final Map<String, User> merged = {};
      for (final u in localUsers) {
        merged[u.id] = u;
      }
      for (final u in cloudUsers) {
        merged[u.id] = u;
      }

      return merged.values.toList();
    } catch (e) {
      debugPrint("⚠️ Patient search failed: $e");
      // If network fails, return at least local results
      try {
        final db = await DatabaseHelper.instance.database;
        final localData = await db.query(
          'patients',
          where: 'first_name LIKE ? OR last_name LIKE ?',
          whereArgs: ['%$query%', '%$query%'],
          limit: 10,
        );
        return localData.map((json) => User.fromMap(json)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  // Mobile App Authentication (Strict Phone + PIN Match)
  Future<User?> authenticatePatient(String phone, String pin) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      // Cloud now stores encrypted strings. We must matching against the encrypted versions.
      final encryptedPhone = dbHelper.encrypt(phone);
      final encryptedPin = dbHelper.encrypt(pin);

      final data = await supabase
          .from('patients')
          .select()
          .eq('phone_number', encryptedPhone)
          .eq('pin_code', encryptedPin)
          .limit(1);

      if (data.isNotEmpty) {
        // Return decrypted user object
        final row = data.first;
        final decryptedRow = Map<String, dynamic>.from(row);
        decryptedRow['phone_number'] = dbHelper.decrypt(row['phone_number']);
        decryptedRow['pin_code'] = dbHelper.decrypt(row['pin_code']);
        return User.fromMap(decryptedRow);
      }
      return null;
    } catch (e) {
      debugPrint("⚠️ Authentication cloud query failed: $e");
      return null;
    }
  }

  // Mobile App: Fetch Family Dependents
  Future<List<User>> fetchDependents(String parentId) async {
    try {
      final data =
          await supabase.from('patients').select().eq('parent_id', parentId);
      return data.map((json) => User.fromMap(json)).toList();
    } catch (e) {
      debugPrint("⚠️ Failed to fetch dependents: $e");
      return [];
    }
  }

  // --- VITALS SYNCING ---

  // Fetch Patient Vitals from SQLite (OFFLINE-FIRST)
  Future<List<VitalSigns>> fetchPatientVitalsLocal(String userId) async {
    // UPDATED: Redirect to DatabaseHelper to ensure decryption is handled correctly.
    // SyncService previously used VitalSigns.fromMap which fails on encrypted strings.
    return await DatabaseHelper.instance.getRecordsByUserId(userId);
  }

  // Fetch Patient Vitals from Supabase (Mobile App Real-time Analytics)
  Future<List<VitalSigns>> fetchPatientVitals(String userId) async {
    try {
      final data = await supabase
          .from('vitals')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);

      return data.map((json) => VitalSigns.fromMap(json)).toList();
    } catch (e) {
      debugPrint("⚠️ Failed to fetch patient vitals from cloud: $e");
      return [];
    }
  }

  /// NEW: Fetch and Cache ALL family vitals for offline access
  Future<void> syncFamilyVitals(List<String> familyIds) async {
    if (familyIds.isEmpty) return;
    try {
      debugPrint("🔄 Syncing Family Vitals for offline access...");
      final data = await supabase
          .from('vitals')
          .select()
          .filter('user_id', 'in', familyIds)
          .order('updated_at', ascending: true);

      if (data.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final batch = db.batch();
        for (var row in data) {
          final vitalMap = {
            'id': row['id'],
            'user_id': row['user_id'],
            'timestamp': row['timestamp'],
            'heart_rate': DatabaseHelper.instance.encrypt(row['heart_rate']),
            'systolic_bp': DatabaseHelper.instance.encrypt(row['systolic_bp']),
            'diastolic_bp': DatabaseHelper.instance.encrypt(row['diastolic_bp']),
            'oxygen': DatabaseHelper.instance.encrypt(row['oxygen']),
            'temperature': DatabaseHelper.instance.encrypt(row['temperature']),
            'bmi': row['bmi'],
            'bmi_category': row['bmi_category'],
            'status': row['status'],
            'remarks': row['remarks'],
            'follow_up_action': row['follow_up_action'],
            'updated_at': row['updated_at'],
            'is_deleted': row['is_deleted'] == true ? 1 : 0,
            'is_synced': 1
          };
          batch.insert('vitals', vitalMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        debugPrint("✅ Cached ${data.length} family vitals locally.");
        _vitalsChangeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ Error syncing family vitals: $e");
    }
  }

  // Push new Vitals to Supabase
  Future<void> createVitalSign(VitalSigns vital) async {
    try {
      final Map<String, dynamic> supabaseData = {
        'id': vital.id,
        'user_id': vital.userId,
        'timestamp': vital.timestamp.toIso8601String(),
        'heart_rate': vital.heartRate,
        'systolic_bp': vital.systolicBP,
        'diastolic_bp': vital.diastolicBP,
        'oxygen': vital.oxygen,
        'temperature': vital.temperature,
        'bmi': vital.bmi,
        'status': vital.status,
        'remarks': vital.remarks,
      };

      debugPrint("🌐 Attempting to push new vitals to Supabase...");
      await supabase.from('vitals').insert(supabaseData);
      debugPrint("✅ Successfully pushed vitals to Supabase.");
    } catch (e) {
      debugPrint("⚠️ Supabase push failed for Vitals (Offline Mode). $e");
    }
  }

  // Push Updated Vitals Status/Remarks to Supabase
  Future<void> updateVitalSign(VitalSigns vital) async {
    try {
      final Map<String, dynamic> supabaseData = {
        'status': vital.status,
        'remarks': vital.remarks,
        'follow_up_action': vital.followUpAction,
      };

      await supabase.from('vitals').update(supabaseData).eq('id', vital.id);
      debugPrint("✅ Successfully updated vitals status in Supabase.");
    } catch (e) {
      debugPrint("⚠️ Supabase update failed for Vitals (Offline). $e");
    }
  }

  // --- SCHEDULES SYNCING ---

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
      await DatabaseHelper.instance.markScheduleAsSynced(id);
      debugPrint("✅ Schedule pushed to Supabase cloud.");
    } catch (e) {
      debugPrint("⚠️ Supabase push failed for Schedule (Offline). $e");
    }
  }

  Future<void> deleteScheduleCloud(String id) async {
    try {
      await supabase.from('schedules').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      debugPrint("✅ Schedule soft-deleted from Supabase.");
    } catch (e) {
      debugPrint("⚠️ Failed to delete schedule: $e");
    }
  }

  // --- ANNOUNCEMENTS SYNCING ---

  // Push a new Announcement to Supabase (called from Admin Desktop)
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
      await DatabaseHelper.instance.markAnnouncementAsSynced(id);
      debugPrint("✅ Announcement pushed to Supabase cloud.");
    } catch (e) {
      debugPrint("⚠️ Supabase push failed for Announcement (Offline). $e");
    }
  }

  // Delete Announcement (called from Admin Desktop)
  Future<void> deleteAnnouncement(String id) async {
    try {
      await supabase.from('announcements').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      debugPrint("✅ Announcement soft-deleted from Supabase.");
    } catch (e) {
      debugPrint("⚠️ Failed to delete announcement: $e");
    }
  }

  // React to Announcement
  Future<void> reactToAnnouncement(
      String announcementId, String emoji, String userId) async {
    try {
      // 1. OPTIMISTIC UPDATE: Fetch local record first
      final localData =
          await DatabaseHelper.instance.getAnnouncementById(announcementId);
      if (localData == null) {
        debugPrint(
            "⚠️ Optimistic Update: Announcement $announcementId not found locally.");
        return;
      }

      Map<String, dynamic> reactions = {};
      if (localData['reactions'] is String) {
        try {
          reactions = json.decode(localData['reactions']);
        } catch (_) {
          reactions = {};
        }
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

      // 2. Update local DB immediately
      await DatabaseHelper.instance.updateAnnouncement({
        'id': announcementId,
        'reactions': json.encode(reactions),
      });

      // 3. Broadcast to UI immediately (Seamless/Instant feedback)
      _announcementChangeController.add(null);
      debugPrint("⚡ Optimistic reaction update: $emoji");

      // 4. Background: Update Supabase Cloud
      unawaited(() async {
        try {
          // Fetch freshest cloud state to merge (Slightly safer than just overwriting)
          final cloudData = await supabase
              .from('announcements')
              .select('reactions')
              .eq('id', announcementId)
              .single();

          Map<String, dynamic> cloudReactions =
              Map<String, dynamic>.from(cloudData['reactions'] ?? {});
          List<dynamic> cloudUsers =
              List<dynamic>.from(cloudReactions[emoji] ?? []);

          // Sync the user state to cloud
          if (users.contains(userId)) {
            if (!cloudUsers.contains(userId)) cloudUsers.add(userId);
          } else {
            cloudUsers.remove(userId);
          }

          if (cloudUsers.isEmpty) {
            cloudReactions.remove(emoji);
          } else {
            cloudReactions[emoji] = cloudUsers;
          }

          await supabase
              .from('announcements')
              .update({'reactions': cloudReactions}).eq('id', announcementId);
          debugPrint("✅ Cloud reaction sync complete.");
        } on PostgrestException catch (pe) {
          debugPrint(
              "⚠️ Background Cloud Reaction Fail (RLS/Database): ${pe.message}");
        } catch (e) {
          debugPrint("⚠️ Background Cloud Reaction Fail (Connection): $e");
        }
      }());
    } catch (e) {
      debugPrint("❌ reactToAnnouncement Error: $e");
    }
  }

  // Fetch all filtered Announcements from SQLite (called from Mobile App)
  Future<List<Map<String, dynamic>>> fetchAnnouncements(
      {User? currentUser}) async {
    try {
      final all = await DatabaseHelper.instance.getAnnouncements();
      debugPrint("DEBUG: Total local announcements in DB: ${all.length}");

      var filtered = all.where((a) {
        final isDeleted = a['is_deleted'] == 1 || a['is_deleted'] == true;
        final isActive = a['is_active'] == 1 || a['is_active'] == true || a['isActive'] == 1 || a['isActive'] == true;
        if (isDeleted || !isActive) return false;
        return true;
      }).toList();

      if (currentUser != null) {
        final age = currentUser.age;
        debugPrint("DEBUG: Filtering for user age: $age");
        // Optimized check: Don't perform network calls here!
        // Just use a simple age/target check. Senior check is age >= 60.
        // We can't know child status easily without network, so we check if age <= 12
        // as a heuristic for "children" announcements or if they are the head of household.
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])
                  ?.toString()
                  .toUpperCase() ??
              'ALL';
          debugPrint("DEBUG: Checking target '$target' against age $age");
          if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
          if (target == 'SENIORS' && age >= 60) return true;
          if (target == 'CHILDREN' && age <= 12) return true;
          return false;
        }).toList();
      }

      // Sort by timestamp descending
      filtered.sort((a, b) {
        final dtA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final dtB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return dtB.compareTo(dtA);
      });

      final List<Map<String, dynamic>> finalResult = [];
      for (var a in filtered) {
        final Map<String, dynamic> processed = Map<String, dynamic>.from(a);

        // Decode reactions if it's a string
        if (processed['reactions'] is String) {
          try {
            processed['reactions'] = json.decode(processed['reactions']);
          } catch (_) {
            processed['reactions'] = {};
          }
        }

        finalResult.add(processed);
      }

      debugPrint("DEBUG: Returning ${finalResult.length} announcements to UI.");
      return finalResult;
    } catch (e) {
      debugPrint("❌ fetchAnnouncements Error: $e");
      return [];
    }
  }

  // Fetch all filtered Alerts from SQLite (called from Mobile App)
  Future<List<Map<String, dynamic>>> fetchAlerts({User? currentUser}) async {
    try {
      final all = await DatabaseHelper.instance.getAlerts();
      var filtered = all.where((a) {
        final isDeleted = a['is_deleted'] == 1 || a['is_deleted'] == true;
        // Alerts are usually active until deleted or until they expire (implicit)
        if (isDeleted) return false;
        return true;
      }).toList();

      if (currentUser != null) {
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])
                  ?.toString()
                  .toUpperCase() ??
              'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
          
          // Senior check (age >= 60)
          if (target == 'SENIORS' && currentUser.age >= 60) return true;
          
          // Child check (age <= 12)
          if (target == 'CHILDREN' && currentUser.age <= 12) return true;
          
          return false;
        }).toList();
      }

      // Sort by timestamp descending
      filtered.sort((a, b) {
        final dtA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final dtB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return dtB.compareTo(dtA);
      });

      return filtered;
    } catch (e) {
      debugPrint("❌ fetchAlerts Error: $e");
      return [];
    }
  }
  /// Helper to convert boolean values to integers (0/1) for SQLite compatibility on Windows
  Map<String, dynamic> _prepareRowForSqlite(Map<String, dynamic> row) {
    final prepared = Map<String, dynamic>.from(row);
    prepared.forEach((key, value) {
      if (value is bool) {
        prepared[key] = value ? 1 : 0;
      }
    });
    return prepared;
  }
}
