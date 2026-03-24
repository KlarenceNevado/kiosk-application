import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class VitalSigns {
  final String id;
  final String userId; // NEW: Links record to a user
  final DateTime timestamp;
  final int heartRate;
  final int systolicBP;
  final int diastolicBP;
  final int oxygen;
  final double temperature;
  final double? bmi;
  final String? bmiCategory;
  // Validation tracking
  final String status; // pending, verified, rejected
  final String? remarks;
  final String? followUpAction;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool isSynced;
  // height/weight could be added here if needed for permanent record

  /// Returns the timestamp specifically in Asia/Manila (PHT) for UI display
  DateTime get phtTimestamp {
    try {
      final manila = tz.getLocation('Asia/Manila');
      return tz.TZDateTime.from(timestamp, manila);
    } catch (e) {
      return timestamp.toLocal();
    }
  }

  final String? reportUrl;
  final String? reportPath;

  VitalSigns({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.oxygen,
    required this.temperature,
    this.bmi,
    this.bmiCategory,
    this.status = 'pending',
    this.remarks,
    this.followUpAction,
    this.reportUrl,
    this.reportPath,
    this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'heartRate': heartRate,
      'systolicBP': systolicBP,
      'diastolicBP': diastolicBP,
      'oxygen': oxygen,
      'temperature': temperature,
      'bmi': bmi,
      'bmiCategory': bmiCategory,
      'status': status,
      'remarks': remarks,
      'followUpAction': followUpAction,
      'report_url': reportUrl,
      'report_path': reportPath,
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  String toJson() => json.encode(toMap());

  factory VitalSigns.fromMap(Map<String, dynamic> map) {
    return VitalSigns(
      id: map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? 'guest',
      timestamp: DateTime.parse(map['timestamp']),
      heartRate: (map['heartRate'] ?? map['heart_rate'])?.toInt() ?? 0,
      systolicBP: (map['systolicBP'] ?? map['systolic_bp'])?.toInt() ?? 0,
      diastolicBP: (map['diastolicBP'] ?? map['diastolic_bp'])?.toInt() ?? 0,
      oxygen: map['oxygen']?.toInt() ?? 0,
      temperature: map['temperature']?.toDouble() ?? 0.0,
      bmi: map['bmi']?.toDouble(),
      bmiCategory: map['bmiCategory'] ?? map['bmi_category'],
      status: map['status'] ?? 'pending',
      remarks: map['remarks'],
      followUpAction: map['followUpAction'] ?? map['follow_up_action'],
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
    );
  }

  factory VitalSigns.fromJson(String source) =>
      VitalSigns.fromMap(json.decode(source));

  VitalSigns copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    int? heartRate,
    int? systolicBP,
    int? diastolicBP,
    int? oxygen,
    double? temperature,
    double? bmi,
    String? bmiCategory,
    String? status,
    String? remarks,
    String? followUpAction,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return VitalSigns(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      systolicBP: systolicBP ?? this.systolicBP,
      diastolicBP: diastolicBP ?? this.diastolicBP,
      oxygen: oxygen ?? this.oxygen,
      temperature: temperature ?? this.temperature,
      bmi: bmi ?? this.bmi,
      bmiCategory: bmiCategory ?? this.bmiCategory,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      followUpAction: followUpAction ?? this.followUpAction,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
