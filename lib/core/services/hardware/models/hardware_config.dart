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
      final String response =
          await rootBundle.loadString('assets/config/hardware_config.json');
      final data = await json.decode(response);
      final config = HardwareConfig.fromJson(data);
      config.validate();
      _instance = config;
      debugPrint("⚙️ [HardwareConfig] Successfully loaded and validated config from assets.");
      return _instance!;
    } catch (e) {
      debugPrint(
          "⚠️ [HardwareConfig] Failed to load config, using hardcoded defaults: $e");
      _instance = HardwareConfig.defaultConfig();
      return _instance!;
    }
  }

  void validate() {
    system.validate();
    hub.validate();
    oximeter.validate();
    bloodPressure.validate();
  }

  static HardwareConfig defaultConfig() {
    return HardwareConfig(
      system: SystemSettings(),
      hub: DeviceSettings(
          name: "Default Hub", baudRate: 115200),
      oximeter: DeviceSettings(name: "Default Oximeter", baudRate: 19200),
      bloodPressure: DeviceSettings(name: "Default BP", baudRate: 9600),
    );
  }
}

class SystemSettings {
  final int discoveryTimeoutMs;
  final int probeDelayMs;
  final bool debugLogs;
  final bool forceManualVitals;

  SystemSettings({
    this.discoveryTimeoutMs = 500,
    this.probeDelayMs = 500,
    this.debugLogs = true,
    this.forceManualVitals = false,
  });

  void validate() {
    if (discoveryTimeoutMs < 100) {
      throw Exception("Invalid system.discovery_timeout_ms: Must be >= 100ms");
    }
    if (probeDelayMs < 50) {
      throw Exception("Invalid system.probe_delay_ms: Must be >= 50ms");
    }
  }

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      discoveryTimeoutMs: json['discovery_timeout_ms'] ?? 500,
      probeDelayMs: json['probe_delay_ms'] ?? 500,
      debugLogs: json['debug_logs'] ?? true,
      forceManualVitals: json['force_manual_vitals'] ?? false,
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
  final int? vendorId;
  final int? productId;

  DeviceSettings({
    required this.name,
    this.portOverride,
    required this.baudRate,
    this.watchdogTimeoutMs = 10000,
    this.handshakeSignature,
    this.handshakeSignatureHex,
    this.vendorId,
    this.productId,
  });

  void validate() {
    final validBauds = [4800, 9600, 19200, 38400, 57600, 115200];
    if (!validBauds.contains(baudRate)) {
      throw Exception("Invalid baud_rate for $name: $baudRate");
    }
    if (watchdogTimeoutMs < 2000) {
      throw Exception("Watchdog timeout too low for $name: $watchdogTimeoutMs");
    }
  }

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    return DeviceSettings(
      name: json['name'] ?? "Unknown Device",
      portOverride: json['port_override'],
      baudRate: json['baud_rate'] ?? 9600,
      watchdogTimeoutMs: json['watchdog_timeout_ms'] ?? 10000,
      handshakeSignature: json['handshake_signature'],
      handshakeSignatureHex: json['handshake_signature_hex'],
      vendorId: json['vendor_id'],
      productId: json['product_id'],
    );
  }
}
