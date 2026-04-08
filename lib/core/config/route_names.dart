class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';

  static const String healthWizard = '/health-check';
  static const String summary = '/summary';

  static const String individualTests = '/tests';
  static const String testTemperature = '/tests/temp';
  static const String testBloodPressure = '/tests/bp';
  static const String testHeartRate = '/tests/hr';
  static const String testOxygen = '/tests/spo2';
  static const String testBmi = '/tests/bmi';

  static const String history = '/history';
  static const String help = '/help';
  static const String healthTips = '/health-tips';

  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminLogs = '/admin/logs';
  static const String adminUsers = '/admin/users';
  static const String adminSystemInfo = '/admin/info';
  static const String adminSettings = '/admin/settings';
  static const String adminDiagnostics = '/admin/diagnostics';

  static const String patientLogin = '/patient/login';
  static const String patientDashboard = '/patient/dashboard';
  static const String patientHome = '/patient/home';
  static const String patientSplash = '/patient/splash';
  static const String publicResult = '/results/:id';
}
