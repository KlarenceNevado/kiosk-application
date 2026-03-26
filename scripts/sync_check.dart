import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: avoid_print
// Removed unused imports

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  
  const dbPath = "C:\\Users\\Klarence Nevado\\AppData\\Roaming\\com.example\\kiosk_application\\kiosk_health.db";
  
  if (!File(dbPath).existsSync()) {
    print("❌ Database file not found at $dbPath");
    return;
  }

  final db = await databaseFactory.openDatabase(dbPath);
  
  print("--- Sync Audit Report ---");
  
  // 1. Unsynced Patients
  try {
    final patients = await db.rawQuery("SELECT COUNT(*) as count FROM patients WHERE is_synced = 0");
    print("Unsynced Patients: ${patients.first['count']}");
  } catch (e) {
    print("Error querying patients: $e");
  }

  // 2. Unsynced Vitals
  try {
    final vitals = await db.rawQuery("SELECT COUNT(*) as count FROM vitals WHERE is_synced = 0");
    print("Unsynced Vitals: ${vitals.first['count']}");
  } catch (e) {
    print("Error querying vitals: $e");
  }

  // 3. Blocked Records
  try {
    final blocked = await db.rawQuery("SELECT table_name, record_id, last_error FROM sync_metadata WHERE is_blocked = 1");
    if (blocked.isEmpty) {
      print("No blocked records found.");
    } else {
      print("Blocked Records:");
      for (var row in blocked) {
        print("  - Table: ${row['table_name']}, ID: ${row['record_id']}, Error: ${row['last_error']}");
      }
    }
  } catch (e) {
     print("Sync Metadata Info: ${e.toString().contains('no such table') ? 'No blocked records table yet.' : e}");
  }

  // 4. Schema Version
  final version = await db.getVersion();
  print("Database Schema Version: $version");

  await db.close();
  print("--- End of Report ---");
}
