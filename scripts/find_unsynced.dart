// ignore_for_file: avoid_print
// Removed unused import
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  const dbPath = "C:\\Users\\Klarence Nevado\\AppData\\Roaming\\com.example\\kiosk_application\\kiosk_health.db";
  final db = await databaseFactory.openDatabase(dbPath);
  
  final unsynced = await db.query('vitals', where: 'is_synced = 0');
  if (unsynced.isEmpty) {
    print("✅ No unsynced vitals found.");
  } else {
    print("⚠️ Found ${unsynced.length} unsynced vitals:");
    for (var row in unsynced) {
      print("  - ID: ${row['id']}, UserID: ${row['user_id']}, Timestamp: ${row['timestamp']}");
    }
  }
  
  await db.close();
}
