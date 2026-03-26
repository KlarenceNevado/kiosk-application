import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// CORE
import 'package:kiosk_application/core/config/routes.dart';
import 'package:kiosk_application/core/config/theme.dart';
import 'package:kiosk_application/core/errors/error_handler.dart';

import 'package:kiosk_application/core/services/system/app_environment.dart';
import 'package:kiosk_application/core/services/system/initialization_service.dart';
import 'package:kiosk_application/core/services/system/session_timer_service.dart';
import 'package:kiosk_application/core/services/hardware/sensor_manager.dart';

// FEATURES
import 'package:kiosk_application/features/auth/data/auth_repository.dart';
import 'package:kiosk_application/features/health_check/logic/health_wizard_provider.dart';
import 'package:kiosk_application/features/user_history/data/history_repository.dart';
import 'package:kiosk_application/features/admin/data/admin_repository.dart';
import 'package:kiosk_application/features/patient/data/mobile_navigation_provider.dart';
import 'package:kiosk_application/features/chat/data/chat_repository.dart';

import 'package:kiosk_application/core/providers/language_provider.dart';
import 'package:kiosk_application/l10n/app_localizations.dart';
import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/user_history/domain/i_history_repository.dart';
import 'package:kiosk_application/features/chat/domain/i_chat_repository.dart';
import 'package:kiosk_application/core/domain/i_system_repository.dart';
import 'package:kiosk_application/core/repositories/local_system_repository.dart';

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
        ChangeNotifierProvider<IAuthRepository>(create: (_) => LocalAuthRepository(), lazy: false),
        ChangeNotifierProvider<IHistoryRepository>(create: (_) => LocalHistoryRepository()),
        ChangeNotifierProvider(create: (_) => AdminRepository()..init()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
        ChangeNotifierProvider<IChatRepository>(create: (_) => LocalChatRepository()),
        Provider<ISystemRepository>(create: (_) => LocalSystemRepository()),
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
