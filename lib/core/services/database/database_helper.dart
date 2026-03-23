import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../../../features/health_check/models/vital_signs_model.dart';
import '../../services/security/encryption_service.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../../../features/auth/models/user_model.dart';
import '../../models/system_log_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  bool _sanityCheckPerformed = false; // Singleton flag to prevent redundant checks

  DatabaseHelper._init();
  static Completer<Database>? _dbInitCompleter;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_dbInitCompleter != null) {
      return await _dbInitCompleter!.future;
    }

    _dbInitCompleter = Completer<Database>();

    try {
      if (Platform.isWindows || Platform.isLinux) {
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
    // 1. Get a shared absolute path for both apps to use
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, filePath);

    debugPrint("Database Path Unified: $path");

    // Ensure Encryption is active before any DB operations occur
    await EncryptionService().init();

    final db = await openDatabase(
      path,
      version: 18, // BUMPED TO 18 FOR SYSTEM_LOGS TABLE
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );

    // CRITICAL: Perform a manual sanity check on Windows/Desktop to ensure columns exist
    // even if migrations were skipped or failed silently.
    await performSchemaSanityCheck(db);

    return db;
  }

  Future _createDB(Database db, int version) async {
    // Patients Table
    await db.execute('''
    CREATE TABLE patients (
      id TEXT PRIMARY KEY,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      middle_initial TEXT,
      sitio TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      pin_code TEXT NOT NULL,
      gender TEXT NOT NULL,
      date_of_birth TEXT NOT NULL,
      parent_id TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 0,
      relation TEXT
    )
    ''');

    // Vitals Table
    await db.execute('''
    CREATE TABLE vitals (
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
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0 
    )
    ''');

    // Audit Logs Table
    await db.execute('''
    CREATE TABLE audit_logs (
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
    await db.execute('''
    CREATE TRIGGER audit_logs_immutable_update
    BEFORE UPDATE ON audit_logs
    BEGIN
      SELECT RAISE(ABORT, 'Audit logs are immutable and cannot be modified.');
    END;
    ''');

    await db.execute('''
    CREATE TRIGGER audit_logs_immutable_delete
    BEFORE DELETE ON audit_logs
    BEGIN
      SELECT RAISE(ABORT, 'Audit logs are immutable and cannot be deleted.');
    END;
    ''');

    // Announcements Table
    await db.execute('''
    CREATE TABLE announcements (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      target_group TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      reactions TEXT,
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // Schedules Table
    await db.execute('''
    CREATE TABLE schedules (
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
    CREATE TABLE alerts (
      id TEXT PRIMARY KEY,
      message TEXT NOT NULL,
      target_group TEXT NOT NULL,
      is_emergency INTEGER NOT NULL DEFAULT 0,
      timestamp TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // chat_messages Table
    await db.execute('''
    CREATE TABLE chat_messages (
      id TEXT PRIMARY KEY,
      sender_id TEXT NOT NULL,
      receiver_id TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      reply_to TEXT,
      reactions TEXT DEFAULT '{}',
      is_forwarded INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      updated_at TEXT DEFAULT "1970-01-01T00:00:00Z",
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // Reminders Table (NEW in v16)
    await db.execute('''
    CREATE TABLE reminders (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      time TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      user_id TEXT NOT NULL
    )
    ''');

    // Sync Metadata Table (NEW in v17)
    await db.execute('''
    CREATE TABLE sync_metadata (
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
    CREATE TABLE system_logs (
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
        pin_code TEXT NOT NULL,
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

    if (oldVersion < 12) {
      // Hardened check for is_forwarded to fix Admin Desktop crash
      try {
        final List<Map<String, dynamic>> columns =
            await db.rawQuery('PRAGMA table_info(chat_messages)');
        final bool hasIsForwarded =
            columns.any((c) => c['name'] == 'is_forwarded');

        if (!hasIsForwarded) {
          await db.execute(
              'ALTER TABLE chat_messages ADD COLUMN is_forwarded INTEGER DEFAULT 0');
          debugPrint("✅ Added is_forwarded column to chat_messages");
        }
      } catch (e) {
        debugPrint("⚠️ Error checking/adding is_forwarded: $e");
      }

      // Ensure indexes exist
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_chat_sender ON chat_messages(sender_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_chat_receiver ON chat_messages(receiver_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_chat_timestamp ON chat_messages(timestamp)');
      } catch (_) {}

      debugPrint("🚀 Database Upgraded to Version 12 (Critical Crash Fix)");
    }

    if (oldVersion < 13) {
      try {
        await _addColumnIfNotExists(db, 'patients', 'isActive', 'INTEGER DEFAULT 1');
        await _addColumnIfNotExists(db, 'announcements', 'isActive', 'INTEGER DEFAULT 1');
        await _addColumnIfNotExists(db, 'alerts', 'isActive', 'INTEGER DEFAULT 1');
        debugPrint("✅ Added isActive column to patients, announcements, and alerts");
      } catch (e) {
        debugPrint("⚠️ Error adding isActive: $e");
      }
      debugPrint("🚀 Database Upgraded to Version 13 (Archiving)");
    }

    if (oldVersion < 14) {
      final tables = [
        'patients',
        'vitals',
        'announcements',
        'schedules',
        'alerts',
        'chat_messages'
      ];
      for (final table in tables) {
        await _addColumnIfNotExists(db, table, 'is_synced', 'INTEGER NOT NULL DEFAULT 0');
        await _addColumnIfNotExists(db, table, 'updated_at', 'TEXT DEFAULT "1970-01-01T00:00:00Z"');
        await _addColumnIfNotExists(db, table, 'is_deleted', 'INTEGER DEFAULT 0');
      }
    }

    if (oldVersion < 15) {
      await _addColumnIfNotExists(db, 'patients', 'parentId', 'TEXT');
      await _addColumnIfNotExists(db, 'patients', 'relation', 'TEXT');
      debugPrint("🚀 Database Upgraded to Version 15 (Dependent Links)");
    }

    if (oldVersion < 16) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        time TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        userId TEXT NOT NULL
      )
      ''');
      debugPrint("🚀 Database Upgraded to Version 16 (Reminders Table)");
    }

    if (oldVersion < 17) {
      await _addColumnIfNotExists(db, 'vitals', 'report_url', 'TEXT');
      await _addColumnIfNotExists(db, 'vitals', 'report_path', 'TEXT');
      await _addColumnIfNotExists(db, 'announcements', 'media_url', 'TEXT');
      await _addColumnIfNotExists(db, 'announcements', 'media_path', 'TEXT');
      await _addColumnIfNotExists(db, 'chat_messages', 'media_url', 'TEXT');
      await _addColumnIfNotExists(db, 'chat_messages', 'media_path', 'TEXT');
      debugPrint("🚀 Database Upgraded to Version 17 (File Cache Support)");
    }

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
  }

  /// Forces a check on all core tables to ensure sync columns exist.
  /// This is a fallback for when ALTER TABLE in onUpgrade fails or is skipped.
  Future<void> performSchemaSanityCheck(Database db) async {
    if (_sanityCheckPerformed) return; 
    
    debugPrint("🔍 [Sanity Check] Verifying database schema integrity...");

    // 1. Rename Patients columns if they are still using camelCase (LEGACY MIGRATION)
    await _renameColumnIfExists(db, 'patients', 'firstName', 'first_name');
    await _renameColumnIfExists(db, 'patients', 'lastName', 'last_name');
    await _renameColumnIfExists(db, 'patients', 'middleInitial', 'middle_initial');
    await _renameColumnIfExists(db, 'patients', 'phoneNumber', 'phone_number');
    await _renameColumnIfExists(db, 'patients', 'pinCode', 'pin_code');
    await _renameColumnIfExists(db, 'patients', 'parentId', 'parent_id');
    await _renameColumnIfExists(db, 'patients', 'dateOfBirth', 'date_of_birth');
    await _renameColumnIfExists(db, 'patients', 'isActive', 'is_active');

    // Rename Vitals columns
    await _renameColumnIfExists(db, 'vitals', 'userId', 'user_id');
    await _renameColumnIfExists(db, 'vitals', 'heartRate', 'heart_rate');
    await _renameColumnIfExists(db, 'vitals', 'systolicBP', 'systolic_bp');
    await _renameColumnIfExists(db, 'vitals', 'diastolicBP', 'diastolic_bp');
    await _renameColumnIfExists(db, 'vitals', 'bmiCategory', 'bmi_category');
    await _renameColumnIfExists(db, 'vitals', 'followUpAction', 'follow_up_action');

    // Rename Announcements columns
    await _renameColumnIfExists(db, 'announcements', 'targetGroup', 'target_group');
    await _renameColumnIfExists(db, 'announcements', 'isActive', 'is_active');

    // Rename Schedules columns
    await _renameColumnIfExists(db, 'schedules', 'colorValue', 'color_value');

    // Rename Alerts columns
    await _renameColumnIfExists(db, 'alerts', 'targetGroup', 'target_group');
    await _renameColumnIfExists(db, 'alerts', 'isEmergency', 'is_emergency');
    await _renameColumnIfExists(db, 'alerts', 'isActive', 'is_active');

    // Rename Reminders columns
    await _renameColumnIfExists(db, 'reminders', 'isActive', 'is_active');
    await _renameColumnIfExists(db, 'reminders', 'userId', 'user_id');

    // 2. Core Tables and Columns Cleanup
    final tables = [
      'patients',
      'vitals',
      'announcements',
      'schedules',
      'alerts',
      'chat_messages',
      'reminders'
    ];
    
    for (final table in tables) {
      await _addColumnIfNotExists(db, table, 'is_synced', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, table, 'updated_at', 'TEXT DEFAULT "1970-01-01T00:00:00Z"');
      await _addColumnIfNotExists(db, table, 'is_deleted', 'INTEGER DEFAULT 0');
      
      if (['patients', 'announcements', 'alerts', 'reminders'].contains(table)) {
        await _addColumnIfNotExists(db, table, 'is_active', 'INTEGER NOT NULL DEFAULT 1');
      }
    }

    // 3. Vitals Specifics (File Cache Support)
    await _addColumnIfNotExists(db, 'vitals', 'report_url', 'TEXT');
    await _addColumnIfNotExists(db, 'vitals', 'report_path', 'TEXT');
    await _addColumnIfNotExists(db, 'vitals', 'user_id', 'TEXT NOT NULL DEFAULT "unknown"');
    
    // Rename userId to user_id in vitals if needed
    await _renameColumnIfExists(db, 'vitals', 'userId', 'user_id');

    // 4. Detailed Patient Checks
    await _addColumnIfNotExists(db, 'patients', 'created_at', 'TEXT');
    await _addColumnIfNotExists(db, 'patients', 'parent_id', 'TEXT');
    await _addColumnIfNotExists(db, 'patients', 'relation', 'TEXT');

    // 5. Build Reminders If Missing
    await db.execute('''
    CREATE TABLE IF NOT EXISTS reminders (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      time TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      userId TEXT NOT NULL
    )
    ''');

    // 6. Sync Metadata (NEW)
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

    // 7. System Logs (NEW in v18)
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
    
    _sanityCheckPerformed = true;
    debugPrint("✅ [Sanity Check] Schema verification complete.");
  }

  /// Helper to safely rename a column if it exists (SQLite 3.25.0+)
  Future<void> _renameColumnIfExists(Database db, String tableName, String oldColumn, String newColumn) async {
    try {
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final bool oldExists = columns.any((c) => c['name'] == oldColumn);
      final bool newExists = columns.any((c) => c['name'] == newColumn);

      if (oldExists && !newExists) {
        await db.execute('ALTER TABLE $tableName RENAME COLUMN $oldColumn TO $newColumn');
        debugPrint("✅ Renamed '$oldColumn' to '$newColumn' in table '$tableName'");
      }
    } catch (e) {
      debugPrint("⚠️ Error renaming column: $e");
    }
  }

  /// Helper to safely add a column only if it doesn't already exist
  Future<void> _addColumnIfNotExists(Database db, String tableName, String columnName, String columnDefinition) async {
    try {
      // Check if column exists by querying table info
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final bool columnExists = columns.any((column) => column['name'] == columnName);

      if (!columnExists) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition');
        debugPrint("✅ Added column '$columnName' to table '$tableName'");
      }
    } catch (e) {
      debugPrint("⚠️ Error adding column '$columnName' to '$tableName': $e");
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

  Future<void> createRecord(VitalSigns record) async {
    final db = await instance.database;
    final map = record.toMap();

    // ENCRYPT SENSITIVE FIELDS
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'user_id': map['userId'],
      'timestamp': map['timestamp'],
      'heart_rate': _encrypt(map['heartRate']),
      'systolic_bp': _encrypt(map['systolicBP']),
      'diastolic_bp': _encrypt(map['diastolicBP']),
      'oxygen': _encrypt(map['oxygen']),
      'temperature': _encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmi_category': map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'follow_up_action': map['followUpAction'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'is_synced': 0,
      'report_url': map['report_url'],
      'report_path': map['report_path']
    };

    await db.insert('vitals', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Same as createRecord, but forces is_synced based on the incoming valid map (from sync service)
  Future<void> insertVitalSign(Map<String, dynamic> map) async {
    final db = await instance.database;

    // ENCRYPT SENSITIVE FIELDS
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'user_id': map['user_id'] ?? map['userId'], // Prioritize snake_case, fallback to camelCase
      'timestamp': map['timestamp'],
      'heart_rate': _encrypt(map['heart_rate'] ?? map['heartRate']),
      'systolic_bp': _encrypt(map['systolic_bp'] ?? map['systolicBP']),
      'diastolic_bp': _encrypt(map['diastolic_bp'] ?? map['diastolicBP']),
      'oxygen': _encrypt(map['oxygen']),
      'temperature': _encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmi_category': map['bmi_category'] ?? map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'follow_up_action': map['follow_up_action'] ?? map['followUpAction'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'is_synced': (map['is_synced'] == true || map['is_synced'] == 1) ? 1 : 0,
      'report_url': map['report_url'],
      'report_path': map['report_path']
    };

    await db.insert('vitals', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRecord(VitalSigns record) async {
    final db = await instance.database;
    final map = record.toMap();

    // ENCRYPT SENSITIVE FIELDS for update
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'user_id': map['user_id'] ?? map['userId'],
      'timestamp': map['timestamp'],
      'heart_rate': _encrypt(map['heart_rate'] ?? map['heartRate']),
      'systolic_bp': _encrypt(map['systolic_bp'] ?? map['systolicBP']),
      'diastolic_bp': _encrypt(map['diastolic_bp'] ?? map['diastolicBP']),
      'oxygen': _encrypt(map['oxygen']),
      'temperature': _encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmi_category': map['bmi_category'] ?? map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'follow_up_action': map['follow_up_action'] ?? map['followUpAction'],
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'is_synced': 0 // Need to sync changes
    };

    await db.update('vitals', encryptedMap,
        where: 'id = ?', whereArgs: [record.id]);
  }

  /// Partial update for specific fields (e.g. file paths during sync)
  Future<int> updateRecordRaw(String id, Map<String, dynamic> data) async {
    final db = await instance.database;
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
    final db = await instance.database;
    final result = await db.query('vitals',
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<List<VitalSigns>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query('vitals',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<Map<String, dynamic>?> getVitalRecordById(String id) async {
    final db = await instance.database;
    final results = await db.query('vitals', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  // --- SYNC SUPPORT MODULES ---
  Future<List<User>> getUnsyncedPatients() async {
    final db = await instance.database;
    final maps = await db.query(
      'patients',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) {
      final decrypted = Map<String, dynamic>.from(map);
      decrypted['phoneNumber'] = _decrypt(map['phone_number'] as String);
      decrypted['pinCode'] = _decrypt(map['pin_code'] as String);
      return User.fromMap(decrypted);
    }).toList();
  }

  Future<void> markPatientAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'patients',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<VitalSigns>> getUnsyncedRecords() async {
    final db = await instance.database;
    final maps = await db.query(
      'vitals',
      where: 'is_synced = ?',
      whereArgs: [0], // 0 = False
      orderBy: 'timestamp ASC', // oldest first
    );
    return maps.map((map) => _parseVitalSigns(map)).toList();
  }

  Future<void> markRecordAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'vitals',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAnnouncementAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'announcements',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAlertAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'alerts',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markScheduleAsSynced(String id) async {
    final db = await instance.database;
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
    final db = await instance.database;
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
      {String severity = 'LOW', String? userId}) async {
    final db = await instance.database;

    // 1. Get previous hash for chaining
    final lastLogs = await db.query('audit_logs', orderBy: 'id DESC', limit: 1);
    final previousHash =
        lastLogs.isNotEmpty ? lastLogs.first['hash'] as String? : 'GENESIS';

    final timestamp = DateTime.now().toIso8601String();
    final deviceInfo =
        "${Platform.operatingSystem} (${Platform.localHostname})";

    final normalizedUserId = userId ?? 'SYSTEM';
    final normalizedSeverity = severity.toUpperCase();

    // 2. Create data string for hashing (HMAC-style using encryption key)
    final dataToHash =
        "$timestamp|$action|$description|$normalizedSeverity|$normalizedUserId|$deviceInfo|$previousHash";
    final key = utf8.encode(EncryptionService().getSecureKey());
    final hmacSha256 = Hmac(sha256, key);
    final hash = hmacSha256.convert(utf8.encode(dataToHash)).toString();

    await db.insert('audit_logs', {
      'timestamp': timestamp,
      'action': action,
      'description': description,
      'severity': normalizedSeverity,
      'user_id': normalizedUserId,
      'ip_address': 'LOCALHOST',
      'device_info': deviceInfo,
      'hash': hash,
      'previous_hash': previousHash
    });
  }

  Future<bool> verifyAuditIntegrity() async {
    final db = await instance.database;
    final logs = await db.query('audit_logs', orderBy: 'id ASC');

    String expectedPreviousHash = 'GENESIS';

    for (var log in logs) {
      final actualPreviousHash = log['previous_hash'] as String? ?? 'GENESIS';
      if (actualPreviousHash != expectedPreviousHash) {
        debugPrint(
            "❌ Integrity Violation: Hash chain broken at Log ID ${log['id']} (Expected: $expectedPreviousHash, Actual: $actualPreviousHash)");
        return false;
      }

      // Re-calculate hash to verify content (HMAC-style)
      final dataToHash =
          "${log['timestamp']}|${log['action']}|${log['description']}|${log['severity']}|${log['user_id']}|${log['device_info']}|$actualPreviousHash";
      final key = utf8.encode(EncryptionService().getSecureKey());
      final hmacSha256 = Hmac(sha256, key);
      final calculatedHash =
          hmacSha256.convert(utf8.encode(dataToHash)).toString();

      if (calculatedHash != log['hash']) {
        debugPrint(
            "❌ Integrity Violation: Content tampered at Log ID ${log['id']}");
        return false;
      }

      expectedPreviousHash = log['hash'] as String;
    }

    debugPrint("🛡️ Audit Integrity Verified: All logs are secure.");
    return true;
  }

  // --- SYNC METADATA HELPERS ---
  Future<void> updateSyncMetadata({
    required String tableName,
    required String recordId,
    String? error,
    bool incrementRetry = false,
    bool block = false,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    
    // Check if exists
    final existing = await db.query(
      'sync_metadata',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );

    if (existing.isEmpty) {
      await db.insert('sync_metadata', {
        'table_name': tableName,
        'record_id': recordId,
        'last_error': error,
        'retry_count': incrementRetry ? 1 : 0,
        'last_attempt': now,
        'is_blocked': block ? 1 : 0,
      });
    } else {
      final currentRetry = existing.first['retry_count'] as int;
      await db.update(
        'sync_metadata',
        {
          'last_error': error,
          'retry_count': incrementRetry ? currentRetry + 1 : currentRetry,
          'last_attempt': now,
          'is_blocked': block ? 1 : (existing.first['is_blocked']),
        },
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [tableName, recordId],
      );
    }
  }

  Future<void> clearSyncMetadata(String tableName, String recordId) async {
    final db = await instance.database;
    await db.delete(
      'sync_metadata',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );
  }

  Future<List<String>> getBlockedRecords(String tableName) async {
    final db = await instance.database;
    final result = await db.query(
      'sync_metadata',
      columns: ['record_id'],
      where: 'table_name = ? AND is_blocked = 1',
      whereArgs: [tableName],
    );
    return result.map((e) => e['record_id'] as String).toList();
  }

  Future<Map<String, dynamic>?> getSyncMetadata(String tableName, String recordId) async {
    final db = await instance.database;
    final result = await db.query(
      'sync_metadata',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final db = await instance.database;
    return await db.query('audit_logs', orderBy: 'id DESC', limit: 200);
  }

  Future<Map<String, dynamic>> getSecurityPulse() async {
    final db = await instance.database;
    final totalEvents = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM audit_logs')) ??
        0;
    final highRiskCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM audit_logs WHERE severity IN ("CRITICAL", "HIGH")')) ??
        0;
    final lastAttack = await db.query('audit_logs',
        where: 'severity = ?',
        whereArgs: ['CRITICAL'],
        orderBy: 'id DESC',
        limit: 1);

    return {
      'total': totalEvents,
      'highRisk': highRiskCount,
      'lastCritical':
          lastAttack.isNotEmpty ? lastAttack.first['timestamp'] : null,
      'status': highRiskCount > 0 ? 'WARNING' : 'SECURE',
    };
  }

  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('vitals');
      await txn.execute('VACUUM');
    });

    await logSecurityEvent(
        "DATA_WIPE", "All vital sign history cleared and database vacuumed.");
  }

  // --- PATIENT MODULE CRUD ---

  Future<void> insertPatient(User user) async {
    final db = await instance.database;
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
      decrypted['phoneNumber'] = _decrypt(json['phone_number'] as String);
      decrypted['pinCode'] = _decrypt(json['pin_code'] as String);
      // Ensure model mapping works with snake_case from DB
      return User.fromMap(decrypted);
    }).toList();
  }

  Future<User?> getPatientById(String id) async {
    final db = await database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final decrypted = Map<String, dynamic>.from(maps.first);
      decrypted['phoneNumber'] = _decrypt(maps.first['phone_number'] as String);
      decrypted['pinCode'] = _decrypt(maps.first['pin_code'] as String);
      return User.fromMap(decrypted);
    }
    return null;
  }

  Future<void> updatePatient(User user) async {
    final db = await instance.database;
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
    };
    await db.update('patients', encryptedMap,
        where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deletePatient(String id) async {
    final db = await instance.database;
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

  // --- ADMIN EXTENSION MODULES CRUD ---

  Future<void> insertAnnouncement(Map<String, dynamic> row) async {
    final db = await database;
    final Map<String, dynamic> dbRow = Map.from(row);
    if (dbRow['reactions'] is Map) {
      dbRow['reactions'] = json.encode(dbRow['reactions']);
    }
    // Defensive bool-to-int conversion
    dbRow['is_active'] =
        (dbRow['is_active'] == true || dbRow['is_active'] == 1 || dbRow['isActive'] == true || dbRow['isActive'] == 1) ? 1 : 0;
    dbRow['target_group'] = dbRow['target_group'] ?? dbRow['targetGroup'];
    dbRow['is_deleted'] =
        (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] =
        (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;

    // Remove legacy camelCase if present
    dbRow.remove('targetGroup');

    await db.insert('announcements', dbRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final db = await database;

    return await db.query('announcements',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
  }

  Future<Map<String, dynamic>?> getAnnouncementById(String id) async {
    final db = await database;
    final results =
        await db.query('announcements', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateAnnouncement(Map<String, dynamic> row) async {
    final db = await database;
    final Map<String, dynamic> dbRow = Map.from(row);
    if (dbRow['reactions'] is Map) {
      dbRow['reactions'] = json.encode(dbRow['reactions']);
    }
    await db.update('announcements', dbRow,
        where: 'id = ?', whereArgs: [dbRow['id']]);
  }

  Future<void> deleteAnnouncement(String id) async {
    final db = await database;
    await db.update(
        'announcements',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> insertSchedule(Map<String, dynamic> row) async {
    final db = await database;
    final Map<String, dynamic> dbRow = Map.from(row);
    // Defensive bool-to-int conversion
    dbRow['is_deleted'] =
        (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] =
        (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;
    dbRow['color_value'] = dbRow['color_value'] ?? dbRow['colorValue'];
    
    // Remove legacy camelCase
    dbRow.remove('colorValue');

    await db.insert('schedules', dbRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await database;
    return await db.query('schedules',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'date ASC');
  }

  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.update(
        'schedules',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getScheduleById(String id) async {
    final db = await database;
    final maps = await db.query('schedules', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> insertAlert(Map<String, dynamic> row) async {
    final db = await database;
    final Map<String, dynamic> dbRow = Map.from(row);
    // Defensive bool-to-int conversion
    dbRow['is_emergency'] =
        (dbRow['is_emergency'] == true || dbRow['is_emergency'] == 1 || dbRow['isEmergency'] == true || dbRow['isEmergency'] == 1) ? 1 : 0;
    dbRow['is_deleted'] =
        (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] =
        (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;
    dbRow['target_group'] = dbRow['target_group'] ?? dbRow['targetGroup'];

    // Remove legacy camelCase
    dbRow.remove('isEmergency');
    dbRow.remove('targetGroup');

    await db.insert('alerts', dbRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    final db = await database;
    return await db.query('alerts',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
  }

  Future<Map<String, dynamic>?> getAlertById(String id) async {
    final db = await database;
    final results = await db.query('alerts', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateAlert(Map<String, dynamic> row) async {
    final db = await database;
    final id = row['id'];
    await db.update('alerts', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAlert(String id) async {
    final db = await database;
    await db.update(
        'alerts',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAnnouncements() async {
    final db = await database;
    return await db
        .query('announcements', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAlerts() async {
    final db = await database;
    return await db.query('alerts', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSchedules() async {
    final db = await database;
    return await db.query('schedules', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedChatMessages() async {
    final db = await database;
    return await db.query('chat_messages', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<Map<String, dynamic>?> getVitalSignById(String id) async {
    final db = await database;
    final maps = await db.query('vitals', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? maps.first : null;
  }

  // --- REMINDERS (NEW) ---
  Future<int> insertReminder(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('reminders', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getReminders(String userId) async {
    final db = await database;
    return await db.query('reminders',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'time ASC');
  }

  Future<int> updateReminder(Map<String, dynamic> row) async {
    final db = await database;
    final id = row['id'];
    final Map<String, dynamic> dbRow = Map.from(row);
    if (dbRow.containsKey('userId')) {
      dbRow['user_id'] = dbRow['userId'];
      dbRow.remove('userId');
    }
    return await db.update('reminders', dbRow, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllReminders(String userId) async {
    final db = await database;
    return await db.delete('reminders', where: 'user_id = ?', whereArgs: [userId]);
  }

  // --- SYSTEM LOGS MODULE ---
  Future<void> createSystemLog(SystemLog log) async {
    final db = await instance.database;
    await db.insert('system_logs', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SystemLog>> getSystemLogs({int limit = 100}) async {
    final db = await instance.database;
    final result = await db.query('system_logs',
        orderBy: 'timestamp DESC', limit: limit);
    return result.map((json) => SystemLog.fromMap(json)).toList();
  }

  Future<List<SystemLog>> getUnsyncedSystemLogs() async {
    final db = await instance.database;
    final maps = await db.query(
      'system_logs',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => SystemLog.fromMap(map)).toList();
  }

  Future<void> markSystemLogAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'system_logs',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
