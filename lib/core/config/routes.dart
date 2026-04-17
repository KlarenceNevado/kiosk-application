import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// --- CORE SCREENS ---
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/mainmenu/screens/main_menu_screen.dart';

// --- HEALTH CHECK WIZARD ---
import '../../features/health_check/screens/health_check_wizard.dart';
import '../../features/health_check/screens/summary_screen.dart';

// --- INDIVIDUAL TESTS ---
import '../../features/health_check/screens/individual_tests/individual_tests_menu.dart';
import 'package:kiosk_application/features/health_check/screens/individual_tests/single_sensor_test_screen.dart';
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
import '../../features/admin/screens/admin_diagnostics_screen.dart';
import '../../features/health_check/screens/hardware_diagnostic_screen.dart';


// --- PATIENT MOBILE APP ---
import '../../features/patient/screens/patient_dashboard_screen.dart';
import '../../features/patient/screens/patient_nav_shell.dart';
import '../../features/mobile/screens/mobile_login_screen.dart';
import '../../features/mobile/screens/mobile_splash_screen.dart';
import '../../features/health_check/screens/public_results_screen.dart';

import 'route_names.dart';
export 'route_names.dart';

// Shared Route List with Fluid Transitions
List<GoRoute> _sharedRoutes = [
  _fluidRoute(AppRoutes.login, const LoginScreen()),
  _fluidRoute(AppRoutes.register, (context, state) {
    final isAdmin = state.uri.queryParameters['admin'] == 'true';
    return RegisterScreen(isAdmin: isAdmin);
  }),
  _fluidRoute(AppRoutes.home, const MainMenuScreen()),
  _fluidRoute(AppRoutes.healthWizard, const HealthCheckWizard()),
  _fluidRoute(AppRoutes.summary, const SummaryScreen()),
  _fluidRoute(AppRoutes.individualTests, const IndividualTestsMenu()),
  _fluidRoute(AppRoutes.testTemperature,
      const SingleSensorTestScreen(type: TestSensorType.temperature)),
  _fluidRoute(AppRoutes.testBloodPressure,
      const SingleSensorTestScreen(type: TestSensorType.bloodPressure)),
  _fluidRoute(AppRoutes.testHeartRate,
      const SingleSensorTestScreen(type: TestSensorType.heartRate)),
  _fluidRoute(AppRoutes.testOxygen,
      const SingleSensorTestScreen(type: TestSensorType.oxygen)),
  _fluidRoute(AppRoutes.testBmi, const BmiTestScreen()),
  _fluidRoute(AppRoutes.history, const HistoryListScreen()),
  _fluidRoute(AppRoutes.help, const HelpInfoScreen()),
  _fluidRoute(AppRoutes.healthTips, const HealthTipsScreen()),
  _fluidRoute(AppRoutes.adminLogin, const AdminLoginScreen()),
  _fluidRoute(AppRoutes.adminDashboard, const AdminDashboardScreen()),
  _fluidRoute(AppRoutes.adminLogs, const SecurityLogsScreen()),
  _fluidRoute(AppRoutes.adminUsers, const AdminUserManagementScreen()),
  _fluidRoute(AppRoutes.adminSystemInfo, const SystemInfoScreen()),
  _fluidRoute(AppRoutes.adminSettings, const AdminSettingsScreen()),
  _fluidRoute(AppRoutes.adminDiagnostics, const AdminDiagnosticsScreen()),
  _fluidRoute(AppRoutes.adminHardware, const HardwareDiagnosticScreen()),

  _fluidRoute(AppRoutes.patientSplash, const MobileSplashScreen()),
  _fluidRoute(AppRoutes.patientLogin, const MobileLoginScreen()),
  _fluidRoute(AppRoutes.patientDashboard, const PatientDashboardScreen()),
  _fluidRoute(AppRoutes.patientHome, const PatientNavShell()),
  _fluidRoute(AppRoutes.publicResult, (context, state) {
    final id = state.pathParameters['id'] ?? '';
    return PublicResultsScreen(recordId: id);
  }),
];

/// Helper for high-end fluid page transitions
GoRoute _fluidRoute(String path, dynamic builderOrWidget) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) {
      final widget = builderOrWidget is Widget
          ? builderOrWidget
          : (builderOrWidget as Widget Function(BuildContext, GoRouterState))(
              context, state);

      return CustomTransitionPage(
        key: state.pageKey,
        child: widget,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCirc,
              )),
              child: child,
            ),
          );
        },
      );
    },
  );
}

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
