import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// CORE
import 'core/config/routes.dart';
import 'core/config/theme.dart';
import 'core/errors/error_handler.dart';

// SERVICES
import 'core/services/hardware/mock_sensor_service.dart';
import 'core/services/system/session_timer_service.dart';
import 'core/services/database/sync_service.dart';
import 'core/services/system/config_service.dart';
import 'core/services/security/encryption_service.dart';
import 'core/services/system/app_environment.dart';

// FEATURES
import 'features/auth/data/auth_repository.dart';
import 'features/health_check/logic/health_wizard_provider.dart';
import 'features/user_history/data/history_repository.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/patient/data/mobile_navigation_provider.dart';
import 'features/chat/data/chat_repository.dart';

// STATE
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void toggleLanguage() {
    _locale =
        _locale.languageCode == 'en' ? const Locale('fil') : const Locale('en');
    notifyListeners();
  }
}

// FIXED: Renamed back to 'main()' so VS Code debugger can find it
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.kiosk);

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

// 2. Initialize System Services
  ErrorHandler.init();
  await ConfigService().loadSettings();
  await EncryptionService().init();

  // 3. Initialize Supabase (Offline-First Cloud Sync)
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    debugPrint("⚠️ DotEnv: Could not load .env file: $e");
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );


  SyncService().startSyncLoop();

  // 3. Kiosk UI Lockdown
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => MockSensorService()),
        ChangeNotifierProvider(create: (_) => AuthRepository()),
        ChangeNotifierProvider(create: (_) => HistoryRepository()),
        ChangeNotifierProvider(create: (_) => AdminRepository()..init()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
        ChangeNotifierProvider(create: (_) => ChatRepository()),
        ChangeNotifierProvider(
          create: (context) => HealthWizardProvider(
            context.read<MockSensorService>(),
          ),
        ),
      ],
      child: const KioskApp(),
    ),
  );
}

class KioskApp extends StatelessWidget {
  const KioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LanguageProvider>().locale;

    return MaterialApp.router(
      title: 'Kiosk Application',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fil'),
      ],
      builder: (context, child) {
        ErrorWidget.builder = ErrorHandler.errorWidgetBuilder;
        return SessionTimeoutManager(
          duration: const Duration(minutes: 2),
          child: child,
        );
      },
    );
  }
}
