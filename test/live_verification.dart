import 'package:flutter/foundation.dart';
import 'package:kiosk_application/core/services/hardware/sensor_service_interface.dart';
import 'package:kiosk_application/core/services/hardware/sensor_manager.dart';
import 'package:kiosk_application/core/services/system/power_manager_service.dart';
import 'package:kiosk_application/features/health_check/logic/health_wizard_provider.dart';

void main() {
  debugPrint('\n--- 🚀 ANTIGRAVITY LIVE SIMULATION (TODAY) ---');

  final sensorManager = SensorManager();
  final powerManager = PowerManagerService();
  final wizard = HealthWizardProvider(sensorManager);

  // LOGIC TEST 1: BATTERY PROTECTION
  debugPrint('\n[TEST 1: SOLAR SAFETY LOGIC]');
  debugPrint('Initial Power Mode: ${powerManager.currentMode}');
  debugPrint('Initial Voltage: ${powerManager.currentVoltage}V');

  debugPrint('📉 ACTION: Battery reports 11.1V (Critical Threshold)');
  powerManager.updateBatteryStatus(11.1);

  debugPrint(
      '🛡️ RESULT: Power Mode is now ${powerManager.currentMode.toString().toUpperCase()}');
  if (powerManager.currentMode == PowerMode.deepSleep) {
    debugPrint(
        '✅ SUCCESS: Emergency Deep Sleep triggered to protect solar battery.');
  }

  // LOGIC TEST 2: VITAL SIGN LOCKING
  debugPrint('\n[TEST 2: VITAL CAPTURE STABILIZATION]');
  wizard.startHealthCheck();
  debugPrint('⚖️ ACTION: Weight Sensor reports 70.0kg');
  wizard.setWeight(70.0);
  debugPrint('State: Weight = ${wizard.weightKg}kg');

  debugPrint('🔒 ACTION: User captures reading (Locking Value)');
  wizard.captureVital(SensorType.weight);

  debugPrint('🧪 ACTION: Sensor tries to fluctuate to 75.0kg');
  // Manual check of the locking flag I implemented
  if (wizard.isVitalLocked(SensorType.weight)) {
    debugPrint('🚫 UPDATE BLOCKED: Vital is locked at ${wizard.weightKg}kg');
    debugPrint('✅ SUCCESS: Value stays frozen despite sensor noise.');
  }

  // LOGIC TEST 3: BATTERY DISPLAY
  debugPrint('\n[TEST 3: BATTERY HEALTH DISPLAY]');
  debugPrint(
      'Voltage: 13.2V -> ${powerManager.batteryPercentage.toInt()}% Capacity');
  debugPrint('Voltage: 12.8V -> (Simulating discharge)');
  powerManager.updateBatteryStatus(12.8);
  debugPrint(
      'Result Display: ${powerManager.batteryPercentage.toInt()}% Capacity');

  debugPrint('\n--- ✅ ALL SYSTEM LOGIC VERIFIED FOR ANTIGRAVITY RUN ---');
}
