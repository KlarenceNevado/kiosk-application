import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';

class VisitorSyncHandler {
  final SupabaseClient supabase;
  final dbHelper = DatabaseHelper.instance;

  VisitorSyncHandler(this.supabase);

  /// Pushes local unsynced visitors to Supabase.
  Future<void> pushUnsyncedVisitors() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> unsynced = await db.query(
        'visitors',
        where: 'is_synced = 0',
      );

      if (unsynced.isEmpty) return;

      debugPrint("🔄 [VisitorSync] Pushing ${unsynced.length} unsynced visitors...");

      for (var visitor in unsynced) {
        final Map<String, dynamic> syncData = Map.from(visitor);
        // We don't push the internal sync flag
        syncData.remove('is_synced');

        await supabase.from('visitors').upsert(syncData);

        // Mark as synced locally
        await db.update(
          'visitors',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [visitor['id']],
        );
      }
    } catch (e) {
      debugPrint("❌ [VisitorSync] Error syncing visitors: $e");
    }
  }

  /// Pushes local unsynced visitor vitals to Supabase.
  Future<void> pushUnsyncedVitals() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> unsynced = await db.query(
        'visitor_vitals',
        where: 'is_synced = 0',
      );

      if (unsynced.isEmpty) return;

      debugPrint("🔄 [VisitorSync] Pushing ${unsynced.length} unsynced visitor vitals...");

      for (var vitals in unsynced) {
        final Map<String, dynamic> syncData = Map.from(vitals);
        syncData.remove('is_synced');

        await supabase.from('visitor_vitals').upsert(syncData);

        // Mark as synced locally
        await db.update(
          'visitor_vitals',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [vitals['id']],
        );
      }
    } catch (e) {
      debugPrint("❌ [VisitorSync] Error syncing visitor vitals: $e");
    }
  }

  /// One-time migration to move any existing "local_" residents in the main 'vitals' table 
  /// into the new 'visitor_vitals' table to keep the resident data clean.
  Future<void> migrateLegacyVisitorData() async {
    try {
      final db = await dbHelper.database;
      
      // 1. Find vitals associated with local_ users (who are actually visitors)
      final List<Map<String, dynamic>> legacyVitals = await db.query(
        'vitals',
        where: "user_id LIKE 'local_%'",
      );

      if (legacyVitals.isEmpty) return;
      
      debugPrint("🧹 [VisitorSync] Migrating ${legacyVitals.length} legacy visitor records...");

      await db.transaction((txn) async {
        for (var vitals in legacyVitals) {
          final visitorId = vitals['user_id'];
          
          // Check if visitor entry exists, if not create a stub
          final List<Map<String, dynamic>> visitorCheck = await txn.query(
            'visitors',
            where: 'id = ?',
            whereArgs: [visitorId],
          );
          
          if (visitorCheck.isEmpty) {
            await txn.insert('visitors', {
              'id': visitorId,
              'first_name': 'Legacy',
              'last_name': 'Visitor',
              'created_at': vitals['timestamp'],
              'is_synced': 0,
            });
          }

          // Insert into new table
          await txn.insert('visitor_vitals', {
            'id': vitals['id'],
            'visitor_id': visitorId,
            'timestamp': vitals['timestamp'],
            'heart_rate': vitals['heart_rate'],
            'systolic_bp': vitals['systolic_bp'],
            'diastolic_bp': vitals['diastolic_bp'],
            'oxygen': vitals['oxygen'],
            'temperature': vitals['temperature'],
            'bmi': vitals['bmi'],
            'bmi_category': vitals['bmi_category'],
            'status': vitals['status'],
            'remarks': vitals['remarks'],
            'created_at': vitals['created_at'],
            'is_synced': 0,
          });

          // Remove from resident vitals table to achieve "HIWALAY" data
          await txn.delete('vitals', where: 'id = ?', whereArgs: [vitals['id']]);
        }
      });
      
      debugPrint("✅ [VisitorSync] Migration complete.");
    } catch (e) {
       debugPrint("⚠️ [VisitorSync] Migration failed: $e");
    }
  }
}
