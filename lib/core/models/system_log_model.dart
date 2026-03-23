import 'dart:convert';

class SystemLog {
  final String id;
  final String? userId;
  final String? sessionId;
  final String action;
  final String timestamp;
  final int durationSeconds;
  final String? sensorFailures;
  final String severity;
  final String module;
  final bool isSynced;
  final String updatedAt;

  SystemLog({
    required this.id,
    this.userId,
    this.sessionId,
    required this.action,
    required this.timestamp,
    this.durationSeconds = 0,
    this.sensorFailures,
    required this.severity,
    required this.module,
    this.isSynced = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'action': action,
      'timestamp': timestamp,
      'duration_seconds': durationSeconds,
      'sensor_failures': sensorFailures,
      'severity': severity,
      'module': module,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt,
    };
  }

  factory SystemLog.fromMap(Map<String, dynamic> map) {
    return SystemLog(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      sessionId: map['session_id'] as String?,
      action: map['action'] as String,
      timestamp: map['timestamp'] as String,
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      sensorFailures: map['sensor_failures'] as String?,
      severity: map['severity'] as String,
      module: map['module'] as String,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      updatedAt: map['updated_at'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory SystemLog.fromJson(String source) => SystemLog.fromMap(json.decode(source) as Map<String, dynamic>);
}
