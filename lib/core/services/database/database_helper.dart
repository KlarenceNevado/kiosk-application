import 'dart:async';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../../features/health_check/models/vital_signs_model.dart';
import '../../../features/auth/models/user_model.dart';
import '../../models/system_log_model.dart';
import '../../services/security/encryption_service.dart';
import 'migration_service.dart';
import 'dao/patient_dao.dart';
import 'dao/vitals_dao.dart';
import 'dao/system_dao.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();
  static Completer<Database>? _dbInitCompleter;
  
  // Isolate-safety: Only the UI isolate should perform migrations.
  static bool _isBackground = false;

  /// Set to true in the background isolate to skip migrations and heavy sanity checks.
  void setIsBackground(bool value) {
    _isBackground = value;
    debugPrint("📂 [DatabaseHelper] Mode set to: ${_isBackground ? 'BACKGROUND' : 'MAIN UI'}");
  }

  late final PatientDao patientDao;
  late final VitalsDao vitalsDao;
  late final SystemDao systemDao;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_dbInitCompleter != null) {
      return await _dbInitCompleter!.future;
    }

    _dbInitCompleter = Completer<Database>();

    if (kIsWeb) {
      try {
        debugPrint("🌐 [DatabaseHelper] Web Platform detected. Initializing SQLite for Web...");
        databaseFactory = databaseFactoryFfiWeb;
        _database = await _initDB('kiosk_health.db');
        _dbInitCompleter!.complete(_database);
        return _database!;
      } catch (e) {
        debugPrint("❌ [DatabaseHelper] Web Database Init Failed: $e");
        _dbInitCompleter!.completeError(e);
        _dbInitCompleter = null;
        rethrow;
      }
    }

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      _database = await _initDB('kiosk_health.db');
      _dbInitCompleter!.complete(_database);
      return _database!;
    } catch (e) {
      _dbInitCompleter!.completeError(e);
      _dbInitCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final String path;
    if (kIsWeb) {
      path = filePath; // Web uses simple names for IndexedDB
    } else {
      // 1. Get a shared absolute path for both apps to use
      final directory = await getApplicationSupportDirectory();
      path = join(directory.path, filePath);
    }

    debugPrint("Database Path Unified: $path");

    // Ensure Encryption is active before any DB operations occur
    await EncryptionService().init();

    final db = await openDatabase(
      path,
      version: 21, // BUMPED TO 21 FOR PUSH TOKEN SUPPORT
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );

    // 3. Centralized Migration & Sanity Checks
    if (!_isBackground) {
      final migrationService = MigrationService();
      await migrationService.runMigrations(db);
      await migrationService.performSanityCheck(db);
    } else {
      debugPrint("📂 [DatabaseHelper] Background Isolate: Skipping migrations & sanity checks.");
    }

    // 4. Initialize DAOs
    patientDao = PatientDao(db);
    vitalsDao = VitalsDao(db);
    systemDao = SystemDao(db);

    return db;
  }

  Future _createDB(Database db, int version) async {
    // Patients Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS patients (
      id TEXT PRIMARY KEY,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      middle_initial TEXT,
      sitio TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      pin_code TEXT,
      gender TEXT NOT NULL,
      date_of_birth TEXT NOT NULL,
      parent_id TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 0,
      relation TEXT,
      device_token TEXT
    )
    ''');

    // Vitals Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS vitals (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      heart_rate TEXT NOT NULL,
      systolic_bp TEXT NOT NULL,
      diastolic_bp TEXT NOT NULL,
      oxygen TEXT NOT NULL,
      temperature TEXT NOT NULL,
      bmi REAL,
      bmi_category TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      remarks TEXT,
      follow_up_action TEXT,
      report_url TEXT,
      report_path TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0 
    )
    ''');

    // Audit Logs Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      action TEXT NOT NULL,
      description TEXT,
      severity TEXT NOT NULL DEFAULT 'LOW',
      user_id TEXT,
      ip_address TEXT,
      device_info TEXT,
      hash TEXT,
      previous_hash TEXT
    )
    ''');

    // SECURITY HARDENING: SQL TRIGGERS FOR IMMUTABILITY (WORM)
    await db.execute('DROP TRIGGER IF EXISTS audit_logs_immutable_update');
    await db.execute('''
    CREATE TRIGGER audit_logs_immutable_update
    BEFORE UPDATE ON audit_logs
    BEGIN
      SELECT RAISE(ABORT, 'Audit logs are immutable and cannot be modified.');
    END;
    ''');

    await db.execute('DROP TRIGGER IF EXISTS audit_logs_immutable_delete');
    await db.execute('''
    CREATE TRIGGER audit_logs_immutable_delete
    BEFORE DELETE ON audit_logs
    BEGIN
      SELECT RAISE(ABORT, 'Audit logs are immutable and cannot be deleted.');
    END;
    ''');

    // Announcements Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS announcements (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      target_group TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      reactions TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // Schedules Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS schedules (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      date TEXT NOT NULL,
      location TEXT NOT NULL,
      assigned TEXT NOT NULL,
      color_value INTEGER NOT NULL,
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // Alerts Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS alerts (
      id TEXT PRIMARY KEY,
      message TEXT NOT NULL,
      target_group TEXT NOT NULL,
      is_emergency INTEGER NOT NULL DEFAULT 0,
      timestamp TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // chat_messages Table
    await db.execute('''
    CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY,
      sender_id TEXT NOT NULL,
      receiver_id TEXT NOT NULL,
      patient_id TEXT,
      sender TEXT,
      message TEXT,
      parent_id TEXT,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      reply_to TEXT,
      reactions TEXT DEFAULT '{}',
      media_url TEXT,
      media_path TEXT,
      is_forwarded INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT "1970-01-01T00:00:00Z",
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // Reminders Table (NEW in v16)
    await db.execute('''
    CREATE TABLE IF NOT EXISTS reminders (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      time TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      user_id TEXT NOT NULL
    )
    ''');

    // Sync Metadata Table (NEW in v17)
    await db.execute('''
    CREATE TABLE IF NOT EXISTS sync_metadata (
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      last_error TEXT,
      retry_count INTEGER DEFAULT 0,
      last_attempt TEXT,
      is_blocked INTEGER DEFAULT 0,
      PRIMARY KEY (table_name, record_id)
    )
    ''');

    // System Logs Table (NEW in v18)
    await db.execute('''
    CREATE TABLE IF NOT EXISTS system_logs (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      session_id TEXT,
      action TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      duration_seconds INTEGER DEFAULT 0,
      sensor_failures TEXT,
      severity TEXT NOT NULL,
      module TEXT NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT DEFAULT (datetime('now'))
    )
    ''');
  }

  // Handle schema changes cleanly
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint("🛠️ Database Upgrade: v$oldVersion -> v$newVersion");
    
    // Sqflite calls onUpgrade within a transaction. 
    // We add logging for academic/audit purposes.
    // If upgrading from an older version, ensure audit_logs exists
    if (oldVersion < 4) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL,
        description TEXT,
        user_id TEXT,
        ip_address TEXT
      )
      ''');

      // Ensure vitals table also exists or is updated if needed
      await db.execute('''
      CREATE TABLE IF NOT EXISTS vitals (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        heartRate INTEGER NOT NULL,
        systolicBP INTEGER NOT NULL,
        diastolicBP INTEGER NOT NULL,
        oxygen INTEGER NOT NULL,
        temperature REAL NOT NULL,
        bmi REAL,
        bmiCategory TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        remarks TEXT,
        followUpAction TEXT,
        report_url TEXT,
        report_path TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        is_synced INTEGER NOT NULL DEFAULT 0 
      )
      ''');
    }

    if (oldVersion < 6) {
      // Add is_synced to announcements if not exists
      try {
        await db.execute(
            'ALTER TABLE announcements ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      // Add is_synced to alerts if not exists
      try {
        await db.execute(
            'ALTER TABLE alerts ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      // Ensure isActive is added to legacy db instances
      try {
        await db.execute(
            'ALTER TABLE alerts ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      // 1. Create Patients Table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        middle_initial TEXT,
        sitio TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        pin_code TEXT,
        gender TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        parent_id TEXT,
        updated_at TEXT DEFAULT (datetime('now')),
        is_deleted INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
      ''');

      // 2. Add Delta Sync columns to other tables
      final tables = ['vitals', 'announcements', 'schedules', 'alerts'];
      for (final table in tables) {
        try {
          // SQLite ALTER TABLE does not support non-constant defaults like datetime('now')
          // Using a placeholder constant that will be updated on the first sync.
          await db.execute(
              'ALTER TABLE $table ADD COLUMN updated_at TEXT DEFAULT "1970-01-01T00:00:00Z"');
          await db.execute(
              'ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
        } catch (_) {}
      }
    }

    if (oldVersion < 10) {
      // 1. Add Delta Sync columns to tables if they were missed due to non-constant default error
      final tables = ['vitals', 'announcements', 'schedules', 'alerts'];
      for (final table in tables) {
        try {
          // SQLite ALTER TABLE does not support non-constant defaults like datetime('now')
          // Using a placeholder constant that will be updated on the first sync.
          await db.execute(
              'ALTER TABLE $table ADD COLUMN updated_at TEXT DEFAULT "1970-01-01T00:00:00Z"');
          await db.execute(
              'ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
        } catch (_) {
          // Column might already exist, which is fine
        }
      }

      // 2. Create local Chat Messages table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        reply_to TEXT,
        reactions TEXT DEFAULT '{}',
        is_deleted INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT "1970-01-01T00:00:00Z",
        is_synced INTEGER NOT NULL DEFAULT 0
      )
      ''');

      debugPrint("🚀 Database Upgraded to Version 10 (Chat & Sync Fixes)");
    }

    if (oldVersion < 11) {
      debugPrint(
          "🚀 Database Upgraded to Version 11 (Chat Forwarding & Icons)");
    }

    // Legacy version handling - delegating structural checks to MigrationService
    debugPrint("📂 [DatabaseHelper] Performing upgrade check from v$oldVersion to v$newVersion");
    
    // We keep historical execute blocks if they are critical and not covered by sanityCheck
    if (oldVersion < 12) {
      // Chat Indexes
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_sender ON chat_messages(sender_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_receiver ON chat_messages(receiver_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_timestamp ON chat_messages(timestamp)');
      } catch (_) {}
    }

    // Modern structural integrity is now handled by MigrationService.performSanityCheck(db)
    // called in _initDB after openDatabase.

    if (oldVersion < 18) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS system_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        session_id TEXT,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        sensor_failures TEXT,
        severity TEXT NOT NULL,
        module TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT DEFAULT (datetime('now'))
      )
      ''');
      debugPrint("🚀 Database Upgraded to Version 18 (System Logs Table)");
    }
    
    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE patients ADD COLUMN device_token TEXT');
        debugPrint("🚀 Database Upgraded to Version 21 (Push Token Architecture)");
      } catch (_) {}
    }
  }

  // --- ENCRYPTION HELPERS ---
  String _encrypt(dynamic value) {
    if (value == null) return '';
    final strVal = value.toString();
    // If it's already an 'iv:ciphertext' payload, don't double-encrypt
    if (strVal.contains(':') && strVal.length > 20) {
      return strVal;
    }
    return EncryptionService().encryptData(strVal);
  }

  /// Public wrapper for encryption (used by SyncService)
  String encrypt(dynamic value) => _encrypt(value);

  /// Public wrapper for decryption (used by SyncService)
  String decrypt(String encrypted) => _decrypt(encrypted);

  String _decrypt(String encrypted) {
    if (encrypted.isEmpty) return '';
    return EncryptionService().decryptData(encrypted);
  }

  int _decryptInt(String encrypted) {
    final val = _decrypt(encrypted);
    return int.tryParse(val) ?? 0;
  }

  double _decryptDouble(String encrypted) {
    final val = _decrypt(encrypted);
    return double.tryParse(val) ?? 0.0;
  }

  Future<void> createRecord(VitalSigns record) => vitalsDao.createRecord(record);

  // Same as createRecord, but forces is_synced based on the incoming valid map (from sync service)
  Future<void> insertVitalSign(Map<String, dynamic> map) => vitalsDao.insertVitalSign(map);

  Future<void> updateRecord(VitalSigns record) => vitalsDao.updateRecord(record);

  /// Partial update for specific fields (e.g. file paths during sync)
  Future<int> updateRecordRaw(String id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'vitals',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  VitalSigns _parseVitalSigns(Map<String, dynamic> json) {
    try {
      // Helper to handle both encrypted (String) and legacy (int/double) data
      int getInt(dynamic val) {
        if (val == null) return 0;
        if (val is int) return val;
        try {
          return _decryptInt(val.toString());
        } catch (_) {
          return int.tryParse(val.toString()) ?? 0;
        }
      }

      double getDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is double) return val;
        if (val is int) return val.toDouble();
        try {
          return _decryptDouble(val.toString());
        } catch (_) {
          return double.tryParse(val.toString()) ?? 0.0;
        }
      }

      return VitalSigns(
        id: json['id'] ?? '',
        userId: json['userId'] ?? json['user_id'] ?? 'guest',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        heartRate: getInt(json['heartRate'] ?? json['heart_rate']),
        systolicBP: getInt(json['systolicBP'] ?? json['systolic_bp']),
        diastolicBP: getInt(json['diastolicBP'] ?? json['diastolic_bp']),
        oxygen: getInt(json['oxygen']),
        temperature: getDouble(json['temperature']),
        bmi: json['bmi'] is String
            ? double.tryParse(json['bmi'])
            : (json['bmi'] as num?)?.toDouble(),
        bmiCategory: json['bmiCategory'] ?? json['bmi_category'],
        status: json['status'] ?? 'pending',
        remarks: json['remarks'],
        followUpAction: json['followUpAction'] ?? json['follow_up_action'],
      );
    } catch (e) {
      debugPrint("❌ Error parsing vital signs: $e");
      // Fallback to basic map if logic above fails
      return VitalSigns.fromMap(json);
    }
  }

  Future<List<VitalSigns>> getRecordsByUserId(String userId) async {
    final db = await database;
    final result = await db.query('vitals',
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<List<VitalSigns>> getAllRecords() async {
    final db = await database;
    final result = await db.query('vitals',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<Map<String, dynamic>?> getVitalRecordById(String id) async {
    final db = await database;
    final results = await db.query('vitals', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  // --- SYNC SUPPORT MODULES ---
  Future<List<User>> getUnsyncedPatients() => patientDao.getUnsyncedPatients();

  Future<void> markPatientAsSynced(String id) => patientDao.markPatientAsSynced(id);

  Future<List<VitalSigns>> getUnsyncedRecords() => vitalsDao.getUnsyncedRecords();

  Future<void> markRecordAsSynced(String id) => vitalsDao.markRecordAsSynced(id);

  Future<void> markAnnouncementAsSynced(String id) async {
    final db = await database;
    await db.update(
      'announcements',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAlertAsSynced(String id) async {
    final db = await database;
    await db.update(
      'alerts',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markScheduleAsSynced(String id) async {
    final db = await database;
    await db.update(
      'schedules',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Batch update for sync status - much more efficient for bulk operations
  Future<void> markBatchAsSynced(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.update(table, {'is_synced': 1, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
    debugPrint("✅ Database: Marked ${ids.length} records in '$table' as synced.");
  }

  // --- SECURITY METHODS ---
  Future<void> logSecurityEvent(String action, String description,
          {String severity = 'LOW', String? userId}) =>
      systemDao.logSecurityEvent(action, description,
          severity: severity, userId: userId);

  Future<bool> verifyAuditIntegrity() => systemDao.verifyAuditIntegrity();

  Future<Map<String, dynamic>> getSecurityPulse() =>
      systemDao.getSecurityPulse();

  // --- SYNC METADATA HELPERS ---
  Future<void> updateSyncMetadata({
    required String tableName,
    required String recordId,
    String? error,
    bool incrementRetry = false,
    bool block = false,
  }) =>
      systemDao.updateSyncMetadata(
          tableName: tableName,
          recordId: recordId,
          error: error,
          incrementRetry: incrementRetry,
          block: block);

  Future<void> clearSyncMetadata(String tableName, String recordId) =>
      systemDao.clearSyncMetadata(tableName, recordId);

  Future<List<String>> getBlockedRecords(String tableName) =>
      systemDao.getBlockedRecords(tableName);

  Future<Map<String, dynamic>?> getSyncMetadata(
          String tableName, String recordId) =>
      systemDao.getSyncMetadata(tableName, recordId);

  Future<List<Map<String, dynamic>>> getAuditLogs() => systemDao.getAuditLogs();

  Future<void> clearHistory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('vitals');
      await txn.execute('VACUUM');
    });

    await logSecurityEvent(
        "DATA_WIPE", "All vital sign history cleared and database vacuumed.");
  }

  // --- PATIENT MODULE CRUD ---

  Future<void> insertPatient(User user) async {
    final db = await database;
    final map = user.toMap();

    // Encrypt sensitive fields before saving to SQLite
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'first_name': map['first_name'] ?? map['firstName'],
      'last_name': map['last_name'] ?? map['lastName'],
      'middle_initial': map['middle_initial'] ?? map['middleInitial'],
      'sitio': map['sitio'],
      'phone_number': _encrypt(map['phone_number'] ?? map['phoneNumber']),
      'pin_code': _encrypt(map['pin_code'] ?? map['pin_code'] ?? map['pinCode']),
      'gender': map['gender'],
      'date_of_birth': map['date_of_birth'] ?? map['dateOfBirth'],
      'parent_id': map['parent_id'] ?? map['parentId'],
      'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted':
          (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'is_active': (map['is_active'] == true || map['is_active'] == 1 || map['isActive'] == true || map['isActive'] == 1) ? 1 : 0,
      'is_synced': (map['is_synced'] == true || map['is_synced'] == 1) ? 1 : 0,
      'device_token': map['device_token'] ?? map['deviceToken'],
    };

    await db.insert('patients', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getPatients() async {
    final db = await database;
    final result = await db.query('patients',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'last_name ASC');
    return result.map((json) {
      final decrypted = Map<String, dynamic>.from(json);
      decrypted['phoneNumber'] = _decrypt(json['phone_number']?.toString() ?? '');
      decrypted['pinCode'] = _decrypt(json['pin_code']?.toString() ?? '');
      decrypted['deviceToken'] = json['device_token'];
      // Ensure model mapping works with snake_case from DB
      return User.fromMap(decrypted);
    }).toList();
  }

  Future<User?> getPatientById(String id) async {
    final db = await database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final decrypted = Map<String, dynamic>.from(maps.first);
      decrypted['phoneNumber'] = _decrypt(maps.first['phone_number']?.toString() ?? '');
      decrypted['pinCode'] = _decrypt(maps.first['pin_code']?.toString() ?? '');
      decrypted['deviceToken'] = maps.first['device_token'];
      return User.fromMap(decrypted);
    }
    return null;
  }

  Future<void> updatePatient(User user) async {
    final db = await database;
    final map = user.toMap();
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'first_name': map['first_name'] ?? map['firstName'],
      'last_name': map['last_name'] ?? map['lastName'],
      'middle_initial': map['middle_initial'] ?? map['middleInitial'],
      'sitio': map['sitio'],
      'phone_number': _encrypt(map['phone_number'] ?? map['phoneNumber']),
      'pin_code': _encrypt(map['pin_code'] ?? map['pin_code'] ?? map['pinCode']),
      'gender': map['gender'],
      'date_of_birth': map['date_of_birth'] ?? map['dateOfBirth'],
      'parent_id': map['parent_id'] ?? map['parentId'],
      'created_at': map['created_at'],
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted':
          (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'is_active': (map['is_active'] == true || map['is_active'] == 1 || map['isActive'] == true || map['isActive'] == 1) ? 1 : 0,
      'is_synced': 0, // Mark for re-sync
      'device_token': map['device_token'] ?? map['deviceToken'],
    };
    await db.update('patients', encryptedMap,
        where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deletePatient(String id) async {
    final db = await database;
    await db.update(
        'patients',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<bool> checkDatabaseIntegrity() async {
    final db = await database;
    try {
      final result = await db.rawQuery('PRAGMA integrity_check');
      final isOk =
          result.isNotEmpty && result.first.values.first.toString() == 'ok';

      await logSecurityEvent(isOk ? "INTEGRITY_PASS" : "INTEGRITY_FAIL",
          "Database integrity check performed.");

      return isOk;
    } catch (e) {
      return false;
    }
  }

  // --- SYSTEM MODULE DELEGATION ---

  Future<void> insertAnnouncement(Map<String, dynamic> row) =>
      systemDao.insertAnnouncement(row);

  Future<List<Map<String, dynamic>>> getAnnouncements() =>
      systemDao.getAnnouncements();

  Future<Map<String, dynamic>?> getAnnouncementById(String id) =>
      systemDao.getAnnouncementById(id);

  Future<void> updateAnnouncement(Map<String, dynamic> row) =>
      systemDao.updateAnnouncement(row);

  Future<void> deleteAnnouncement(String id) =>
      systemDao.deleteAnnouncement(id);

  // --- SCHEDULES ---
  Future<void> insertSchedule(Map<String, dynamic> row) =>
      systemDao.insertSchedule(row);

  Future<List<Map<String, dynamic>>> getSchedules() => systemDao.getSchedules();

  Future<void> deleteSchedule(String id) => systemDao.deleteSchedule(id);

  Future<Map<String, dynamic>?> getScheduleById(String id) =>
      systemDao.getScheduleById(id);

  // --- ALERTS ---
  Future<void> insertAlert(Map<String, dynamic> row) =>
      systemDao.insertAlert(row);

  Future<List<Map<String, dynamic>>> getAlerts() => systemDao.getAlerts();

  Future<Map<String, dynamic>?> getAlertById(String id) =>
      systemDao.getAlertById(id);

  Future<void> updateAlert(Map<String, dynamic> row) =>
      systemDao.updateAlert(row);

  Future<void> deleteAlert(String id) => systemDao.deleteAlert(id);

  // --- UNSYNCED FETCHERS ---
  Future<List<Map<String, dynamic>>> getUnsyncedAnnouncements() =>
      systemDao.getUnsyncedAnnouncements();

  Future<List<Map<String, dynamic>>> getUnsyncedAlerts() =>
      systemDao.getUnsyncedAlerts();

  Future<List<Map<String, dynamic>>> getUnsyncedSchedules() =>
      systemDao.getUnsyncedSchedules();

  Future<List<Map<String, dynamic>>> getUnsyncedChatMessages() =>
      systemDao.getUnsyncedChatMessages();

  Future<Map<String, dynamic>?> getVitalSignById(String id) => 
      vitalsDao.getVitalSignById(id);

  // --- REMINDERS ---
  Future<int> insertReminder(Map<String, dynamic> row) =>
      systemDao.insertReminder(row);

  Future<List<Map<String, dynamic>>> getReminders(String userId) =>
      systemDao.getReminders(userId);

  Future<int> updateReminder(Map<String, dynamic> row) =>
      systemDao.updateReminder(row);

  Future<int> deleteReminder(int id) => systemDao.deleteReminder(id);

  Future<int> deleteAllReminders(String userId) =>
      systemDao.deleteAllReminders(userId);

  // --- SYSTEM LOGS ---
  Future<void> createSystemLog(SystemLog log) => systemDao.createSystemLog(log);

  Future<List<SystemLog>> getSystemLogs({int limit = 100}) =>
      systemDao.getSystemLogs(limit: limit);

  Future<List<SystemLog>> getUnsyncedSystemLogs() =>
      systemDao.getUnsyncedSystemLogs();

  Future<void> markSystemLogAsSynced(String id) =>
      systemDao.markSystemLogAsSynced(id);
}
