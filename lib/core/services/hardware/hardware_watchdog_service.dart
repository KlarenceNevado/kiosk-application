import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sensor_service_interface.dart';
import 'sensor_manager.dart';
import '../system/log_manager_service.dart';

class HardwareWatchdogService {
  static final HardwareWatchdogService _instance = HardwareWatchdogService._internal();
  factory HardwareWatchdogService() => _instance;
  HardwareWatchdogService._internal();

  Timer? _watchdogTimer;
  final Map<SensorType, DateTime> _lastSeen = {};
  
  // Threshold for "SILENCE" before triggering recovery (seconds)
  static const int silenceThreshold = 15;

  void start() {
    debugPrint("🛡️ [HardwareWatchdog] Starting system monitoring...");
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkHealth());

    // Listen to all sensor data to update heartbeats
    SensorManager().allDataStream.listen((event) {
      if (event.data != null) {
        _lastSeen[event.type] = DateTime.now();
      }
    });
  }

  void stop() {
    _watchdogTimer?.cancel();
  }

  void _checkHealth() {
    final now = DateTime.now();
    final sensorManager = SensorManager();

    for (var type in SensorType.values) {
      // We only monitor sensors that should be active
      final service = sensorManager.getSensor(type);
      if (service.currentStatus == SensorStatus.reading) {
        final lastTime = _lastSeen[type];
        
        // If never seen or seen too long ago
        if (lastTime == null || now.difference(lastTime).inSeconds > silenceThreshold) {
          _triggerRecovery(type);
        }
      }
    }
  }

  Future<void> _triggerRecovery(SensorType type) async {
    final logManager = LogManagerService();
    debugPrint("🚨 [HardwareWatchdog] Silent sensor detected: $type. Triggering recovery...");
    
    logManager.logEvent(
      "HARDWARE_RECOVERY_TRIGGERED",
      "Sensor $type was silent for >$silenceThreshold seconds. Restarting driver.",
      severity: LogSeverity.warning,
    );

    final sensorManager = SensorManager();
    sensorManager.stopSensor(type);
    
    // Brief cool-down for hardware/OS buffers
    await Future.delayed(const Duration(seconds: 2));
    
    sensorManager.startSensor(type);
    
    // Reset timer to give it a chance to start
    _lastSeen[type] = DateTime.now();
    
    logManager.logEvent(
      "HARDWARE_RECOVERY_COMPLETE",
      "Driver for $type restarted successfully.",
      severity: LogSeverity.info,
    );
  }
}
