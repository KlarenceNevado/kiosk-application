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

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDB('kiosk_health.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // 1. Get a shared absolute path for both apps to use
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, filePath);

    debugPrint("Database Path Unified: $path");

    // Ensure Encryption is active before any DB operations occur
    await EncryptionService().init();

    return await openDatabase(
      path,
      version: 13, // BUMPED TO 13 FOR PATIENT ARCHIVING
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // Patients Table
    await db.execute('''
    CREATE TABLE patients (
      id TEXT PRIMARY KEY,
      firstName TEXT NOT NULL,
      lastName TEXT NOT NULL,
      middleInitial TEXT,
      sitio TEXT NOT NULL,
      phoneNumber TEXT NOT NULL,
      pinCode TEXT NOT NULL,
      gender TEXT NOT NULL,
      dateOfBirth TEXT NOT NULL,
      parentId TEXT,
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0
    )
    ''');

    // Vitals Table
    await db.execute('''
    CREATE TABLE vitals (
      id TEXT PRIMARY KEY,
      userId TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      heartRate TEXT NOT NULL,
      systolicBP TEXT NOT NULL,
      diastolicBP TEXT NOT NULL,
      oxygen TEXT NOT NULL,
      temperature TEXT NOT NULL,
      bmi REAL,
      bmiCategory TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      remarks TEXT,
      followUpAction TEXT,
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
      targetGroup TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
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
      colorValue INTEGER NOT NULL,
      updated_at TEXT DEFAULT (datetime('now')),
      is_deleted INTEGER DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 1
    )
    ''');

    // Alerts Table
    await db.execute('''
    CREATE TABLE alerts (
      id TEXT PRIMARY KEY,
      message TEXT NOT NULL,
      targetGroup TEXT NOT NULL,
      isEmergency INTEGER NOT NULL DEFAULT 0,
      timestamp TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
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
  }

  // Handle schema changes cleanly
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        middleInitial TEXT,
        sitio TEXT NOT NULL,
        phoneNumber TEXT NOT NULL,
        pinCode TEXT NOT NULL,
        gender TEXT NOT NULL,
        dateOfBirth TEXT NOT NULL,
        parentId TEXT,
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
        await db.execute(
            'ALTER TABLE patients ADD COLUMN isActive INTEGER DEFAULT 1');
        debugPrint("✅ Added isActive column to patients");
      } catch (e) {
        debugPrint("⚠️ Error adding isActive to patients: $e");
      }
      debugPrint("🚀 Database Upgraded to Version 13 (Patient Archiving)");
    }
  }

  // --- ENCRYPTION HELPERS ---
  String _encrypt(dynamic value) {
    if (value == null) return '';
    return EncryptionService().encryptData(value.toString());
  }

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
      'userId': map['userId'],
      'timestamp': map['timestamp'],
      'heartRate': _encrypt(map['heartRate']),
      'systolicBP': _encrypt(map['systolicBP']),
      'diastolicBP': _encrypt(map['diastolicBP']),
      'oxygen': _encrypt(map['oxygen']),
      'temperature': _encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmiCategory': map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'followUpAction': map['followUpAction'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'is_synced': 0
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
      'userId': map['userId'],
      'timestamp': map['timestamp'],
      'heartRate': _encrypt(map['heartRate']),
      'systolicBP': _encrypt(map['systolicBP']),
      'diastolicBP': _encrypt(map['diastolicBP']),
      'oxygen': _encrypt(map['oxygen']),
      'temperature': _encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmiCategory': map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'followUpAction': map['followUpAction'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': map['is_deleted'] ?? 0,
      'is_synced': map['isSynced'] ?? 0
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
      'userId': map['userId'],
      'timestamp': map['timestamp'],
      'heartRate': _encrypt(map['heartRate']),
      'systolicBP': _encrypt(map['systolicBP']),
      'diastolicBP': _encrypt(map['diastolicBP']),
      'oxygen': _encrypt(map['oxygen']),
      'temperature': _encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmiCategory': map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'followUpAction': map['followUpAction'],
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'is_synced': 0 // Need to sync changes
    };

    await db.update('vitals', encryptedMap,
        where: 'id = ?', whereArgs: [record.id]);
  }

  VitalSigns _parseVitalSigns(Map<String, dynamic> json) {
    try {
      // Helper to handle both encrypted (String) and legacy (int/double) data
      int getInt(dynamic val) {
        if (val is int) return val;
        try {
          return _decryptInt(val as String);
        } catch (_) {
          return int.tryParse(val.toString()) ?? 0;
        }
      }

      double getDouble(dynamic val) {
        if (val is double) return val;
        if (val is int) return val.toDouble();
        try {
          return _decryptDouble(val as String);
        } catch (_) {
          return double.tryParse(val.toString()) ?? 0.0;
        }
      }

      return VitalSigns(
        id: json['id'],
        userId: json['userId'],
        timestamp: DateTime.parse(json['timestamp']),
        heartRate: getInt(json['heartRate']),
        systolicBP: getInt(json['systolicBP']),
        diastolicBP: getInt(json['diastolicBP']),
        oxygen: getInt(json['oxygen']),
        temperature: getDouble(json['temperature']),
        bmi: json['bmi'] is String
            ? double.tryParse(json['bmi'])
            : (json['bmi'] as num?)?.toDouble(),
        bmiCategory: json['bmiCategory'],
        status: json['status'] ?? 'pending',
        remarks: json['remarks'],
        followUpAction: json['followUpAction'],
      );
    } catch (e) {
      debugPrint("Error parsing vital signs: $e");
      return VitalSigns.fromMap(json);
    }
  }

  Future<List<VitalSigns>> getRecordsByUserId(String userId) async {
    final db = await instance.database;
    final result = await db.query('vitals',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<List<VitalSigns>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query('vitals',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
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
      decrypted['phoneNumber'] = _decrypt(map['phoneNumber'] as String);
      decrypted['pinCode'] = _decrypt(map['pinCode'] as String);
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
      'firstName': map['firstName'],
      'lastName': map['lastName'],
      'middleInitial': map['middleInitial'],
      'sitio': map['sitio'],
      'phoneNumber': _encrypt(map['phoneNumber']),
      'pinCode': _encrypt(map['pinCode']),
      'gender': map['gender'],
      'dateOfBirth': map['dateOfBirth'],
      'parentId': map['parentId'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted':
          (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'isActive': (map['isActive'] == true || map['isActive'] == 1) ? 1 : 0,
      'is_synced': (map['is_synced'] == true || map['is_synced'] == 1) ? 1 : 0,
    };

    await db.insert('patients', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getPatients() async {
    final db = await instance.database;
    final result = await db.query('patients',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'lastName ASC');
    return result.map((json) {
      final decrypted = Map<String, dynamic>.from(json);
      decrypted['phoneNumber'] = _decrypt(json['phoneNumber'] as String);
      decrypted['pinCode'] = _decrypt(json['pinCode'] as String);
      return User.fromMap(decrypted);
    }).toList();
  }

  Future<User?> getPatientById(String id) async {
    final db = await instance.database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final decrypted = Map<String, dynamic>.from(maps.first);
      decrypted['phoneNumber'] = _decrypt(maps.first['phoneNumber'] as String);
      decrypted['pinCode'] = _decrypt(maps.first['pinCode'] as String);
      return User.fromMap(decrypted);
    }
    return null;
  }

  Future<void> updatePatient(User user) async {
    final db = await instance.database;
    final map = user.toMap();
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'firstName': map['firstName'],
      'lastName': map['lastName'],
      'middleInitial': map['middleInitial'],
      'sitio': map['sitio'],
      'phoneNumber': _encrypt(map['phoneNumber']),
      'pinCode': _encrypt(map['pinCode']),
      'gender': map['gender'],
      'dateOfBirth': map['dateOfBirth'],
      'parentId': map['parentId'],
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted':
          (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'isActive': (map['isActive'] == true || map['isActive'] == 1) ? 1 : 0,
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
    final db = await instance.database;
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
    final db = await instance.database;
    final Map<String, dynamic> dbRow = Map.from(row);
    if (dbRow['reactions'] is Map) {
      dbRow['reactions'] = json.encode(dbRow['reactions']);
    }
    // Defensive bool-to-int conversion
    dbRow['isActive'] =
        (dbRow['isActive'] == true || dbRow['isActive'] == 1) ? 1 : 0;
    dbRow['is_deleted'] =
        (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] =
        (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;

    await db.insert('announcements', dbRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final db = await instance.database;
    return await db.query('announcements',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
  }

  Future<Map<String, dynamic>?> getAnnouncementById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'announcements',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> updateAnnouncement(Map<String, dynamic> row) async {
    final db = await instance.database;
    final Map<String, dynamic> dbRow = Map.from(row);
    if (dbRow['reactions'] is Map) {
      dbRow['reactions'] = json.encode(dbRow['reactions']);
    }
    await db.update('announcements', dbRow,
        where: 'id = ?', whereArgs: [dbRow['id']]);
  }

  Future<void> deleteAnnouncement(String id) async {
    final db = await instance.database;
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
    final db = await instance.database;
    final Map<String, dynamic> dbRow = Map.from(row);
    // Defensive bool-to-int conversion
    dbRow['is_deleted'] =
        (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] =
        (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;

    await db.insert('schedules', dbRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await instance.database;
    return await db.query('schedules',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'date ASC');
  }

  Future<void> deleteSchedule(String id) async {
    final db = await instance.database;
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

  Future<void> insertAlert(Map<String, dynamic> row) async {
    final db = await instance.database;
    final Map<String, dynamic> dbRow = Map.from(row);
    // Defensive bool-to-int conversion
    dbRow['isEmergency'] =
        (dbRow['isEmergency'] == true || dbRow['isEmergency'] == 1) ? 1 : 0;
    dbRow['is_deleted'] =
        (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] =
        (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;

    await db.insert('alerts', dbRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    final db = await instance.database;
    return await db.query('alerts',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
  }

  Future<void> updateAlert(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'];
    await db.update('alerts', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAlert(String id) async {
    final db = await instance.database;
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
    final db = await instance.database;
    return await db
        .query('announcements', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAlerts() async {
    final db = await instance.database;
    return await db.query('alerts', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSchedules() async {
    final db = await instance.database;
    return await db.query('schedules', where: 'is_synced = ?', whereArgs: [0]);
  }
}
