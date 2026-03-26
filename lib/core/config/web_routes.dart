import 'package:go_router/go_router.dart';

// WEB-SAFE: Only Patient/Mobile screens — NO admin, NO kiosk, NO SyncService
import '../../features/mobile/screens/mobile_splash_screen.dart';
import '../../features/mobile/screens/mobile_login_screen.dart';
import '../../features/patient/screens/patient_nav_shell.dart';
import '../../features/patient/screens/patient_dashboard_screen.dart';

class WebAppRoutes {
  static const String patientSplash = '/patient/splash';
  static const String patientLogin = '/patient/login';
  static const String patientHome = '/patient/home';
  static const String patientDashboard = '/patient/dashboard';
}

/// Web-only patient router. No Admin, Kiosk, or native screen imports.
final GoRouter webPatientRouter = GoRouter(
  initialLocation: WebAppRoutes.patientSplash,
  routes: [
    GoRoute(
      path: WebAppRoutes.patientSplash,
      builder: (context, state) => const MobileSplashScreen(),
    ),
    GoRoute(
      path: WebAppRoutes.patientLogin,
      builder: (context, state) => const MobileLoginScreen(),
    ),
    GoRoute(
      path: WebAppRoutes.patientHome,
      builder: (context, state) => const PatientNavShell(),
    ),
    GoRoute(
      path: WebAppRoutes.patientDashboard,
      builder: (context, state) => const PatientDashboardScreen(),
    ),
  ],
);
