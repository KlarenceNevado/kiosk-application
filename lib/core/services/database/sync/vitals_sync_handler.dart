import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'sync_handler.dart';
import '../../../../features/health_check/models/vital_signs_model.dart';
import '../../system/sync_event_bus.dart';

class VitalsSyncHandler extends SyncHandler {
  RealtimeChannel? _channel;
  
  final _changeController = StreamController<void>.broadcast();
  Stream<void> get stream => _changeController.stream;

  final _newRecordController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newRecordStream => _newRecordController.stream;

  VitalsSyncHandler(super.supabase);

  @override
  Future<void> push() async {
    try {
      final blockedIds = await dbHelper.getBlockedRecords('vitals');
      final unsyncedVitals = await dbHelper.getUnsyncedRecords();
      if (unsyncedVitals.isEmpty) {
        return;
      }

      final results = await Future.wait(unsyncedVitals.map((vital) async {
        if (blockedIds.contains(vital.id)) {
          return null;
        }
        try {
          final success = await _upsertVitalSign(vital);
          if (success) {
            await dbHelper.clearSyncMetadata('vitals', vital.id);
            return vital.id;
          } else {
            await dbHelper.updateSyncMetadata(tableName: 'vitals', recordId: vital.id, error: 'Push failed', incrementRetry: true);
            return null;
          }
        } catch (e) {
           await dbHelper.updateSyncMetadata(tableName: 'vitals', recordId: vital.id, error: e.toString(), incrementRetry: true);
           return null;
        }
      }));

      final syncedIds = results.whereType<String>().toList();
      if (syncedIds.isNotEmpty) {
        await dbHelper.markBatchAsSynced('vitals', syncedIds);
        _changeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ VitalsSyncHandler: Push Error: $e");
    }
  }

  @override
  Future<void> pull() async {
    try {
      final lastSync = await _getLastSync();
      var query = supabase.from('vitals').select();
      if (lastSync != null) {
        query = query.gt('updated_at', lastSync);
      }

      final cloudVitals = await query.order('updated_at', ascending: true);
      String? latestTimestamp;
      bool anyNew = false;
      Map<String, dynamic>? latestNew;

      if (cloudVitals.isNotEmpty) {
        final db = await dbHelper.database;
        final batch = db.batch();
        for (var row in cloudVitals) {
          final exists = await dbHelper.getVitalSignById(row['id']);
          if (exists == null) {
            anyNew = true;
            latestNew = row;
          }
          final prepared = _prepareRowForSqlite(row);
          batch.insert('vitals', prepared, conflictAlgorithm: ConflictAlgorithm.replace);
          latestTimestamp = row['updated_at'];
        }
        await batch.commit(noResult: true);
      }

      if (latestTimestamp != null) {
        await _updateLastSync(latestTimestamp);
        _changeController.add(null);
        if (anyNew && latestNew != null) {
          _newRecordController.add(latestNew);
        }
      }
    } catch (e) {
      debugPrint("❌ VitalsSyncHandler: Pull Error: $e");
    }
  }

  void subscribe(void Function(PostgresChangePayload payload) onData) {
    if (_channel != null) {
      return;
    }
    _channel = supabase.channel('public:vitals_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'vitals',
      callback: (payload) {
        onData(payload);
        _changeController.add(null);
        SyncEventBus.instance.triggerVitalsUpdate();
      },
    ).subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  // --- CRUD HELPERS ---

  Future<bool> _upsertVitalSign(VitalSigns vital) async {
    try {
      final Map<String, dynamic> supabaseData = {
        'id': vital.id,
        'user_id': vital.userId,
        'timestamp': vital.timestamp.toIso8601String(),
        'heart_rate': dbHelper.encrypt(vital.heartRate),
        'systolic_bp': dbHelper.encrypt(vital.systolicBP),
        'diastolic_bp': dbHelper.encrypt(vital.diastolicBP),
        'oxygen': dbHelper.encrypt(vital.oxygen),
        'temperature': dbHelper.encrypt(vital.temperature),
        'bmi': vital.bmi,
        'bmi_category': vital.bmiCategory,
        'status': vital.status,
        'remarks': vital.remarks,
        'follow_up_action': vital.followUpAction,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await supabase.from('vitals').upsert(supabaseData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> createVitalSign(VitalSigns vital) async {
    try {
      final Map<String, dynamic> supabaseData = {
        'id': vital.id,
        'user_id': vital.userId,
        'timestamp': vital.timestamp.toIso8601String(),
        'heart_rate': dbHelper.encrypt(vital.heartRate),
        'systolic_bp': dbHelper.encrypt(vital.systolicBP),
        'diastolic_bp': dbHelper.encrypt(vital.diastolicBP),
        'oxygen': dbHelper.encrypt(vital.oxygen),
        'temperature': dbHelper.encrypt(vital.temperature),
        'bmi': vital.bmi,
        'bmi_category': vital.bmiCategory,
        'status': vital.status,
        'remarks': vital.remarks,
        'follow_up_action': vital.followUpAction,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await supabase.from('vitals').insert(supabaseData);
    } catch (e) {
      debugPrint("⚠️ VitalsSyncHandler: Create failed. $e");
    }
  }

  Future<void> updateVitalSign(VitalSigns vital) async {
    try {
      final Map<String, dynamic> supabaseData = {
        'heart_rate': dbHelper.encrypt(vital.heartRate),
        'systolic_bp': dbHelper.encrypt(vital.systolicBP),
        'diastolic_bp': dbHelper.encrypt(vital.diastolicBP),
        'oxygen': dbHelper.encrypt(vital.oxygen),
        'temperature': dbHelper.encrypt(vital.temperature),
        'bmi': vital.bmi,
        'status': vital.status,
        'remarks': vital.remarks,
        'follow_up_action': vital.followUpAction,
      };
      await supabase.from('vitals').update(supabaseData).eq('id', vital.id);
    } catch (e) {
      debugPrint("⚠️ VitalsSyncHandler: Update failed. $e");
    }
  }

  Future<List<VitalSigns>> fetchPatientVitals(String userId) async {
    try {
      final data = await supabase.from('vitals').select().eq('user_id', userId).order('timestamp', ascending: false);
      return data.map((json) => VitalSigns.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<VitalSigns>> fetchPatientVitalsLocal(String userId) async {
    return await dbHelper.getRecordsByUserId(userId);
  }

  Future<void> syncFamilyVitals(List<String> familyIds) async {
    if (familyIds.isEmpty) {
      return;
    }
    try {
      final data = await supabase.from('vitals').select().filter('user_id', 'in', familyIds).order('updated_at', ascending: true);
      if (data.isNotEmpty) {
        final db = await dbHelper.database;
        final batch = db.batch();
        for (var row in data) {
          final prepared = _prepareRowForSqlite(row);
          prepared['is_synced'] = 1;
          batch.insert('vitals', prepared, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        _changeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ VitalsSyncHandler: syncFamilyVitals Error: $e");
    }
  }

  // --- PRIVATE HELPERS ---

  Future<String?> _getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_vitals');
  }

  Future<void> _updateLastSync(String? timestamp) async {
    if (timestamp == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_vitals', timestamp);
  }

  Map<String, dynamic> _prepareRowForSqlite(Map<String, dynamic> row) {
    final prepared = Map<String, dynamic>.from(row);
    prepared.forEach((key, value) {
      if (value is bool) {
        prepared[key] = value ? 1 : 0;
      }
    });

    // Decrypt fields if they are strings (it means they were pulled from cloud as ciphertext)
    // The BaseDao.encrypt handles the check to avoid double-processing.
    final fieldsToDecrypt = ['heart_rate', 'systolic_bp', 'diastolic_bp', 'oxygen', 'temperature'];
    for (final field in fieldsToDecrypt) {
      if (prepared[field] != null && prepared[field] is String) {
        // We set it back to the map; the DAO's _parseVitalSigns will handle further conversion to int/double
        prepared[field] = dbHelper.decrypt(prepared[field]);
      }
    }

    return prepared;
  }
}
