import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: avoid_print

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final appData = Platform.environment['APPDATA'] ?? '';

  // Search multiple possible locations for the database file
  final candidates = [
    "$appData\\kiosk_application\\kiosk_health.db",
    "$appData\\com.example\\kiosk_application\\kiosk_health.db",
    "$appData\\com.islaverde\\kiosk_application\\kiosk_health.db",
  ];

  String? dbPath;
  for (final path in candidates) {
    if (File(path).existsSync()) {
      dbPath = path;
      break;
    }
  }

  if (dbPath == null) {
    // Try recursive search as fallback
    final appDataDir = Directory(appData);
    final found = appDataDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('kiosk_health.db'))
        .toList();
    if (found.isNotEmpty) {
      dbPath = found.first.path;
    }
  }

  if (dbPath == null) {
    print("❌ Database file not found in any known location under $appData");
    return;
  }

  print("📂 Database found at: $dbPath");

  final db = await databaseFactory.openDatabase(dbPath);

  print("══════════════════════════════════════════════");
  print("  SYNC DIAGNOSTIC REPORT");
  print("  Generated: ${DateTime.now().toIso8601String()}");
  print("══════════════════════════════════════════════\n");

  // ─── LAYER 1: UNSYNCED RECORD COUNTS ───
  print("── LAYER 1: UNSYNCED RECORDS ──");
  final tables = [
    'patients',
    'vitals',
    'announcements',
    'alerts',
    'schedules',
    'chat_messages'
  ];
  for (final table in tables) {
    try {
      final result = await db
          .rawQuery("SELECT COUNT(*) as count FROM $table WHERE is_synced = 0");
      final count = result.first['count'];
      final icon = (count as int) > 0 ? '⚠️' : '✅';
      print("  $icon $table: $count unsynced");
    } catch (e) {
      print("  ❌ $table: Error — $e");
    }
  }

  // ─── LAYER 2: STUCK SOFT-DELETES ───
  print("\n── LAYER 2: STUCK SOFT-DELETES (is_deleted=1 AND is_synced=0) ──");
  for (final table in tables) {
    try {
      final result = await db.rawQuery(
          "SELECT COUNT(*) as count FROM $table WHERE is_deleted = 1 AND is_synced = 0");
      final count = result.first['count'];
      final icon = (count as int) > 0 ? '🚫' : '✅';
      print("  $icon $table: $count stuck deletes");
    } catch (e) {
      print("  ❌ $table: Error — $e");
    }
  }

  // ─── LAYER 3: STALE RECORDS (>24h unsynced) ───
  print("\n── LAYER 3: STALE RECORDS (unsynced > 24 hours) ──");
  for (final table in tables) {
    try {
      final result = await db.rawQuery(
          "SELECT COUNT(*) as count FROM $table WHERE is_synced = 0 AND updated_at < datetime('now', '-1 day')");
      final count = result.first['count'];
      final icon = (count as int) > 0 ? '⏳' : '✅';
      print("  $icon $table: $count stale");
    } catch (e) {
      print("  ❌ $table: Error — $e");
    }
  }

  // ─── LAYER 4: TOTAL RECORD COUNTS ───
  print("\n── LAYER 4: TOTAL RECORD COUNTS ──");
  for (final table in tables) {
    try {
      final result = await db.rawQuery(
          "SELECT COUNT(*) as total, SUM(CASE WHEN is_deleted = 1 THEN 1 ELSE 0 END) as deleted, SUM(CASE WHEN is_synced = 1 THEN 1 ELSE 0 END) as synced FROM $table");
      final row = result.first;
      print(
          "  📊 $table: total=${row['total']}, synced=${row['synced']}, deleted=${row['deleted']}");
    } catch (e) {
      print("  ❌ $table: Error — $e");
    }
  }

  // ─── LAYER 5: SYNC METADATA / BLOCKED RECORDS ───
  print("\n── LAYER 5: BLOCKED RECORDS (sync_metadata) ──");
  try {
    final blocked = await db.rawQuery(
        "SELECT table_name, record_id, last_error, retry_count, is_blocked FROM sync_metadata WHERE is_blocked = 1 OR retry_count > 3");
    if (blocked.isEmpty) {
      print("  ✅ No blocked or high-retry records.");
    } else {
      for (var row in blocked) {
        print(
            "  🚫 Table: ${row['table_name']}, ID: ${row['record_id']}, Retries: ${row['retry_count']}, Blocked: ${row['is_blocked']}");
        print("     Error: ${row['last_error']}");
      }
    }

    final summary = await db.rawQuery(
        "SELECT table_name, COUNT(*) as pending, SUM(CASE WHEN is_blocked = 1 THEN 1 ELSE 0 END) as blocked FROM sync_metadata GROUP BY table_name");
    if (summary.isNotEmpty) {
      print("  ── Metadata Summary ──");
      for (var row in summary) {
        print(
            "    ${row['table_name']}: ${row['pending']} pending, ${row['blocked']} blocked");
      }
    }
  } catch (e) {
    final msg = e.toString().contains('no such table')
        ? 'sync_metadata table does not exist yet (OK if first run).'
        : e.toString();
    print("  ℹ️ $msg");
  }

  // ─── LAYER 6: DATABASE VERSION ───
  print("\n── LAYER 6: DATABASE INFO ──");
  final version = await db.getVersion();
  print("  Schema Version: $version");
  final fileSize = File(dbPath).lengthSync();
  print("  File Size: ${(fileSize / 1024).toStringAsFixed(1)} KB");

  await db.close();
  print("\n══════════════════════════════════════════════");
  print("  END OF SYNC DIAGNOSTIC REPORT");
  print("══════════════════════════════════════════════");
}
