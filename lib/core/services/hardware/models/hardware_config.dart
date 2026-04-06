import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class HardwareConfig {
  static HardwareConfig? _instance;
  static HardwareConfig get instance => _instance ?? defaultConfig();

  final SystemSettings system;
  final DeviceSettings hub;
  final DeviceSettings oximeter;
  final DeviceSettings bloodPressure;

  HardwareConfig({
    required this.system,
    required this.hub,
    required this.oximeter,
    required this.bloodPressure,
  });

  factory HardwareConfig.fromJson(Map<String, dynamic> json) {
    return HardwareConfig(
      system: SystemSettings.fromJson(json['system'] ?? {}),
      hub: DeviceSettings.fromJson(json['hub'] ?? {}),
      oximeter: DeviceSettings.fromJson(json['oximeter'] ?? {}),
      bloodPressure: DeviceSettings.fromJson(json['blood_pressure'] ?? {}),
    );
  }

  static Future<HardwareConfig> load() async {
    try {
      final String response = await rootBundle.loadString('assets/config/hardware_config.json');
      final data = await json.decode(response);
      _instance = HardwareConfig.fromJson(data);
      debugPrint("⚙️ [HardwareConfig] Successfully loaded config from assets.");
      return _instance!;
    } catch (e) {
      debugPrint("⚠️ [HardwareConfig] Failed to load config, using hardcoded defaults: $e");
      _instance = HardwareConfig.defaultConfig();
      return _instance!;
    }
  }

  static HardwareConfig defaultConfig() {
    return HardwareConfig(
      system: SystemSettings(),
      hub: DeviceSettings(name: "Default Hub", baudRate: 115200, portOverride: "/dev/ttyAMA0"),
      oximeter: DeviceSettings(name: "Default Oximeter", baudRate: 19200),
      bloodPressure: DeviceSettings(name: "Default BP", baudRate: 9600),
    );
  }
}

class SystemSettings {
  final int discoveryTimeoutMs;
  final int probeDelayMs;
  final bool debugLogs;

  SystemSettings({
    this.discoveryTimeoutMs = 500,
    this.probeDelayMs = 500,
    this.debugLogs = true,
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      discoveryTimeoutMs: json['discovery_timeout_ms'] ?? 500,
      probeDelayMs: json['probe_delay_ms'] ?? 500,
      debugLogs: json['debug_logs'] ?? true,
    );
  }
}

class DeviceSettings {
  final String name;
  final String? portOverride;
  final int baudRate;
  final int watchdogTimeoutMs;
  final String? handshakeSignature;
  final String? handshakeSignatureHex;

  DeviceSettings({
    required this.name,
    this.portOverride,
    required this.baudRate,
    this.watchdogTimeoutMs = 10000,
    this.handshakeSignature,
    this.handshakeSignatureHex,
  });

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    return DeviceSettings(
      name: json['name'] ?? "Unknown Device",
      portOverride: json['port_override'],
      baudRate: json['baud_rate'] ?? 9600,
      watchdogTimeoutMs: json['watchdog_timeout_ms'] ?? 10000,
      handshakeSignature: json['handshake_signature'],
      handshakeSignatureHex: json['handshake_signature_hex'],
    );
  }
}
