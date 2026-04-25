import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

// CONFIG
import 'package:kiosk_application/core/config/routes.dart';

// THEME
import 'package:kiosk_application/features/patient/patient_app_theme.dart';

// DATA LOGIC
import 'package:kiosk_application/features/auth/data/auth_repository.dart';
import 'package:kiosk_application/features/user_history/data/history_repository.dart';
import 'package:kiosk_application/core/providers/language_provider.dart';
import 'package:kiosk_application/features/patient/data/mobile_navigation_provider.dart';
import 'package:kiosk_application/features/chat/data/chat_repository.dart';
import 'package:kiosk_application/core/services/system/app_environment.dart';
import 'package:kiosk_application/core/services/system/initialization_service.dart';
import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/user_history/domain/i_history_repository.dart';
import 'package:kiosk_application/features/chat/domain/i_chat_repository.dart';
import 'package:kiosk_application/core/domain/i_system_repository.dart';
import 'package:kiosk_application/core/repositories/local_system_repository.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppEnvironment().setMode(AppMode.mobilePatient);

    // Centralized Initialization (Awaited for Mobile to ensure stable connections)
    await InitializationService().initialize(awaitDeferred: true);

    debugPrint("✅ [Bootstrap] Launching UI...");

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<IAuthRepository>(
              create: (_) => LocalAuthRepository()),
          ChangeNotifierProvider<IHistoryRepository>(
              create: (_) => LocalHistoryRepository()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
          ChangeNotifierProvider<IChatRepository>(
              create: (_) => LocalChatRepository()),
          Provider<ISystemRepository>(create: (_) => LocalSystemRepository()),
        ],
        child: const ResidentMobileApp(),
      ),
    );
  }, (error, stack) {
    debugPrint("❌ CRITICAL UNCAUGHT ERROR: $error");
    debugPrint(stack.toString());
  });
}

class ResidentMobileApp extends StatelessWidget {
  const ResidentMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Isla Verde Resident Companion',
      theme: PatientAppTheme.lightTheme,
      routerConfig: residentRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
