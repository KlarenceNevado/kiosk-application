import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// CORE
import 'core/config/routes.dart';
import 'core/config/theme.dart';
import 'core/errors/error_handler.dart';

import 'core/services/system/app_environment.dart';
import 'core/services/system/initialization_service.dart';
import 'core/services/system/session_timer_service.dart';
import 'core/services/hardware/sensor_manager.dart';

// FEATURES
import 'features/auth/data/auth_repository.dart';
import 'features/health_check/logic/health_wizard_provider.dart';
import 'features/user_history/data/history_repository.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/patient/data/mobile_navigation_provider.dart';
import 'features/chat/data/chat_repository.dart';

import 'core/providers/language_provider.dart';
import 'l10n/app_localizations.dart';

// FIXED: Renamed back to 'main()' so VS Code debugger can find it
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment().setMode(AppMode.kiosk);

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
