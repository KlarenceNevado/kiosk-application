import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../../../../features/health_check/models/vital_signs_model.dart';
import 'base_dao.dart';

class VitalsDao extends BaseDao {
  VitalsDao(super.db);

  Future<void> createRecord(VitalSigns record) async {
    final map = record.toMap();

    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'user_id': map['userId'],
      'timestamp': map['timestamp'],
      'heart_rate': encrypt(map['heartRate']),
      'systolic_bp': encrypt(map['systolicBP']),
      'diastolic_bp': encrypt(map['diastolicBP']),
      'oxygen': encrypt(map['oxygen']),
      'temperature': encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmi_category': map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'follow_up_action': map['followUpAction'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'is_synced': 0,
      'report_url': map['report_url'],
      'report_path': map['report_path']
    };

    await db.insert('vitals', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertVitalSign(Map<String, dynamic> map) async {
    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'user_id': map['user_id'] ?? map['userId'],
      'timestamp': map['timestamp'],
      'heart_rate': encrypt(map['heart_rate'] ?? map['heartRate']),
      'systolic_bp': encrypt(map['systolic_bp'] ?? map['systolicBP']),
      'diastolic_bp': encrypt(map['diastolic_bp'] ?? map['diastolicBP']),
      'oxygen': encrypt(map['oxygen']),
      'temperature': encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmi_category': map['bmi_category'] ?? map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'follow_up_action': map['follow_up_action'] ?? map['followUpAction'],
      'updated_at': map['updated_at'] ?? DateTime.now().toIso8601String(),
      'is_deleted': (map['is_deleted'] == true || map['is_deleted'] == 1) ? 1 : 0,
      'is_synced': (map['is_synced'] == true || map['is_synced'] == 1) ? 1 : 0,
      'report_url': map['report_url'],
      'report_path': map['report_path']
    };

    await db.insert('vitals', encryptedMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRecord(VitalSigns record) async {
    final map = record.toMap();

    final encryptedMap = <String, dynamic>{
      'id': map['id'],
      'user_id': map['user_id'] ?? map['userId'],
      'timestamp': map['timestamp'],
      'heart_rate': encrypt(map['heart_rate'] ?? map['heartRate']),
      'systolic_bp': encrypt(map['systolic_bp'] ?? map['systolicBP']),
      'diastolic_bp': encrypt(map['diastolic_bp'] ?? map['diastolicBP']),
      'oxygen': encrypt(map['oxygen']),
      'temperature': encrypt(map['temperature']),
      'bmi': map['bmi'],
      'bmi_category': map['bmi_category'] ?? map['bmiCategory'],
      'status': map['status'],
      'remarks': map['remarks'],
      'follow_up_action': map['follow_up_action'] ?? map['followUpAction'],
      'updated_at': DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'is_synced': 0
    };

    await db.update('vitals', encryptedMap,
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> updateRecordRaw(String id, Map<String, dynamic> data) async {
    return await db.update(
      'vitals',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  VitalSigns _parseVitalSigns(Map<String, dynamic> json) {
    try {
      int getInt(dynamic val) {
        if (val == null) return 0;
        if (val is int) return val;
        try {
          return decryptInt(val.toString());
        } catch (_) {
          return int.tryParse(val.toString()) ?? 0;
        }
      }

      double getDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is double) return val;
        if (val is int) return val.toDouble();
        try {
          return decryptDouble(val.toString());
        } catch (_) {
          return double.tryParse(val.toString()) ?? 0.0;
        }
      }

      return VitalSigns(
        id: json['id'] ?? '',
        userId: json['userId'] ?? json['user_id'] ?? 'guest',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        heartRate: getInt(json['heartRate'] ?? json['heart_rate']),
        systolicBP: getInt(json['systolicBP'] ?? json['systolic_bp']),
        diastolicBP: getInt(json['diastolicBP'] ?? json['diastolic_bp']),
        oxygen: getInt(json['oxygen']),
        temperature: getDouble(json['temperature']),
        bmi: json['bmi'] is String
            ? double.tryParse(json['bmi'])
            : (json['bmi'] as num?)?.toDouble(),
        bmiCategory: json['bmiCategory'] ?? json['bmi_category'],
        status: json['status'] ?? 'pending',
        remarks: json['remarks'],
        followUpAction: json['followUpAction'] ?? json['follow_up_action'],
        updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
        isDeleted: json['is_deleted'] == 1,
        isSynced: json['is_synced'] == 1,
        reportUrl: json['report_url'],
        reportPath: json['report_path'],
      );
    } catch (e) {
      debugPrint("❌ Error parsing vital signs: $e");
      return VitalSigns.fromMap(json);
    }
  }

  Future<List<VitalSigns>> getRecordsByUserId(String userId) async {
    final result = await db.query('vitals',
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<List<VitalSigns>> getAllRecords() async {
    final result = await db.query('vitals',
        where: 'is_deleted = ?', whereArgs: [0], orderBy: 'timestamp DESC');
    return result.map((json) => _parseVitalSigns(json)).toList();
  }

  Future<Map<String, dynamic>?> getVitalRecordById(String id) async {
    final results = await db.query('vitals', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<VitalSigns>> getUnsyncedRecords() async {
    final maps = await db.query(
      'vitals',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => _parseVitalSigns(map)).toList();
  }

  Future<void> markRecordAsSynced(String id) async {
    await db.update(
      'vitals',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getVitalSignById(String id) async {
    final maps = await db.query('vitals', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? maps.first : null;
  }
}
