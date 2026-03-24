import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'sync_handler.dart';
import '../../../../features/auth/models/user_model.dart';

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
        final overlapTime = DateTime.parse(lastSync).subtract(const Duration(minutes: 5));
        query = query.gt('updated_at', overlapTime.toIso8601String());
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
      },
    ).subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  // --- CRUD HELPERS ---

  Future<User?> createPatient(User user) async {
    final Map<String, dynamic> supabaseData = {
      'id': user.id,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'middle_initial': user.middleInitial,
      'sitio': user.sitio,
      'phone_number': dbHelper.encrypt(user.phoneNumber),
      'pin_code': dbHelper.encrypt(user.pinCode),
      'date_of_birth': user.dateOfBirth.toIso8601String(),
      'gender': user.gender,
      'parent_id': user.parentId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from('patients').upsert(supabaseData);
      final syncedUser = user.copyWith(isSynced: true, updatedAt: DateTime.now());
      await dbHelper.insertPatient(syncedUser);
      return syncedUser;
    } catch (e) {
      final offlineUser = user.copyWith(isSynced: false);
      await dbHelper.insertPatient(offlineUser);
      return offlineUser;
    }
  }

  Future<bool> updatePatient(User user) async {
    try {
      final Map<String, dynamic> supabaseData = {
        'first_name': user.firstName,
        'last_name': user.lastName,
        'middle_initial': user.middleInitial,
        'sitio': user.sitio,
        'phone_number': dbHelper.encrypt(user.phoneNumber),
        'pin_code': dbHelper.encrypt(user.pinCode),
        'date_of_birth': user.dateOfBirth.toIso8601String(),
        'gender': user.gender,
        'parent_id': user.parentId,
        'updated_at': DateTime.now().toIso8601String(),
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
      final encryptedPhone = dbHelper.encrypt(phone);
      final encryptedPin = dbHelper.encrypt(pin);
      final data = await supabase.from('patients').select().eq('phone_number', encryptedPhone).eq('pin_code', encryptedPin).limit(1);

      if (data.isNotEmpty) {
        final row = data.first;
        final decryptedRow = Map<String, dynamic>.from(row);
        decryptedRow['phone_number'] = dbHelper.decrypt(row['phone_number']);
        decryptedRow['pin_code'] = dbHelper.decrypt(row['pin_code']);
        return User.fromMap(decryptedRow);
      }
      return null;
    } catch (e) {
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
      final data = await supabase.from('patients').select().eq('phone_number', phoneNumber);
      return data.where((row) {
        final first = row['first_name']?.toString().toLowerCase() ?? '';
        final last = row['last_name']?.toString().toLowerCase() ?? '';
        final input = nameInput.toLowerCase().trim();
        return input == first || input == last || "$first $last" == input;
      }).toList();
    } catch (e) {
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

  Map<String, dynamic> _prepareRowForSqlite(Map<String, dynamic> row) {
    final prepared = Map<String, dynamic>.from(row);
    prepared.forEach((key, value) {
      if (value is bool) {
        prepared[key] = value ? 1 : 0;
      }
    });
    return prepared;
  }
}
