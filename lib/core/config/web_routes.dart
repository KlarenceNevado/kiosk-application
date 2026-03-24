import 'package:go_router/go_router.dart';

// WEB-SAFE: Only Patient/Mobile screens — NO admin, NO kiosk, NO SyncService
import '../../features/mobile/screens/web_mobile_splash_screen.dart';
import '../../features/mobile/screens/web_mobile_login_screen.dart';
import '../../features/patient/screens/web_patient_nav_shell.dart';
import '../../features/patient/screens/web_patient_dashboard_screen.dart';

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
      builder: (context, state) => const WebMobileSplashScreen(),
    ),
    GoRoute(
      path: WebAppRoutes.patientLogin,
      builder: (context, state) => const WebMobileLoginScreen(),
    ),
    GoRoute(
      path: WebAppRoutes.patientHome,
      builder: (context, state) => const WebPatientNavShell(),
    ),
    GoRoute(
      path: WebAppRoutes.patientDashboard,
      builder: (context, state) => const WebPatientDashboardScreen(),
    ),
  ],
);
