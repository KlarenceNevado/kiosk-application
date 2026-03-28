import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kiosk_application/core/services/security/security_logger.dart';
import 'sync_handler.dart';
import '../../../../features/auth/models/user_model.dart';
import '../../system/sync_event_bus.dart';

class PatientSyncHandler extends SyncHandler {
  RealtimeChannel? _channel;
  final _changeController = StreamController<void>.broadcast();
  
  Stream<void> get stream => _changeController.stream;

  PatientSyncHandler(super.supabase);

  @override
  Future<void> push() async {
    try {
      final blockedIds = await dbHelper.getBlockedRecords('patients');
      final unsynced = await dbHelper.getUnsyncedPatients();
      if (unsynced.isEmpty) {
        return;
      }

      final List<String> syncedIds = [];
      for (final user in unsynced) {
        if (blockedIds.contains(user.id)) {
          continue;
        }

        try {
          final updatedUser = await createPatient(user);
          if (updatedUser != null && updatedUser.isSynced) {
            syncedIds.add(updatedUser.id);
            await dbHelper.clearSyncMetadata('patients', updatedUser.id);
          } else {
            await dbHelper.updateSyncMetadata(tableName: 'patients', recordId: user.id, error: 'Push failed', incrementRetry: true);
          }
        } catch (e) {
          await dbHelper.updateSyncMetadata(tableName: 'patients', recordId: user.id, error: e.toString(), incrementRetry: true);
        }
      }

      if (syncedIds.isNotEmpty) {
        await dbHelper.markBatchAsSynced('patients', syncedIds);
        _changeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ PatientSyncHandler: Push Error: $e");
    }
  }

  @override
  Future<void> pull() async {
    try {
      final lastSync = await _getLastSync();
      var query = supabase.from('patients').select();

      if (lastSync != null) {
        final overlapTime = DateTime.parse(lastSync).toUtc().subtract(const Duration(minutes: 5));
        query = query.gt('updated_at', overlapTime.toUtc().toIso8601String());
      }

      final cloudPatients = await query.order('updated_at', ascending: true);
      String? latestTimestamp;

      if (cloudPatients.isNotEmpty) {
        final db = await dbHelper.database;
        final batch = db.batch();

        for (var row in cloudPatients) {
          final preparedRow = _prepareRowForSqlite(row);
          batch.insert('patients', preparedRow, conflictAlgorithm: ConflictAlgorithm.replace);
          latestTimestamp = row['updated_at'];
        }
        await batch.commit(noResult: true);
      }

      if (latestTimestamp != null) {
        await _updateLastSync(latestTimestamp);
        _changeController.add(null);
      }
    } catch (e) {
      debugPrint("❌ PatientSyncHandler: Pull Error: $e");
    }
  }

  void subscribe(void Function(PostgresChangePayload payload) onData) {
    if (_channel != null) {
      return;
    }
    _channel = supabase.channel('public:patients_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'patients',
      callback: (payload) {
        onData(payload);
        _changeController.add(null);
        SyncEventBus.instance.triggerPatientUpdate();
      },
    ).subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  // --- CRUD HELPERS ---

  Future<User?> createPatient(User user) async {
    final String birthDate = user.dateOfBirth.toIso8601String().split('T')[0];
    
    final Map<String, dynamic> supabaseData = {
      'id': user.id,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'middle_initial': user.middleInitial,
      'sitio': user.sitio,
      'phone_number': dbHelper.encrypt(user.phoneNumber),
      'gender': user.gender,
      'date_of_birth': birthDate,
      'parent_id': user.parentId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Validation: Supabase 'patients' table ID is a UUID. 
    // If the account has a 'local_' prefix (legacy/guest), it cannot be pushed to cloud.
    if (user.id.startsWith('local_')) {
      SecurityLogger.info("Sync: Skipping Supabase push for legacy/local user ID: ${user.id}");
      // Mark as synced so it doesn't re-appear in getUnsyncedPatients every cycle
      await dbHelper.insertPatient(user.copyWith(isSynced: true));
      return user.copyWith(isSynced: true);
    }

    try {
      await supabase.from('patients').upsert(supabaseData);
      
      final syncedUser = user.copyWith(isSynced: true, updatedAt: DateTime.now());
      await dbHelper.insertPatient(syncedUser);
      SecurityLogger.info("Sync: Successfully pushed patient ${user.id} to Supabase.");
      return syncedUser;
    } catch (e) {
      SecurityLogger.error("Sync: Failed to push patient ${user.id} to Supabase: $e");
      
      final offlineUser = user.copyWith(isSynced: false);
      await dbHelper.insertPatient(offlineUser);
      return offlineUser;
    }
  }

  Future<bool> updatePatient(User user) async {
    final String birthDate = user.dateOfBirth.toIso8601String().split('T')[0];
    try {
      final Map<String, dynamic> supabaseData = {
        'first_name': user.firstName,
        'last_name': user.lastName,
        'middle_initial': user.middleInitial,
        'sitio': user.sitio,
        'phone_number': dbHelper.encrypt(user.phoneNumber),
        'date_of_birth': birthDate,
        'gender': user.gender,
        'parent_id': user.parentId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await supabase.from('patients').update(supabaseData).eq('id', user.id);
      await dbHelper.updatePatient(user.copyWith(isSynced: true));
      return true;
    } catch (e) {
      await dbHelper.updatePatient(user.copyWith(isSynced: false));
      return false;
    }
  }

  Future<bool> deletePatient(String userId) async {
    try {
      await dbHelper.deletePatient(userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<User>> searchPatients(String query) async {
    if (query.isEmpty) {
      return [];
    }
    try {
      final db = await dbHelper.database;
      final localData = await db.query('patients', where: 'first_name LIKE ? OR last_name LIKE ?', whereArgs: ['%$query%', '%$query%'], limit: 10);
      final List<User> localUsers = localData.map((json) => User.fromMap(json)).toList();

      final cloudData = await supabase.from('patients').select().or('first_name.ilike.%$query%,last_name.ilike.%$query%').limit(10);
      final List<User> cloudUsers = cloudData.map((json) => User.fromMap(json)).toList();

      final Map<String, User> merged = {};
      for (final u in localUsers) {
        merged[u.id] = u;
      }
      for (final u in cloudUsers) {
        merged[u.id] = u;
      }
      return merged.values.toList();
    } catch (e) {
      return [];
    }
  }

  Future<User?> authenticatePatient(String phone, String pin) async {
    try {
      // NOTE: We cannot use .eq('phone_number') due to randomized IVs.
      // Strategy: Fetch a recent batch and scan locally (Decryption happens in memory).
      final data = await supabase.from('patients').select().limit(50);

      if (data.isNotEmpty) {
        for (var row in data) {
          final dbEncPhone = row['phone_number']?.toString();
          final dbEncPin = row['pin_code']?.toString();
          if (dbEncPhone == null || dbEncPin == null) continue;

          try {
            final decPhone = dbHelper.decrypt(dbEncPhone);
            final decPin = dbHelper.decrypt(dbEncPin);

            if (decPhone == phone.trim() && decPin == pin.trim()) {
              final decryptedRow = Map<String, dynamic>.from(row);
              decryptedRow['phone_number'] = decPhone;
              decryptedRow['pin_code'] = decPin;
              return User.fromMap(decryptedRow);
            }
          } catch (_) {
            continue; // Skip stale or unreadable data
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ authenticatePatient Error: $e");
      return null;
    }
  }


  Future<List<User>> fetchDependents(String parentId) async {
    try {
      final data = await supabase.from('patients').select().eq('parent_id', parentId);
      return data.map((json) => User.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> findPatient(String nameInput, String phoneNumber) async {
    try {
      // Strategy: Search by Name (Plain Text) then decrypt found phone numbers to match input
      final results = await supabase
          .from('patients')
          .select()
          .or('first_name.ilike.%$nameInput%,last_name.ilike.%$nameInput%')
          .limit(10);

      final List<Map<String, dynamic>> matches = [];
      for (var row in results) {
        final dbEncPhone = row['phone_number']?.toString();
        if (dbEncPhone == null) continue;

        try {
          final decPhone = dbHelper.decrypt(dbEncPhone);
          if (decPhone == phoneNumber.trim()) {
            final preparedRow = Map<String, dynamic>.from(row);
            preparedRow['phone_number'] = decPhone; // Use plain for AuthRepo logic
            matches.add(preparedRow);
          }
        } catch (_) {}
      }
      return matches;
    } catch (e) {
      debugPrint("❌ findPatient (Cloud) Error: $e");
      return [];
    }
  }


  // --- PRIVATE HELPERS ---

  Future<String?> _getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_patients');
  }

  Future<void> _updateLastSync(String? timestamp) async {
    if (timestamp == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_patients', timestamp);
  }

  /// Known local SQLite columns for the 'patients' table.
  /// Any extra columns from Supabase are stripped to prevent INSERT crashes.
  static const _knownPatientColumns = {
    'id', 'first_name', 'last_name', 'middle_initial', 'sitio',
    'phone_number', 'pin_code', 'date_of_birth', 'gender', 'parent_id',
    'avatar_url', 'relation', 'is_active', 'is_synced', 'is_deleted',
    'created_at', 'updated_at',
  };

  Map<String, dynamic> _prepareRowForSqlite(Map<String, dynamic> row) {
    final prepared = Map<String, dynamic>.from(row);

    // Strip unknown columns to prevent "table has no column" errors
    prepared.removeWhere((key, _) => !_knownPatientColumns.contains(key));

    prepared.forEach((key, value) {
      if (value is bool) {
        prepared[key] = value ? 1 : 0;
      }
    });

    if (prepared['phone_number'] != null) {
      prepared['phone_number'] = dbHelper.decrypt(prepared['phone_number']);
    }
    if (prepared['pin_code'] != null) {
      prepared['pin_code'] = dbHelper.decrypt(prepared['pin_code']);
    }

    return prepared;
  }
}
