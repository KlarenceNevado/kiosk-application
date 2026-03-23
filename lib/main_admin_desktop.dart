import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'core/services/system/app_environment.dart';

// CONFIG
import 'core/config/routes.dart';
import 'core/config/theme.dart';

// DATA & LOGIC
import 'features/auth/data/auth_repository.dart';
import 'features/user_history/data/history_repository.dart';
import 'core/services/hardware/sensor_manager.dart';
import 'features/health_check/logic/health_wizard_provider.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/patient/data/mobile_navigation_provider.dart';
import 'features/chat/data/chat_repository.dart';

import 'core/providers/language_provider.dart';

import 'core/services/system/initialization_service.dart';

// Entry point for the Desktop Admin App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.desktopAdmin);

  // Centralized Initialization
  await InitializationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => SensorManager()),
        ChangeNotifierProvider(create: (_) => AuthRepository(), lazy: false),
        ChangeNotifierProvider(create: (_) => HistoryRepository()),
        ChangeNotifierProvider(create: (_) => AdminRepository()..init()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
        ChangeNotifierProvider(create: (_) => ChatRepository()),
        ChangeNotifierProvider(
          create: (context) => HealthWizardProvider(
            context.read<SensorManager>(),
          ),
        ),
      ],
      child: const AdminDesktopApp(),
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
