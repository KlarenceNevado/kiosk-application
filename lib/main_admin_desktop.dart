import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'core/services/system/app_environment.dart';

// CONFIG
import 'core/config/routes.dart';
import 'core/config/theme.dart';

// DATA & LOGIC
import 'features/auth/data/auth_repository.dart';
import 'features/user_history/data/history_repository.dart';
import 'core/services/hardware/mock_sensor_service.dart';
import 'features/health_check/logic/health_wizard_provider.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/patient/data/mobile_navigation_provider.dart';
import 'features/chat/data/chat_repository.dart';

// REUSE LANGUAGE PROVIDER from Kiosk main
import 'main_kiosk.dart';

// Entry point for the Desktop Admin App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.desktopAdmin);

  // 0. Timezone Initialization
  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
  } catch (e) {
    debugPrint("⚠️ Timezone: $e");
  }

  // 1. Initialize Database for Windows/Linux
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. Initialize Supabase
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    debugPrint("⚠️ DotEnv: Could not load assets/.env file, attempting fallback: $e");
    try {
      await dotenv.load(fileName: ".env"); // Fallback check
    } catch (_) {
      debugPrint("❌ DotEnv: Fallback failed. Environment variables missing.");
    }
  }


  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // 3. Desktop Window Configuration
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(1024, 768),
      center: true,
      backgroundColor: Colors.white,
      skipTaskbar: false,
      title: "Isla Verde Admin Command Center",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepository()),
        ChangeNotifierProvider(create: (_) => HistoryRepository()),
        ChangeNotifierProvider(create: (_) => AdminRepository()..init()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
        ChangeNotifierProvider(create: (_) => ChatRepository()),
        Provider(create: (_) => MockSensorService()),
        ChangeNotifierProvider(
          create: (context) => HealthWizardProvider(
            context.read<MockSensorService>(),
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
