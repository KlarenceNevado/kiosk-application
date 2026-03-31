import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../hardware/hardware_control_service.dart';
import 'app_environment.dart';
import 'system_log_service.dart';

enum PowerMode {
  active,
  eco,
  deepSleep
}

/// Manages the system power states and inactivity timers for Raspberry Pi 4B.
/// Integrated with real-time battery voltage monitoring from ESP32 Hub.
class PowerManagerService {
  static final PowerManagerService _instance = PowerManagerService._internal();
  factory PowerManagerService() => _instance;
  PowerManagerService._internal();

  final _env = AppEnvironment();
  final _hardware = HardwareControlService();
  
  final _modeController = StreamController<PowerMode>.broadcast();
  Stream<PowerMode> get modeStream => _modeController.stream;

  PowerMode _currentMode = PowerMode.active;
  PowerMode get currentMode => _currentMode;
  
  double _currentVoltage = 13.2; // Default starting voltage
  double get currentVoltage => _currentVoltage;

  Timer? _inactivityTimer;
  
  // Thresholds in seconds
  static const int dimThreshold = 120;       // 2 minutes: Dim & Powersave
  static const int ecoModeThreshold = 300;   // 5 minutes: Stop UI Tickers
  static const int deepSleepThreshold = 600; // 10 minutes: Screen Off & Relay Off

  /// Starts monitoring user activity and ensures hardware is ready.
  void startMonitoring() {
    _hardware.initialize(); 
    _resetTimer();
  }

  /// Updates the latest battery voltage from the ESP32 Hub.
  /// Triggers emergency deep sleep if below 11.5V.
  void updateBatteryStatus(double voltage) {
    _currentVoltage = voltage;
    
    if (voltage < 11.5 && _currentMode != PowerMode.deepSleep) {
      debugPrint("⚠️ [PowerManager] CRITICAL BATTERY ($voltage V). Forcing Deep Sleep.");
      _triggerEmergencyDeepSleep();
    }
  }

  /// Returns an approximate percentage for a 12V LiFePO4 battery.
  double get batteryPercentage {
    if (_currentVoltage >= 13.6) return 100.0;
    if (_currentVoltage >= 13.3) return 90.0;
    if (_currentVoltage >= 13.2) return 70.0;
    if (_currentVoltage >= 13.1) return 40.0;
    if (_currentVoltage >= 13.0) return 30.0;
    if (_currentVoltage >= 12.9) return 20.0;
    if (_currentVoltage >= 12.8) return 10.0;
    if (_currentVoltage >= 11.5) return 5.0;
    return 0.0;
  }

  /// Called whenever a user interacts with the screen.
  void notifyActivity() {
    if (_currentMode != PowerMode.active) {
      _wakeUp();
    }
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: dimThreshold), _onIdleThresholdReached);
  }

  void _setMode(PowerMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _modeController.add(mode);
    
    debugPrint("🔋 [PowerManager] Switched to mode: $mode");
    
    SystemLogService().logAction(
      action: 'POWER_MODE_CHANGE',
      module: 'SYSTEM',
      severity: 'INFO',
      sensorFailures: 'System entered $mode mode. Battery: $_currentVoltage V (${batteryPercentage.toInt()}%)'
    );
  }

  Future<void> _onIdleThresholdReached() async {
    // Stage 1: Dim the screen and downclock CPU
    await setBrightness(20);
    _setCpuGovernor('powersave');
    
    // Schedule Stage 2
    _inactivityTimer = Timer(const Duration(seconds: ecoModeThreshold - dimThreshold), () async {
      // Stage 2: Enter Eco Mode (Suspend UI Animations)
      _env.isEcoModeActive.value = true;
      _setMode(PowerMode.eco);
      debugPrint('PowerManager: Eco-Mode Activated (Animations Suspended)');

      // Schedule Stage 3
      _inactivityTimer = Timer(const Duration(seconds: deepSleepThreshold - ecoModeThreshold), () async {
        await _triggerEmergencyDeepSleep();
      });
    });
  }

  Future<void> _triggerEmergencyDeepSleep() async {
    // Stage 3: Deep Sleep (Screen Off, Physical Relay Off)
    await _setScreenPower(false);
    await _hardware.enterPowerSavingMode();
    _setMode(PowerMode.deepSleep);
    debugPrint('PowerManager: Entering Deep Sleep Stage');
  }

  Future<void> _wakeUp() async {
    debugPrint('PowerManager: Waking up from Eco-Mode');
    _env.isEcoModeActive.value = false;
    _setMode(PowerMode.active);
    await setBrightness(100);
    _setCpuGovernor('ondemand');
    await _setScreenPower(true);
    await _hardware.exitPowerSavingMode();
  }

  /// Controls screen brightness via ddcutil (for HDMI monitors).
  Future<void> setBrightness(int percent) async {
    if (kIsWeb || !Platform.isLinux) return;
    try {
      // ddcutil setvcp 10 <value>
      await Process.run('ddcutil', ['setvcp', '10', percent.toString()]);
      _env.currentBrightness.value = percent / 100.0;
    } catch (e) {
      debugPrint('PowerManager: Brightness control failed: $e');
    }
  }

  /// Toggles screen power via DPMS.
  Future<void> _setScreenPower(bool isOn) async {
    if (kIsWeb || !Platform.isLinux) return;
    final state = isOn ? 'on' : 'off';
    await Process.run('xset', ['dpms', 'force', state], runInShell: true);
  }

  /// Sets the CPU governor to save power when idle.
  void _setCpuGovernor(String governor) {
    if (kIsWeb || !Platform.isLinux) return;
    // Note: This requires the helper script configured in deploy_kiosk.sh
    Process.run('sh', ['-c', 'echo $governor | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor']);
  }
}
