import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// CONFIG
import 'core/config/routes.dart';

// THEME
import 'features/patient/patient_app_theme.dart';

// DATA LOGIC
import 'features/auth/data/auth_repository.dart';
import 'features/user_history/data/history_repository.dart';
import 'main_kiosk.dart';
import 'core/services/security/notification_service.dart';
import 'features/patient/data/mobile_navigation_provider.dart';
import 'features/chat/data/chat_repository.dart';
import 'core/services/database/sync_service.dart';
import 'core/services/system/app_environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.mobilePatient);

  // Ensure the OS keyboard is not suppressed and UI is edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 0. Timezone Initialization
  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));
  } catch (e) {
    debugPrint("⚠️ Timezone: $e");
  }

  // Initialize Supabase Connection
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Local Notifications Service
  await NotificationService().init();

  // Start Global Sync Loop (Announcements, Alerts, Vitals)
  SyncService().startSyncLoop();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthRepository()),
        ChangeNotifierProvider(create: (_) => HistoryRepository()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
        ChangeNotifierProvider(create: (_) => ChatRepository()),
      ],
      child: const PatientMobileApp(),
    ),
  );
}

class PatientMobileApp extends StatelessWidget {
  const PatientMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Isla Verde Patient Companion',
      theme: PatientAppTheme.lightTheme,
      routerConfig: patientRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
