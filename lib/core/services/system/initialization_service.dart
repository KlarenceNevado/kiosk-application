import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app_environment.dart';
import 'config_service.dart';
import '../security/encryption_service.dart';
import '../security/notification_service.dart';
import '../database/sync_service.dart';
import '../../errors/error_handler.dart';
import '../database/connection_manager.dart';

class InitializationService {
  static final InitializationService _instance = InitializationService._internal();
  factory InitializationService() => _instance;
  InitializationService._internal();

  /// Comprehensive initialization for the application based on the current AppMode.
  Future<void> initialize() async {
    final mode = AppEnvironment().mode;
    debugPrint("🚀 [InitializationService] Initializing for mode: $mode");

    // 1. Timezone Initialization
    _initTimezone();

    // 2. Platform Specific Database Initialization
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _initDesktopDatabase();
    }

    // 3. Core Logic & Security Services
    ErrorHandler.init();
    await ConfigService().loadSettings();
    await EncryptionService().init();

    // 4. Load Environment Variables (.env)
    await _initDotEnv();

    // 5. Initialize Supabase (Offline-First Cloud Sync)
    await _initSupabase();

    // 6. Mode-specific Services
    if (AppEnvironment().isMobilePatient) {
       await _initNotifications();
    }

    // 7. UI Configuration
    _configureUI(mode);

    // 8. Desktop Window Configuration (Linux/Windows/macOS)
    if (AppEnvironment().isDesktopAdmin || AppEnvironment().mode == AppMode.kiosk) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _initDesktopWindow();
      }
    }

    // 9. Sync & Connectivity Services
    ConnectionManager().startMonitoring();
    if (!AppEnvironment().isDesktopAdmin) {
      SyncService().startSyncLoop();
    }

    debugPrint("✅ [InitializationService] Initialization complete.");
  }

  void _initTimezone() {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (e) {
      debugPrint("⚠️ InitializationService (Timezone): $e");
    }
  }

  void _initDesktopDatabase() {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint("⚠️ InitializationService (FFI Init): $e");
    }
  }

  Future<void> _initDotEnv() async {
    try {
      // Try primary asset path
      await dotenv.load(fileName: "assets/.env").timeout(const Duration(seconds: 3));
      debugPrint("✅ InitializationService: Loaded assets/.env");
    } catch (e) {
      debugPrint("📢 InitializationService: assets/.env failed, trying root .env...");
      try {
        await dotenv.load(fileName: ".env");
        debugPrint("✅ InitializationService: Loaded root .env");
      } catch (e2) {
        debugPrint("⚠️ InitializationService (DotEnv): Both load attempts failed. Using hardcoded fallbacks.");
      }
    }
  }

  Future<void> _initSupabase() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseUrl.isEmpty || 
          supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
        throw Exception("Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env");
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 5));
      debugPrint("✅ InitializationService: Supabase initialized");
    } catch (e) {
      debugPrint("❌ InitializationService (Supabase Critical): $e");
      // Re-throw or handle as fatal depending on app policy
      rethrow;
    }
  }

  Future<void> _initNotifications() async {
     try {
      await NotificationService().init();
      debugPrint("✅ InitializationService: Notifications initialized");
    } catch (e) {
      debugPrint("⚠️ InitializationService (Notifications): $e");
    }
  }

  void _configureUI(AppMode mode) {
    try {
      if (mode == AppMode.kiosk) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ));
      }
    } catch (e) {
      debugPrint("⚠️ InitializationService (UI Config): $e");
    }
  }

  Future<void> _initDesktopWindow() async {
     if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.ensureInitialized();

        WindowOptions windowOptions = const WindowOptions(
          size: Size(1280, 720),
          minimumSize: Size(1024, 768),
          center: true,
          backgroundColor: Colors.white,
          skipTaskbar: false,
          title: "Isla Verde Admin Command Center",
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
          // Full screen for Kiosk on Linux/Windows
          if (AppEnvironment().mode == AppMode.kiosk) {
             await windowManager.setFullScreen(true);
          } else {
             await windowManager.maximize();
          }
        });
      } catch (e) {
        debugPrint("⚠️ InitializationService (WindowManager): $e");
      }
    }
  }
}
