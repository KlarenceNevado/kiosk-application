import 'package:go_router/go_router.dart';

// --- CORE SCREENS ---
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/mainmenu/screens/main_menu_screen.dart';

// --- HEALTH CHECK WIZARD ---
import '../../features/health_check/screens/health_check_wizard.dart';
import '../../features/health_check/screens/summary_screen.dart';

// --- INDIVIDUAL TESTS ---
import '../../features/health_check/screens/individual_tests/individual_tests_menu.dart';
import '../../features/health_check/screens/individual_tests/single_sensor_test_screen.dart';
import '../../features/health_check/screens/individual_tests/bmi_test_screen.dart';

// --- HISTORY & HELP ---
import '../../features/user_history/screens/history_list_screen.dart';
import '../../features/help/screens/help_info_screen.dart';
import '../../features/health_tips/screens/health_tips_screen.dart';

// --- ADMIN ---
import '../../features/admin/screens/admin_login_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/security_logs_screen.dart';
import '../../features/admin/screens/admin_user_management_screen.dart';
import '../../features/admin/screens/system_info_screen.dart';
import '../../features/admin/screens/admin_settings_screen.dart';

// --- PATIENT MOBILE APP ---
import '../../features/patient/screens/patient_dashboard_screen.dart';
import '../../features/patient/screens/patient_nav_shell.dart';
import '../../features/mobile/screens/mobile_login_screen.dart';
import '../../features/mobile/screens/mobile_splash_screen.dart';

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

  static const String patientLogin = '/patient/login';
  static const String patientDashboard = '/patient/dashboard';
  static const String patientHome = '/patient/home';
  static const String patientSplash = '/patient/splash';
}

// Shared Route List
List<GoRoute> _sharedRoutes = [
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: AppRoutes.register,
    builder: (context, state) {
      final isAdmin = state.uri.queryParameters['admin'] == 'true';
      return RegisterScreen(isAdmin: isAdmin);
    },
  ),
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => const MainMenuScreen(),
  ),
  GoRoute(
    path: AppRoutes.healthWizard,
    builder: (context, state) => const HealthCheckWizard(),
  ),
  GoRoute(
    path: AppRoutes.summary,
    builder: (context, state) => const SummaryScreen(),
  ),
  GoRoute(
    path: AppRoutes.individualTests,
    builder: (context, state) => const IndividualTestsMenu(),
  ),
  GoRoute(
    path: AppRoutes.testTemperature,
    builder: (context, state) =>
        const SingleSensorTestScreen(type: SensorType.temperature),
  ),
  GoRoute(
    path: AppRoutes.testBloodPressure,
    builder: (context, state) =>
        const SingleSensorTestScreen(type: SensorType.bloodPressure),
  ),
  GoRoute(
    path: AppRoutes.testHeartRate,
    builder: (context, state) =>
        const SingleSensorTestScreen(type: SensorType.heartRate),
  ),
  GoRoute(
    path: AppRoutes.testOxygen,
    builder: (context, state) =>
        const SingleSensorTestScreen(type: SensorType.oxygen),
  ),
  GoRoute(
    path: AppRoutes.testBmi,
    builder: (context, state) => const BmiTestScreen(),
  ),
  GoRoute(
    path: AppRoutes.history,
    builder: (context, state) => const HistoryListScreen(),
  ),
  GoRoute(
    path: AppRoutes.help,
    builder: (context, state) => const HelpInfoScreen(),
  ),
  GoRoute(
    path: AppRoutes.healthTips,
    builder: (context, state) => const HealthTipsScreen(),
  ),

  // ADMIN ROUTES
  GoRoute(
    path: AppRoutes.adminLogin,
    builder: (context, state) => const AdminLoginScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminDashboard,
    builder: (context, state) => const AdminDashboardScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminLogs,
    builder: (context, state) => const SecurityLogsScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminUsers,
    builder: (context, state) => const AdminUserManagementScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminSystemInfo,
    builder: (context, state) => const SystemInfoScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminSettings,
    builder: (context, state) => const AdminSettingsScreen(),
  ),

  // PATIENT MOBILE ROUTES
  GoRoute(
    path: AppRoutes.patientSplash,
    builder: (context, state) => const MobileSplashScreen(),
  ),
  GoRoute(
    path: AppRoutes.patientLogin,
    builder: (context, state) => const MobileLoginScreen(),
  ),
  GoRoute(
    path: AppRoutes.patientDashboard,
    builder: (context, state) => const PatientDashboardScreen(),
  ),
  GoRoute(
    path: AppRoutes.patientHome,
    builder: (context, state) => const PatientNavShell(),
  ),
];

// 1. KIOSK ROUTER (Starts at Patient Login)
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: _sharedRoutes,
);

// 2. ADMIN ROUTER (Starts at Admin Login)
final GoRouter adminRouter = GoRouter(
  initialLocation: AppRoutes.adminLogin,
  routes: _sharedRoutes,
);

// 3. PATIENT MOBILE ROUTER (Starts at Splash Screen)
final GoRouter patientRouter = GoRouter(
  initialLocation: AppRoutes.patientSplash,
  routes: _sharedRoutes,
);
