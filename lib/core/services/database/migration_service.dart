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
    debugPrint("🚀 [MigrationService] Migrating to Version 2 (Snake Case Unification)...");
    
    // 1. Unify Patients Table
    await _renameColumnIfExist(db, 'patients', 'firstName', 'first_name', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'lastName', 'last_name', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'middleInitial', 'middle_initial', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'phoneNumber', 'phone_number', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'pinCode', 'pin_code', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'dateOfBirth', 'date_of_birth', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'parentId', 'parent_id', 'TEXT');
    await _renameColumnIfExist(db, 'patients', 'isActive', 'is_active', 'INTEGER');

    // 2. Unify Vitals Table
    await _renameColumnIfExist(db, 'vitals', 'userId', 'user_id', 'TEXT');
    await _renameColumnIfExist(db, 'vitals', 'heartRate', 'heart_rate', 'TEXT');
    await _renameColumnIfExist(db, 'vitals', 'systolicBP', 'systolic_bp', 'TEXT');
    await _renameColumnIfExist(db, 'vitals', 'diastolicBP', 'diastolic_bp', 'TEXT');
    await _renameColumnIfExist(db, 'vitals', 'bmiCategory', 'bmi_category', 'TEXT');
    await _renameColumnIfExist(db, 'vitals', 'followUpAction', 'follow_up_action', 'TEXT');

    // 3. Unify Other Tables
    await _renameColumnIfExist(db, 'announcements', 'targetGroup', 'target_group', 'TEXT');
    await _renameColumnIfExist(db, 'alerts', 'targetGroup', 'target_group', 'TEXT');
    await _renameColumnIfExist(db, 'alerts', 'isEmergency', 'is_emergency', 'INTEGER');
    await _renameColumnIfExist(db, 'schedules', 'colorValue', 'color_value', 'INTEGER');
    
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
      debugPrint("⚠️ [Migration] Error renaming $oldCol to $newCol in $table: $e");
    }
  }

  /// Perform a deep sanity check for critical columns that might be missing across versions
  Future<void> performSanityCheck(Database db) async {
    final tables = ['patients', 'vitals', 'announcements', 'alerts', 'schedules', 'reminders'];
    
    for (var table in tables) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final columnNames = columns.map((c) => c['name'].toString()).toList();
      
      // Ensure 'is_active' exists in core tables
      if (!columnNames.contains('is_active')) {
         await db.execute('ALTER TABLE $table ADD COLUMN is_active INTEGER DEFAULT 1');
      }
      
      // Ensure 'is_synced' exists
      if (!columnNames.contains('is_synced')) {
         await db.execute('ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 0');
      }
    }
    
    // Specific check for Patients 'created_at'
    final patientCols = await db.rawQuery('PRAGMA table_info(patients)');
    if (!patientCols.any((c) => c['name'] == 'created_at')) {
       await db.execute('ALTER TABLE patients ADD COLUMN created_at TEXT');
    }

    // Vitals missing columns
    final vitalsCols = await db.rawQuery('PRAGMA table_info(vitals)');
    final vitalsColNames = vitalsCols.map((c) => c['name'].toString()).toList();
    if (!vitalsColNames.contains('created_at')) {
       await db.execute('ALTER TABLE vitals ADD COLUMN created_at TEXT DEFAULT (datetime(''now''))');
    }
    if (!vitalsColNames.contains('report_path')) {
       await db.execute('ALTER TABLE vitals ADD COLUMN report_path TEXT');
    }
    if (!vitalsColNames.contains('report_url')) {
       await db.execute('ALTER TABLE vitals ADD COLUMN report_url TEXT');
    }

    // Announcements missing columns
    final annCols = await db.rawQuery('PRAGMA table_info(announcements)');
    if (!annCols.any((c) => c['name'] == 'created_at')) {
       await db.execute('ALTER TABLE announcements ADD COLUMN created_at TEXT DEFAULT (datetime(''now''))');
    }

    // Alerts missing columns
    final alertsCols = await db.rawQuery('PRAGMA table_info(alerts)');
    if (!alertsCols.any((c) => c['name'] == 'created_at')) {
       await db.execute('ALTER TABLE alerts ADD COLUMN created_at TEXT DEFAULT (datetime(''now''))');
    }
  }
}
