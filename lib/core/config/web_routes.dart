import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// WEB-SAFE: Only Patient/Mobile screens — NO admin, NO kiosk, NO SyncService
import '../../features/mobile/screens/mobile_splash_screen.dart';
import '../../features/mobile/screens/mobile_login_screen.dart';
import '../../features/patient/screens/resident_nav_shell.dart';
import '../../features/patient/screens/resident_dashboard_screen.dart';

class WebAppRoutes {
  static const String residentSplash = '/resident/splash';
  static const String residentLogin = '/resident/login';
  static const String residentHome = '/resident/home';
  static const String residentDashboard = '/resident/dashboard';
}

/// Web-only resident router. No Admin, Kiosk, or native screen imports.
/// Includes a redirect guard to prevent accessing protected routes without a session.
final GoRouter webResidentRouter = GoRouter(
  initialLocation: WebAppRoutes.residentSplash,
  redirect: (context, state) async {
    final protectedPaths = [
      WebAppRoutes.residentHome,
      WebAppRoutes.residentDashboard
    ];
    final isProtected = protectedPaths.contains(state.matchedLocation);

    if (isProtected) {
      final prefs = await SharedPreferences.getInstance();
      final hasSession =
          prefs.getString('pwa_session_user_id')?.isNotEmpty ?? false;
      if (!hasSession) {
        return WebAppRoutes.residentLogin;
      }
    }
    return null; // No redirect
  },
  routes: [
    GoRoute(
      path: WebAppRoutes.residentSplash,
      builder: (context, state) => const MobileSplashScreen(),
    ),
    GoRoute(
      path: WebAppRoutes.residentLogin,
      builder: (context, state) => const MobileLoginScreen(),
    ),
    GoRoute(
      path: WebAppRoutes.residentHome,
      builder: (context, state) => const ResidentNavShell(),
    ),
    GoRoute(
      path: WebAppRoutes.residentDashboard,
      builder: (context, state) => const ResidentDashboardScreen(),
    ),
  ],
);
