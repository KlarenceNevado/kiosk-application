import 'package:flutter/material.dart';
// Added for RendererBinding
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:kiosk_application/core/services/system/app_environment.dart';

// ... existing imports ...
import 'package:kiosk_application/core/config/routes.dart';
import 'package:kiosk_application/core/config/theme.dart';
import 'package:kiosk_application/features/auth/data/auth_repository.dart';
import 'package:kiosk_application/features/user_history/data/history_repository.dart';
import 'package:kiosk_application/core/services/hardware/sensor_manager.dart';
import 'package:kiosk_application/features/health_check/logic/health_wizard_provider.dart';
import 'package:kiosk_application/features/admin/data/admin_repository.dart';
import 'package:kiosk_application/features/patient/data/mobile_navigation_provider.dart';
import 'package:kiosk_application/features/chat/data/chat_repository.dart';
import 'package:kiosk_application/core/providers/language_provider.dart';
import 'package:kiosk_application/core/services/system/initialization_service.dart';
import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/user_history/domain/i_history_repository.dart';
import 'package:kiosk_application/features/chat/domain/i_chat_repository.dart';

// Entry point for the Desktop Admin App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.desktopAdmin);

  // Centralized Initialization
  await InitializationService().initialize();

  runApp(
    // ExcludeSemantics at the absolute root is the most robust way to 
    // prevent Flutter from sending any UI updates to the Windows 
    // Accessibility Bridge (AXTree).
    ExcludeSemantics(
      child: MultiProvider(
        providers: [
          Provider(create: (_) => SensorManager()),
          ChangeNotifierProvider<IAuthRepository>(
              create: (_) => LocalAuthRepository(), lazy: false),
          ChangeNotifierProvider<IHistoryRepository>(
              create: (_) => LocalHistoryRepository()),
          ChangeNotifierProvider(create: (_) => AdminRepository()..init()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
          ChangeNotifierProvider<IChatRepository>(
              create: (_) => LocalChatRepository()),
          ChangeNotifierProvider(
            create: (context) => HealthWizardProvider(
              context.read<SensorManager>(),
            ),
          ),
        ],
        child: const AdminDesktopApp(),
      ),
    ),
  );
}

class AdminDesktopApp extends StatelessWidget {
  const AdminDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Admin Desktop',
      theme: AppTheme.lightTheme,
      // FIXED: Uses adminRouter to start at Admin Login
      routerConfig: adminRouter,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const FluidScrollBehavior(),
    );
  }
}

class FluidScrollBehavior extends MaterialScrollBehavior {
  const FluidScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
