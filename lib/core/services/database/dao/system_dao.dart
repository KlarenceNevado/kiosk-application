import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'base_dao.dart';
import '../../../models/system_log_model.dart';
import '../../security/encryption_service.dart';
import '../../../../features/chat/models/chat_message.dart';

class SystemDao extends BaseDao {
  SystemDao(super.db);

  // --- REACTIVE STREAMS ---
  final _announcementController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _alertController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _scheduleController = StreamController<List<Map<String, dynamic>>>.broadcast();

  Timer? _announcementTimer;
  Timer? _alertTimer;
  Timer? _scheduleTimer;

  Stream<List<Map<String, dynamic>>> get announcementStream async* {
    yield await getAnnouncements();
    yield* _announcementController.stream;
  }
  
  Stream<List<Map<String, dynamic>>> get alertStream async* {
    yield await getAlerts();
    yield* _alertController.stream;
  }
  
  Stream<List<Map<String, dynamic>>> get scheduleStream async* {
    yield await getSchedules();
    yield* _scheduleController.stream;
  }

  void refreshAnnouncements() {
    _announcementTimer?.cancel();
    _announcementTimer = Timer(const Duration(milliseconds: 500), () async {
      final data = await getAnnouncements();
      if (!_announcementController.isClosed) {
        _announcementController.add(data);
      }
    });
  }

