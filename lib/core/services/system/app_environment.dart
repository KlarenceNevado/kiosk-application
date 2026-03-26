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


  void setMode(AppMode mode) {
    _mode = mode;
  }

  void setSimulation(bool simulate) {
    _useSimulation = simulate;
  }

  AppMode get mode => _mode;
  bool get useSimulation => _useSimulation;

  bool get isKiosk => _mode == AppMode.kiosk;
  bool get isDesktopAdmin => _mode == AppMode.desktopAdmin;
  bool get isMobilePatient => _mode == AppMode.mobilePatient;

  // Logic for Virtual Keyboard:
  // Kiosk always needs it. Mobile Patient and Desktop Admin always use OS keyboard.
  bool get shouldShowVirtualKeyboard => _mode == AppMode.kiosk;

  // Logic for Hardware features:
  // Only Kiosk has physical sensors to calibrate. 
  // If useSimulation is true, we still show the UI but bypass real drivers.
  bool get hasHardwareAccess => _mode == AppMode.kiosk;
}

