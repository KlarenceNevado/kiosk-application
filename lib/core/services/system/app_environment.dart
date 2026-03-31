import 'dart:io';
import 'package:flutter/foundation.dart';

enum AppMode {
  kiosk,
  desktopAdmin,
  mobilePatient,
}

class AppEnvironment {
  static final AppEnvironment _instance = AppEnvironment._internal();
  factory AppEnvironment() => _instance;
  AppEnvironment._internal();

  AppMode _mode = AppMode.kiosk; // Default
  bool _useSimulation = true; // Default to true so user can work without hardware
  String _pwaUrl = "https://islaverde.health"; // Default fallback
  String _deviceModel = "Unknown";
  String _adminExitPassword = "IslaVerde912"; // Default

  // Power Management & Battery Status (Added for Solar Eco-Mode)
  final ValueNotifier<bool> isEcoModeActive = ValueNotifier<bool>(false);
  final ValueNotifier<double> currentBrightness = ValueNotifier<double>(1.0); // 0.0 to 1.0
  final ValueNotifier<double> batteryLevel = ValueNotifier<double>(0.0); // 0.0 to 100.0

  Future<void> initialize() async {
    if (!kIsWeb && Platform.isLinux) {
      try {
        final file = File('/proc/device-tree/model');
        if (await file.exists()) {
          _deviceModel = (await file.readAsString()).replaceAll('\u0000', '').trim();
          debugPrint("📍 [AppEnvironment] Detected Device: $_deviceModel");
        }
      } catch (e) {
        _deviceModel = "Generic Linux";
      }
    } else if (kIsWeb) {
      _deviceModel = "Web Browser";
    } else {
      _deviceModel = Platform.operatingSystem;
    }
  }

  void setMode(AppMode mode) {
    _mode = mode;
  }

  void setPwaUrl(String url) {
    _pwaUrl = url;
  }

  void setSimulation(bool simulate) {
    _useSimulation = simulate;
  }

  AppMode get mode => _mode;
  bool get useSimulation => _useSimulation;
  String get pwaUrl => _pwaUrl;
  String get deviceModel => _deviceModel;
  String get adminExitPassword => _adminExitPassword;

  void setAdminExitPassword(String password) {
    _adminExitPassword = password;
  }

  bool get isKiosk => _mode == AppMode.kiosk;
  bool get isDesktopAdmin => _mode == AppMode.desktopAdmin;
  bool get isMobilePatient => _mode == AppMode.mobilePatient;

  // RPi Detection helper
  bool get isRaspberryPi => _deviceModel.toLowerCase().contains("raspberry pi");

  // Logic for Virtual Keyboard:
  // Kiosk always needs it. Mobile Patient and Desktop Admin always use OS keyboard.
  bool get shouldShowVirtualKeyboard => _mode == AppMode.kiosk;

  // Logic for Hardware features:
  // Only Kiosk has physical sensors to calibrate. 
  // If useSimulation is true, we still show the UI but bypass real drivers.
  bool get hasHardwareAccess => _mode == AppMode.kiosk;
}

