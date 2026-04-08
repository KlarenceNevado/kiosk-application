import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to control Raspberry Pi hardware components via GPIO.
/// Primarily used for triggering the 4-channel relay module.
class HardwareControlService {
  static final HardwareControlService _instance =
      HardwareControlService._internal();
  factory HardwareControlService() => _instance;
  HardwareControlService._internal();

  // GPIO Pin Mappings (Standard BCM numbering)
  // These should be connected to the 'IN' pins of your 4-channel relay
  static const int relayChannel1 = 17; // General Sensors (e.g., Blood Pressure)
  static const int relayChannel2 = 27; // Accessory Peripherals
  static const int relayChannel3 = 22; // Unused
  static const int relayChannel4 = 23; // Unused

  bool _isInitialized = false;

  /// Initializes the GPIO pins as outputs.
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isLinux) return;

    try {
      await _setPinMode(relayChannel1, 'op');
      await _setPinMode(relayChannel2, 'op');
      _isInitialized = true;
      debugPrint('HardwareControlService: GPIO Initialized');
    } catch (e) {
      debugPrint('HardwareControlService: Initialization failed: $e');
    }
  }

  /// Sets the mode for a specific GPIO pin using 'raspi-gpio'.
  Future<void> _setPinMode(int pin, String mode) async {
    await Process.run('raspi-gpio', ['set', pin.toString(), 'op']);
  }

  /// Switches a relay channel ON or OFF.
  /// Standard relays often use active-low logic (0 = ON, 1 = OFF).
  Future<void> setRelayState(int pin, bool isOn) async {
    if (!_isInitialized) return;

    try {
      // Active Low Logic: 'dl' (drive low) usually turns relay ON,
      // 'dh' (drive high) usually turns it OFF.
      final level = isOn ? 'dl' : 'dh';
      await Process.run('raspi-gpio', ['set', pin.toString(), level]);
      debugPrint(
          'HardwareControlService: Pin $pin set to ${isOn ? 'ON' : 'OFF'}');
    } catch (e) {
      debugPrint('HardwareControlService: Failed to set relay state: $e');
    }
  }

  /// Turns off all high-power sensors to save battery.
  Future<void> enterPowerSavingMode() async {
    await setRelayState(relayChannel1, false);
    await setRelayState(relayChannel2, false);
  }

  /// Restores power to all sensors.
  Future<void> exitPowerSavingMode() async {
    await setRelayState(relayChannel1, true);
    await setRelayState(relayChannel2, true);
  }
}
