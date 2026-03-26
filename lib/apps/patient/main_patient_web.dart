import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

// CONFIG — Web-safe router (no Admin/Kiosk screen imports)
import 'package:kiosk_application/core/config/web_routes.dart';

// THEME
import 'package:kiosk_application/features/patient/patient_app_theme.dart';

// WEB-SAFE DATA LOGIC (No dart:io, No SQLite, No SyncService)
import 'package:kiosk_application/features/auth/data/web_auth_repository.dart';
import 'package:kiosk_application/features/user_history/data/web_history_repository.dart';
import 'package:kiosk_application/core/providers/language_provider.dart';
import 'package:kiosk_application/features/patient/data/mobile_navigation_provider.dart';
import 'package:kiosk_application/features/chat/data/web_chat_repository.dart';
import 'package:kiosk_application/core/services/system/app_environment.dart';
import 'package:kiosk_application/core/services/system/web_initialization_service.dart';

import 'package:kiosk_application/features/auth/domain/i_auth_repository.dart';
import 'package:kiosk_application/features/user_history/domain/i_history_repository.dart';
import 'package:kiosk_application/features/chat/domain/i_chat_repository.dart';
import 'package:kiosk_application/core/domain/i_system_repository.dart';
import 'package:kiosk_application/core/repositories/web_system_repository.dart';

/// Web PWA entry point for the Patient Mobile app.
/// Uses web-safe repositories and initialization to avoid all native dependencies.
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppEnvironment().setMode(AppMode.mobilePatient);

    // Web-safe initialization (no dart:io, no SQLite, no window_manager)
    await WebInitializationService().initialize();

    debugPrint("✅ [Bootstrap] Launching Patient PWA...");

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<IAuthRepository>(create: (_) => WebAuthRepository()),
          ChangeNotifierProvider<IHistoryRepository>(create: (_) => WebHistoryRepository()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
          ChangeNotifierProvider<IChatRepository>(create: (_) => WebChatRepository()),
          Provider<ISystemRepository>(create: (_) => WebSystemRepository()),
        ],
        child: const PatientWebApp(),
      ),
    );
  }, (error, stack) {
    debugPrint("❌ CRITICAL UNCAUGHT ERROR: $error");
    debugPrint(stack.toString());
  });
}

class PatientWebApp extends StatelessWidget {
  const PatientWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Isla Verde Patient Companion',
      theme: PatientAppTheme.lightTheme,
      routerConfig: webPatientRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
