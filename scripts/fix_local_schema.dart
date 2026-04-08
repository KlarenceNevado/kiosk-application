// ignore_for_file: avoid_print
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  const dbPath =
      "C:\\Users\\Klarence Nevado\\AppData\\Roaming\\com.example\\kiosk_application\\kiosk_health.db";

  if (!File(dbPath).existsSync()) {
    print("❌ Database not found.");
    return;
  }

  final db = await dbFactory.openDatabase(dbPath);

  print("🛠️ Starting Local Schema Alignment...");

  Future<void> renameColumn(
      String table, String oldName, String newName, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    bool hasOld = columns.any((c) => c['name'] == oldName);
    bool hasNew = columns.any((c) => c['name'] == newName);

    if (hasOld && !hasNew) {
      print("  Renaming $table.$oldName to $newName...");
      // SQLite doesn't support RENAME COLUMN in older versions, so we use ALTER TABLE RENAME if possible
      // But standard way is:
      try {
        await db
            .execute('ALTER TABLE $table RENAME COLUMN $oldName TO $newName');
        print("  ✅ Done.");
      } catch (e) {
        print(
            "  ⚠️ Failed to rename via ALTER: $e. Using fallback (Add + Copy + Drop not possible here easily).");
      }
    } else if (hasNew) {
      print("  ✅ $table.$newName already exists.");
    }
  }

  // 1. Unify Patients
  await renameColumn('patients', 'firstName', 'first_name', 'TEXT');
  await renameColumn('patients', 'lastName', 'last_name', 'TEXT');
  await renameColumn('patients', 'middleInitial', 'middle_initial', 'TEXT');
  await renameColumn('patients', 'phoneNumber', 'phone_number', 'TEXT');
  await renameColumn('patients', 'pinCode', 'pin_code', 'TEXT');
  await renameColumn('patients', 'dateOfBirth', 'date_of_birth', 'TEXT');
  await renameColumn('patients', 'parentId', 'parent_id', 'TEXT');

  // 2. Unify Vitals
  await renameColumn('vitals', 'userId', 'user_id', 'TEXT');
  await renameColumn('vitals', 'heartRate', 'heart_rate', 'TEXT');
  await renameColumn('vitals', 'systolicBP', 'systolic_bp', 'TEXT');
  await renameColumn('vitals', 'diastolicBP', 'diastolic_bp', 'TEXT');
  await renameColumn('vitals', 'bmiCategory', 'bmi_category', 'TEXT');
  await renameColumn('vitals', 'followUpAction', 'follow_up_action', 'TEXT');

  // 3. Ensure other columns exist for sync
  final vitalCols = await db.rawQuery('PRAGMA table_info(vitals)');
  if (!vitalCols.any((c) => c['name'] == 'is_synced')) {
    await db
        .execute('ALTER TABLE vitals ADD COLUMN is_synced INTEGER DEFAULT 0');
  }
  if (!vitalCols.any((c) => c['name'] == 'updated_at')) {
    await db.execute('ALTER TABLE vitals ADD COLUMN updated_at TEXT');
  }
  if (!vitalCols.any((c) => c['name'] == 'is_deleted')) {
    await db
        .execute('ALTER TABLE vitals ADD COLUMN is_deleted INTEGER DEFAULT 0');
  }

  await db.close();
  print("🏁 Schema Alignment complete.");
}
