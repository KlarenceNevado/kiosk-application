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
import '../system/system_log_service.dart';
import '../hardware/sensor_manager.dart';
import '../hardware/sensor_service_interface.dart';
import 'background_service_helper.dart';

import 'package:permission_handler/permission_handler.dart';

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

    // 3. Environment & Config
    await _initDotEnv();
    await ConfigService().loadSettings();

    // 4. Core Logic & Security Services
    ErrorHandler.init();
    await EncryptionService().init();

    // 5. Initialize Supabase (Offline-First Cloud Sync)
    await _initSupabase();

    // 6. Mode-specific Services
    if (AppEnvironment().isMobilePatient) {
       // Request OS permissions before initializing services
       await _requestAppPermissions();
       await _initNotifications();
       await BackgroundServiceHelper.initializeService();
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

    // 10. Initial Uptime & Health Log (H2 Validation)
    if (mode == AppMode.kiosk) {
      _logInitialHealth();
    }

    debugPrint("✅ [InitializationService] Initialization complete.");
  }

  /// Centralized permission request flow for Mobile Patient mode
  Future<void> _requestAppPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      debugPrint("🔐 [InitializationService] Checking OS Permissions...");
      
      // 1. Notifications (Android 13+)
      if (await Permission.notification.status.isDenied) {
        await Permission.notification.request();
      }

      // 2. IGNORE BATTERY OPTIMIZATIONS (Crucial for sync stability)
      if (Platform.isAndroid) {
        if (await Permission.ignoreBatteryOptimizations.status.isDenied) {
          debugPrint("⚡ [InitializationService] Requesting Battery Optimization Waiver...");
          // This will open the system dialog or settings page
          await Permission.ignoreBatteryOptimizations.request();
        }
      }

      debugPrint("✅ [InitializationService] Permission flow completed.");
    } catch (e) {
      debugPrint("⚠️ [InitializationService] Permission request error: $e");
    }
  }

  Future<void> _logInitialHealth() async {
    try {
      final sensorManager = SensorManager();
      // We wait a bit for sensors to report their initial status
      await Future.delayed(const Duration(seconds: 2));
      
      final sensors = {
        'Weight': sensorManager.getSensor(SensorType.weight).currentStatus.toString(),
        'Oximeter': sensorManager.getSensor(SensorType.oximeter).currentStatus.toString(),
        'Thermometer': sensorManager.getSensor(SensorType.thermometer).currentStatus.toString(),
        'BP': sensorManager.getSensor(SensorType.bloodPressure).currentStatus.toString(),
      };

      await SystemLogService().logUptimeHealth(
        availableSensors: sensors,
      );
    } catch (e) {
      debugPrint("⚠️ InitializationService (Health Log): $e");
    }
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
      // Prioritize --dart-define (injected during build) over .env file
      final supabaseUrl = const String.fromEnvironment('SUPABASE_URL').isNotEmpty 
          ? const String.fromEnvironment('SUPABASE_URL') 
          : dotenv.env['SUPABASE_URL'];
          
      final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty 
          ? const String.fromEnvironment('SUPABASE_ANON_KEY') 
          : dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseUrl.isEmpty || 
          supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
        throw Exception("Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env or --dart-define");
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
          minimumSize: Size(1280, 720),
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
