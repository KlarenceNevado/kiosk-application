import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class MigrationService {
  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  /// Runs all necessary migrations for the current database version.
  Future<void> runMigrations(Database db) async {
    final currentVersion = await db.getVersion();
    debugPrint("📂 [MigrationService] Current DB Version: $currentVersion");

    // Version 1 is the initial state (already handled by onCreate).
    // We use version increments for structural changes.

    // Example: Version 2 - Snake Case Unification & Sanity Check
    if (currentVersion < 2) {
      await _migrateToVersion2(db);
      await db.setVersion(2);
    }
  }

  Future<void> _migrateToVersion2(Database db) async {
    debugPrint(
        "🚀 [MigrationService] Migrating to Version 2 (Snake Case Unification)...");

    // 1. Unify Patients Table
    await _renameColumnIfExist(
        db, 'patients', 'firstName', 'first_name', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'lastName', 'last_name', 'TEXT');
    await _renameColumnIfExist(
        db, 'patients', 'middleInitial', 'middle_initial', 'TEXT');
    await _renameColumnIfExist(
        db, 'patients', 'phoneNumber', 'phone_number', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'pinCode', 'pin_code', 'TEXT');
    await _renameColumnIfExist(
        db, 'patients', 'dateOfBirth', 'date_of_birth', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'parentId', 'parent_id', 'TEXT');
    await _renameColumnIfExist(
        db, 'patients', 'isActive', 'is_active', 'INTEGER');

    // 2. Unify Vitals Table
    await _renameColumnIfExist(db, 'vitals', 'userId', 'user_id', 'TEXT');
    await _renameColumnIfExist(db, 'vitals', 'heartRate', 'heart_rate', 'TEXT');
    await _renameColumnIfExist(
        db, 'vitals', 'systolicBP', 'systolic_bp', 'TEXT');
    await _renameColumnIfExist(
        db, 'vitals', 'diastolicBP', 'diastolic_bp', 'TEXT');
    await _renameColumnIfExist(
        db, 'vitals', 'bmiCategory', 'bmi_category', 'TEXT');
    await _renameColumnIfExist(
        db, 'vitals', 'followUpAction', 'follow_up_action', 'TEXT');

    // 3. Unify Other Tables
    await _renameColumnIfExist(
        db, 'announcements', 'targetGroup', 'target_group', 'TEXT');
    await _renameColumnIfExist(
        db, 'alerts', 'targetGroup', 'target_group', 'TEXT');
    await _renameColumnIfExist(
        db, 'alerts', 'isEmergency', 'is_emergency', 'INTEGER');
    await _renameColumnIfExist(
        db, 'schedules', 'colorValue', 'color_value', 'INTEGER');

    debugPrint("✅ [MigrationService] Version 2 migration complete.");
  }

  /// Safe helper to rename columns if they exist (using SQLite table reconstruction pattern)
  Future<void> _renameColumnIfExist(
    Database db,
    String table,
    String oldCol,
    String newCol,
    String type,
  ) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final columnNames = columns.map((c) => c['name'].toString()).toList();

      if (columnNames.contains(oldCol) && !columnNames.contains(newCol)) {
        debugPrint("🛠 [Migration] Renaming $table.$oldCol -> $newCol");
        await db.execute('ALTER TABLE $table RENAME COLUMN $oldCol TO $newCol');
      }
    } catch (e) {
      debugPrint(
          "⚠️ [Migration] Error renaming $oldCol to $newCol in $table: $e");
    }
  }

  /// Perform a deep sanity check for critical columns that might be missing across versions
  Future<void> performSanityCheck(Database db) async {
    final tables = [
      'patients',
      'vitals',
      'announcements',
      'alerts',
      'schedules',
      'reminders',
      'chat_messages'
    ];

    for (var table in tables) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final columnNames = columns.map((c) => c['name'].toString()).toList();

      // Ensure 'is_active' exists in core tables
      if (!columnNames.contains('is_active')) {
        await db.execute(
            'ALTER TABLE $table ADD COLUMN is_active INTEGER DEFAULT 1');
      }

      // Ensure 'is_synced' exists
      if (!columnNames.contains('is_synced')) {
        await db.execute(
            'ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 0');
      }
    }

    // Specific check for Patients 'created_at'
    final patientCols = await db.rawQuery('PRAGMA table_info(patients)');
    final patientColNames = patientCols.map((c) => c['name'].toString()).toList();
    if (!patientColNames.contains('created_at')) {
      await db.execute('ALTER TABLE patients ADD COLUMN created_at TEXT');
    }
    if (!patientColNames.contains('relation')) {
      await db.execute('ALTER TABLE patients ADD COLUMN relation TEXT');
    }

    // Vitals missing columns
    final vitalsCols = await db.rawQuery('PRAGMA table_info(vitals)');
    final vitalsColNames = vitalsCols.map((c) => c['name'].toString()).toList();
    if (!vitalsColNames.contains('created_at')) {
      await db.execute('ALTER TABLE vitals ADD COLUMN created_at TEXT');
      await db.execute("UPDATE vitals SET created_at = datetime('now') WHERE created_at IS NULL");
    }
    if (!vitalsColNames.contains('report_path')) {
      await db.execute('ALTER TABLE vitals ADD COLUMN report_path TEXT');
    }
    if (!vitalsColNames.contains('report_url')) {
      await db.execute('ALTER TABLE vitals ADD COLUMN report_url TEXT');
    }

    // Announcements missing columns
    final annCols = await db.rawQuery('PRAGMA table_info(announcements)');
    final annColNames = annCols.map((c) => c['name'].toString()).toList();
    if (!annColNames.contains('created_at')) {
      await db.execute('ALTER TABLE announcements ADD COLUMN created_at TEXT');
      await db.execute("UPDATE announcements SET created_at = datetime('now') WHERE created_at IS NULL");
    }
    if (!annColNames.contains('media_url')) {
      await db.execute('ALTER TABLE announcements ADD COLUMN media_url TEXT');
    }
    if (!annColNames.contains('media_path')) {
      await db.execute('ALTER TABLE announcements ADD COLUMN media_path TEXT');
    }

    // Alerts missing columns
    final alertsCols = await db.rawQuery('PRAGMA table_info(alerts)');
    if (!alertsCols.any((c) => c['name'] == 'created_at')) {
      await db.execute('ALTER TABLE alerts ADD COLUMN created_at TEXT');
      await db.execute(
          "UPDATE alerts SET created_at = datetime('now') WHERE created_at IS NULL");
    }

    // chat_messages missing columns
    final chatCols = await db.rawQuery('PRAGMA table_info(chat_messages)');
    final chatColNames = chatCols.map((c) => c['name'].toString()).toList();
    if (!chatColNames.contains('created_at')) {
      await db.execute("ALTER TABLE chat_messages ADD COLUMN created_at TEXT");
      await db.execute(
          "UPDATE chat_messages SET created_at = datetime('now') WHERE created_at IS NULL");
    }
    if (!chatColNames.contains('media_url')) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN media_url TEXT');
    }
    if (!chatColNames.contains('media_path')) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN media_path TEXT');
    }
    if (!chatColNames.contains('is_active')) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN is_active INTEGER DEFAULT 1');
    }
    if (!chatColNames.contains('patient_id')) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN patient_id TEXT');
    }
    if (!chatColNames.contains('sender')) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN sender TEXT');
    }
    if (!chatColNames.contains('message')) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN message TEXT');
    }

    // --- RECONSTRUCTION FIX FOR NOT NULL & LEGACY COLUMNS ---
    await _reconstructPatientsTable(db);
    await _reconstructVitalsTable(db);
  }

  Future<void> _reconstructPatientsTable(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(patients)');
    final colNames = cols.map((c) => c['name'].toString()).toList();

    // Check if we need reconstruction (e.g. if pin_code is NOT NULL or if we have legacy names)
    final pinCodeCol = cols.firstWhere((c) => c['name'] == 'pin_code',
        orElse: () => {'notnull': 0});
    final hasLegacy = colNames.contains('firstName') ||
        colNames.contains('lastName') ||
        colNames.contains('phoneNumber');

    if (pinCodeCol['notnull'] == 1 || hasLegacy) {
      debugPrint("🛠 [Migration] Reconstructing patients table to relax constraints...");
      await db.transaction((txn) async {
        await txn.execute('CREATE TABLE patients_new ('
            'id TEXT PRIMARY KEY, '
            'first_name TEXT, '
            'last_name TEXT, '
            'middle_initial TEXT, '
            'sitio TEXT, '
            'phone_number TEXT, '
            'pin_code TEXT, '
            'date_of_birth TEXT, '
            'gender TEXT, '
            'parent_id TEXT, '
            'avatar_url TEXT, '
            'relation TEXT, '
            'is_active INTEGER DEFAULT 1, '
            'is_synced INTEGER DEFAULT 0, '
            'is_deleted INTEGER DEFAULT 0, '
            'created_at TEXT, '
            'updated_at TEXT)');

        // Map data carefully
        final selectCols = [
          'id',
          colNames.contains('first_name') ? 'first_name' : 'firstName',
          colNames.contains('last_name') ? 'last_name' : 'lastName',
          colNames.contains('middle_initial') ? 'middle_initial' : 'middleInitial',
          'sitio',
          colNames.contains('phone_number') ? 'phone_number' : 'phoneNumber',
          colNames.contains('pin_code') ? 'pin_code' : 'pinCode',
          colNames.contains('date_of_birth') ? 'date_of_birth' : 'dateOfBirth',
          'gender',
          colNames.contains('parent_id') ? 'parent_id' : 'parentId',
          'is_active',
          'is_synced',
          colNames.contains('relation') ? 'relation' : "NULL",
          'created_at',
          'updated_at'
        ].join(', ');

        await txn.execute(
            'INSERT INTO patients_new (id, first_name, last_name, middle_initial, sitio, phone_number, pin_code, date_of_birth, gender, parent_id, is_active, is_synced, relation, created_at, updated_at) '
            'SELECT $selectCols FROM patients');

        await txn.execute('DROP TABLE patients');
        await txn.execute('ALTER TABLE patients_new RENAME TO patients');
      });
    }
  }

  Future<void> _reconstructVitalsTable(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(vitals)');
    final colNames = cols.map((c) => c['name'].toString()).toList();

    // Check if we need reconstruction (e.g. if legacy userId exists or if constraints are off)
    if (colNames.contains('userId')) {
      debugPrint("🛠 [Migration] Reconstructing vitals table to remove legacy columns...");
      await db.transaction((txn) async {
        await txn.execute('CREATE TABLE vitals_new ('
            'id TEXT PRIMARY KEY, '
            'user_id TEXT NOT NULL, '
            'timestamp TEXT NOT NULL, '
            'heart_rate TEXT, '
            'systolic_bp TEXT, '
            'diastolic_bp TEXT, '
            'oxygen TEXT, '
            'temperature TEXT, '
            'bmi REAL, '
            'bmi_category TEXT, '
            'status TEXT, '
            'remarks TEXT, '
            'follow_up_action TEXT, '
            'report_url TEXT, '
            'is_synced INTEGER DEFAULT 0, '
            'is_deleted INTEGER DEFAULT 0, '
            'created_at TEXT, '
            'updated_at TEXT)');

        // Select the correct user id content
        final uIdCol = colNames.contains('user_id') ? 'user_id' : 'userId';
        
        await txn.execute(
            'INSERT INTO vitals_new (id, user_id, timestamp, heart_rate, systolic_bp, diastolic_bp, oxygen, temperature, bmi, bmi_category, status, remarks, follow_up_action, report_url, is_synced, created_at, updated_at) '
            'SELECT id, $uIdCol, timestamp, heart_rate, systolic_bp, diastolic_bp, oxygen, temperature, bmi, bmi_category, status, remarks, follow_up_action, report_url, is_synced, created_at, updated_at FROM vitals');

        await txn.execute('DROP TABLE vitals');
        await txn.execute('ALTER TABLE vitals_new RENAME TO vitals');
      });
    }
  }
}
