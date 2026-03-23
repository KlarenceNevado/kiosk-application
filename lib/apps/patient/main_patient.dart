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

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppEnvironment().setMode(AppMode.mobilePatient);

    // Centralized Initialization
    await InitializationService().initialize();

    debugPrint("✅ [Bootstrap] Launching UI...");

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
  }, (error, stack) {
    debugPrint("❌ CRITICAL UNCAUGHT ERROR: $error");
    debugPrint(stack.toString());
  });
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