  void refreshAlerts() {
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(milliseconds: 500), () async {
      final data = await getAlerts();
      if (!_alertController.isClosed) {
        _alertController.add(data);
      }
    });
  }

  void refreshSchedules() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer(const Duration(milliseconds: 500), () async {
      final data = await getSchedules();
      if (!_scheduleController.isClosed) {
        _scheduleController.add(data);
      }
    });
  }

  void dispose() {
    _announcementTimer?.cancel();
    _alertTimer?.cancel();
    _scheduleTimer?.cancel();
    _announcementController.close();
    _alertController.close();
    _scheduleController.close();
  }

  // --- SECURITY & AUDIT ---
  Future<void> logSecurityEvent(String action, String description,
      {String severity = 'LOW', String? userId}) async {
    final lastLogs = await db.query('audit_logs', orderBy: 'id DESC', limit: 1);
    final previousHash =
        lastLogs.isNotEmpty ? lastLogs.first['hash'] as String? : 'GENESIS';

    final timestamp = DateTime.now().toIso8601String();
    final deviceInfo = "${Platform.operatingSystem} (${Platform.localHostname})";

    final normalizedUserId = userId ?? 'SYSTEM';
    final normalizedSeverity = severity.toUpperCase();

    final dataToHash =
        "$timestamp|$action|$description|$normalizedSeverity|$normalizedUserId|$deviceInfo|$previousHash";
    final key = utf8.encode(EncryptionService().getSecureKey());
    final hmacSha256 = Hmac(sha256, key);
    final hash = hmacSha256.convert(utf8.encode(dataToHash)).toString();

    await db.insert('audit_logs', {
      'timestamp': timestamp,
      'action': action,
      'description': description,
      'severity': normalizedSeverity,
      'user_id': normalizedUserId,
      'ip_address': 'LOCALHOST',
      'device_info': deviceInfo,
      'hash': hash,
      'previous_hash': previousHash
    });
  }

  Future<bool> verifyAuditIntegrity() async {
    final logs = await db.query('audit_logs', orderBy: 'id ASC');
    String expectedPreviousHash = 'GENESIS';

    for (var log in logs) {
      final actualPreviousHash = log['previous_hash'] as String? ?? 'GENESIS';
      if (actualPreviousHash != expectedPreviousHash) return false;

      final dataToHash =
          "${log['timestamp']}|${log['action']}|${log['description']}|${log['severity']}|${log['user_id']}|${log['device_info']}|$actualPreviousHash";
      final key = utf8.encode(EncryptionService().getSecureKey());
      final hmacSha256 = Hmac(sha256, key);
      final calculatedHash = hmacSha256.convert(utf8.encode(dataToHash)).toString();

      if (calculatedHash != log['hash']) return false;
      expectedPreviousHash = log['hash']?.toString() ?? '';
    }
    return true;
  }

  Future<Map<String, dynamic>> getSecurityPulse() async {
    final totalEvents = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM audit_logs')) ?? 0;
    final highRiskCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM audit_logs WHERE severity IN ("CRITICAL", "HIGH")')) ?? 0;
    final lastAttack = await db.query('audit_logs',
        where: 'severity = ?', whereArgs: ['CRITICAL'], orderBy: 'id DESC', limit: 1);

    return {
      'total': totalEvents,
      'highRisk': highRiskCount,
      'lastCritical': lastAttack.isNotEmpty ? lastAttack.first['timestamp'] : null,
      'status': highRiskCount > 0 ? 'WARNING' : 'SECURE',
    };
  }

  // --- SYNC METADATA ---
  Future<void> updateSyncMetadata({
    required String tableName,
    required String recordId,
    String? error,
    bool incrementRetry = false,
    bool block = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'sync_metadata',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );

    if (existing.isEmpty) {
      await db.insert('sync_metadata', {
        'table_name': tableName,
        'record_id': recordId,
        'last_error': error,
        'retry_count': incrementRetry ? 1 : 0,
        'last_attempt': now,
        'is_blocked': block ? 1 : 0,
      });
    } else {
      final currentRetry = existing.first['retry_count'] as int;
      await db.update(
        'sync_metadata',
        {
          'last_error': error,
          'retry_count': incrementRetry ? currentRetry + 1 : currentRetry,
          'last_attempt': now,
          'is_blocked': block ? 1 : (existing.first['is_blocked']),
        },
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [tableName, recordId],
      );
    }
  }

  Future<void> clearSyncMetadata(String tableName, String recordId) async {
    await db.delete(
      'sync_metadata',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );
  }

  Future<List<String>> getBlockedRecords(String tableName) async {
    final result = await db.query(
      'sync_metadata',
      columns: ['record_id'],
      where: 'table_name = ? AND is_blocked = 1',
      whereArgs: [tableName],
    );
    return result.map((e) => e['record_id']?.toString() ?? '').toList();
  }

  Future<Map<String, dynamic>?> getSyncMetadata(String tableName, String recordId) async {
    final result = await db.query(
      'sync_metadata',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    return await db.query('audit_logs', orderBy: 'id DESC', limit: 200);
  }

  // --- ANNOUNCEMENTS ---
  Future<void> insertAnnouncement(Map<String, dynamic> row) async {
    final dbRow = Map<String, dynamic>.from(row);
    if (dbRow['reactions'] is Map) dbRow['reactions'] = json.encode(dbRow['reactions']);
    dbRow['is_active'] = (dbRow['is_active'] == true || dbRow['is_active'] == 1 || dbRow['isActive'] == true || dbRow['isActive'] == 1) ? 1 : 0;
    dbRow['is_archived'] = (dbRow['is_archived'] == true || dbRow['is_archived'] == 1 || dbRow['isArchived'] == true || dbRow['isArchived'] == 1) ? 1 : 0;
    dbRow['target_group'] = dbRow['target_group'] ?? dbRow['targetGroup'];
    dbRow['is_deleted'] = (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] = (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;
    dbRow.remove('targetGroup');
    await db.insert('announcements', dbRow, conflictAlgorithm: ConflictAlgorithm.replace);
    refreshAnnouncements();
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final results = await db.query('announcements', 
        where: 'is_deleted = ?', 
        whereArgs: [0], 
        orderBy: 'timestamp DESC');
    return results.map((row) {
      final map = Map<String, dynamic>.from(row);
      if (map['reactions'] is String) {
        try {
          map['reactions'] = json.decode(map['reactions'] as String);
        } catch (_) {
          map['reactions'] = {};
        }
      } else if (map['reactions'] == null) {
        map['reactions'] = {};
      }
      return map;
    }).toList();
  }

  Future<Map<String, dynamic>?> getAnnouncementById(String id) async {
    final results = await db.query('announcements', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    final map = Map<String, dynamic>.from(results.first);
    if (map['reactions'] is String) {
      try {
        map['reactions'] = json.decode(map['reactions'] as String);
      } catch (_) {
        map['reactions'] = {};
      }
    } else if (map['reactions'] == null) {
      map['reactions'] = {};
    }
    return map;
  }

  Future<void> updateAnnouncement(Map<String, dynamic> row) async {
    final dbRow = Map<String, dynamic>.from(row);
    if (dbRow['reactions'] is Map) dbRow['reactions'] = json.encode(dbRow['reactions']);
    
    // Always mark as unsynced and update timestamp on local edit
    dbRow['is_synced'] = 0;
    dbRow['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    await db.update('announcements', dbRow, where: 'id = ?', whereArgs: [dbRow['id']]);
    refreshAnnouncements();
  }

  Future<void> deleteAnnouncement(String id) async {
    await db.update('announcements', {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    refreshAnnouncements();
  }

  Future<void> hardDeleteAnnouncement(String id) async {
    await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
    refreshAnnouncements();
  }

  // --- SCHEDULES ---
  Future<void> insertSchedule(Map<String, dynamic> row) async {
    final dbRow = Map<String, dynamic>.from(row);
    dbRow['is_deleted'] = (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] = (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;
    dbRow['color_value'] = dbRow['color_value'] ?? dbRow['colorValue'];
    dbRow.remove('colorValue');
    await db.insert('schedules', dbRow, conflictAlgorithm: ConflictAlgorithm.replace);
    refreshSchedules();
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    return await db.query('schedules', 
        where: 'is_deleted = ?', 
        whereArgs: [0], 
        orderBy: 'date ASC');
  }

  Future<void> deleteSchedule(String id) async {
    await db.update('schedules', {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    refreshSchedules();
  }

  Future<Map<String, dynamic>?> getScheduleById(String id) async {
    final maps = await db.query('schedules', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> hardDeleteSchedule(String id) async {
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
    refreshSchedules();
  }

  // --- ALERTS ---
  Future<void> insertAlert(Map<String, dynamic> row) async {
    final dbRow = Map<String, dynamic>.from(row);
    dbRow['is_emergency'] = (dbRow['is_emergency'] == true || dbRow['is_emergency'] == 1 || dbRow['isEmergency'] == true || dbRow['isEmergency'] == 1) ? 1 : 0;
    dbRow['is_active'] = (dbRow['is_active'] == true || dbRow['is_active'] == 1 || dbRow['isActive'] == true || dbRow['isActive'] == 1) ? 1 : 0;
    dbRow['is_deleted'] = (dbRow['is_deleted'] == true || dbRow['is_deleted'] == 1) ? 1 : 0;
    dbRow['is_synced'] = (dbRow['is_synced'] == true || dbRow['is_synced'] == 1) ? 1 : 0;
    dbRow['target_group'] = dbRow['target_group'] ?? dbRow['targetGroup'];
    dbRow.remove('isEmergency');
    dbRow.remove('isActive');
    dbRow.remove('targetGroup');
    await db.insert('alerts', dbRow, conflictAlgorithm: ConflictAlgorithm.replace);
    refreshAlerts();
  }

  Future<List<Map<String, dynamic>>> getAlerts() async {
    return await db.query('alerts', 
        where: 'is_deleted = ?', 
        whereArgs: [0], 
        orderBy: 'timestamp DESC');
  }

  Future<Map<String, dynamic>?> getAlertById(String id) async {
    final results = await db.query('alerts', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateAlert(Map<String, dynamic> row) async {
    final dbRow = Map<String, dynamic>.from(row);
    dbRow['is_synced'] = 0;
    dbRow['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    await db.update('alerts', dbRow, where: 'id = ?', whereArgs: [dbRow['id']]);
    refreshAlerts();
  }

  Future<void> deleteAlert(String id) async {
    await db.update('alerts', {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    refreshAlerts();
  }

  Future<void> hardDeleteAlert(String id) async {
    await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
    refreshAlerts();
  }

  // --- UNSYNCED FETCHERS ---
  Future<List<Map<String, dynamic>>> getUnsyncedAnnouncements() async {
    return await db.query('announcements', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAlerts() async {
    return await db.query('alerts', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSchedules() async {
    return await db.query('schedules', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedChatMessages() async {
    return await db.query('chat_messages', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<Map<String, dynamic>?> getChatMessageById(String id) async {
    final results = await db.query('chat_messages', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> upsertChatMessage(Map<String, dynamic> data) async {
    // Use the model to normalize data (handles message/content mapping, reactions decoding, etc.)
    final message = ChatMessage.fromMap(data);
    
    // Convert back to map for SQLite insertion (now includes patient_id, sender, message)
    final prepared = message.toMap();
    
    await db.insert('chat_messages', prepared, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- REMINDERS ---
  Future<int> insertReminder(Map<String, dynamic> row) async {
    return await db.insert('reminders', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getReminders(String userId) async {
    return await db.query('reminders', where: 'user_id = ?', whereArgs: [userId], orderBy: 'time ASC');
  }

  Future<int> updateReminder(Map<String, dynamic> row) async {
    final dbRow = Map<String, dynamic>.from(row);
    if (dbRow.containsKey('userId')) {
      dbRow['user_id'] = dbRow['userId'];
      dbRow.remove('userId');
    }
    return await db.update('reminders', dbRow, where: 'id = ?', whereArgs: [dbRow['id']]);
  }

  Future<int> deleteReminder(int id) async {
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllReminders(String userId) async {
    return await db.delete('reminders', where: 'user_id = ?', whereArgs: [userId]);
  }

  // --- SYSTEM LOGS ---
  Future<void> createSystemLog(SystemLog log) async {
    await db.insert('system_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SystemLog>> getSystemLogs({int limit = 100}) async {
    final result = await db.query('system_logs', orderBy: 'timestamp DESC', limit: limit);
    return result.map((json) => SystemLog.fromMap(json)).toList();
  }

  Future<List<SystemLog>> getUnsyncedSystemLogs() async {
    final maps = await db.query('system_logs', where: 'is_synced = ?', whereArgs: [0]);
    return maps.map((map) => SystemLog.fromMap(map)).toList();
  }

  Future<void> markSystemLogAsSynced(String id) async {
    await db.update('system_logs', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
