import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../models/system_log_model.dart';
import '../security/security_logger.dart';

class SystemLogService {
  static final SystemLogService _instance = SystemLogService._internal();
  factory SystemLogService() => _instance;
  SystemLogService._internal();

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  String? _currentUserId;

  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  /// Starts a new session for a user
  void startSession(String userId) {
    _currentUserId = userId;
    _currentSessionId = _uuid.v4();
    _sessionStartTime = DateTime.now();
    
    logAction(
      action: 'SESSION_START',
      module: 'AUTH',
      severity: 'INFO',
    );
  }

  /// Ends the current session and logs the total duration
  Future<void> endSession() async {
    if (_currentSessionId == null) return;

    final durationSeconds = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    await logAction(
      action: 'SESSION_END',
      module: 'AUTH',
      severity: 'INFO',
      durationSeconds: durationSeconds,
    );

    _currentSessionId = null;
    _sessionStartTime = null;
    _currentUserId = null;
  }

  /// Logs a specific action to the database
  Future<void> logAction({
    required String action,
    required String module,
    String severity = 'INFO',
    int durationSeconds = 0,
    String? sensorFailures,
    String? userId,
  }) async {
    final now = DateTime.now();
    final log = SystemLog(
      id: _uuid.v4(),
      userId: userId ?? _currentUserId,
      sessionId: _currentSessionId,
      action: action,
      timestamp: now.toIso8601String(),
      durationSeconds: durationSeconds,
      sensorFailures: sensorFailures,
      severity: severity,
      module: module,
      updatedAt: now.toIso8601String(),
    );

    try {
      await _db.createSystemLog(log);
      
      // Also mirror to SecurityLogger for console output (sanitized)
      if (severity == 'ERROR') {
        SecurityLogger.error("System Log Error: $action", error: sensorFailures);
      } else if (severity == 'WARNING') {
        SecurityLogger.warning("System Log Warning: $action");
      } else {
        SecurityLogger.info("System Log: $action");
      }
    } catch (e) {
      SecurityLogger.error("Failed to persist system log", error: e);
    }
  }

  String? get currentSessionId => _currentSessionId;
}
