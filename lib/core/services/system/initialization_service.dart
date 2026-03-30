import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
import '../database/database_helper.dart';

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

    // 4. Initialize Firebase (Real OS-Level Push)
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        debugPrint("🔥 [InitializationService] Firebase Initialized.");
      }
    } catch (e) {
      debugPrint("⚠️ [InitializationService] Firebase Init Error: $e");
    }

    // 5. Core Logic & Security Services
    ErrorHandler.init();
    await EncryptionService().init();

    // 5. Initialize Supabase (Offline-First Cloud Sync)
    try {
      await _initSupabase().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("⚠️ [InitializationService] Supabase Initialization Failed/Timed Out: $e");
      // We continue anyway so the app can run in offline mode.
    }

    // 6. Mode-specific Services (Resilient Startup)
    if (AppEnvironment().isMobilePatient) {
       // CRITICAL: Skip UI/Foreground-only services if running in a background isolate
       if (DatabaseHelper.isBackground) {
         debugPrint("📢 [InitializationService] Isolate write-mode: SUPPRESSED (Background Mode).");
       } else {
         debugPrint("📦 [InitializationService] Phase: Mobile Patient Setup (Main Isolate)");
         try {
           // 6.1. Permissions (Requires UI Thread)
           await _requestAppPermissions();
           
           // 6.2. Notifications (Requires UI Thread)
           await _initNotifications();

           // 6.3. Background service (Must only be initialized from Main Isolate)
           await BackgroundServiceHelper.initializeService();
           FlutterBackgroundService().invoke('set_ui_active', {'active': true});
         } catch (e) {
           debugPrint("⚠️ [InitializationService] Mobile Setup Error: $e");
         }
       }
    } else {
       debugPrint("📦 [InitializationService] Phase: Hardware/Kiosk Setup (Skipping Background Service)");
    }

    // 7. UI Configuration
    try {
      _configureUI(mode);
    } catch (e) {
      debugPrint("⚠️ [InitializationService] UI Configuration Error: $e");
    }

    // 8. Desktop Window Configuration (Linux/Windows/macOS)
    if (AppEnvironment().isDesktopAdmin || AppEnvironment().mode == AppMode.kiosk) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          debugPrint("🪟 [InitializationService] Configuring Desktop Window...");
          await _initDesktopWindow().timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint("⚠️ [InitializationService] Desktop Window Initialization Error/Timeout: $e");
        }
      }
    }

    // 9. Sync & Connectivity Services
    try {
      ConnectionManager().startMonitoring();
      if (!AppEnvironment().isDesktopAdmin) {
        SyncService().startSyncLoop();
      }
    } catch (e) {
      debugPrint("⚠️ [InitializationService] Sync Startup Error: $e");
    }

    // 10. Initial Uptime & Health Log (H2 Validation)
    if (mode == AppMode.kiosk) {
        try {
          _logInitialHealth();
        } catch (e) {
          debugPrint("⚠️ [InitializationService] Health Log Error: $e");
        }
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

    // Capture PWA URL from env or fallback
    final pwaUrl = dotenv.env['PWA_URL'];
    if (pwaUrl != null && pwaUrl.isNotEmpty) {
      AppEnvironment().setPwaUrl(pwaUrl);
      debugPrint("📢 InitializationService: PWA Domain set to $pwaUrl");
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

/// TOP LEVEL FUNCTION FOR FIREBASE BACKGROUND MESSAGES
/// Must be outside any class to work on Android terminated state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If we receive a message while terminated, this wakes the CPU.
  await Firebase.initializeApp();
  debugPrint("📩 [Firebase] Handling background message: ${message.messageId}");

  final data = message.data;
  final String? type = data['type'];
  
  if (type == 'chat' || type == 'alert' || type == 'system_alert') {
     // Decrypt if necessary
     String? body = data['body'] ?? message.notification?.body;
     if (body != null && body.contains(':')) {
       try {
         final encryption = EncryptionService();
         await encryption.init();
         body = encryption.decryptData(body);
       } catch (_) {}
     }

     if (body != null) {
       final notificationService = NotificationService();
       await notificationService.init(showPermissionRequest: false);
       
       if (type == 'chat') {
         await notificationService.showChatNotification(
           senderName: 'Health Worker',
           message: body,
         );
       } else if (type == 'system_alert') {
          await notificationService.showSystemAlertNotification(
            title: data['title'] ?? "System Alert",
            body: body,
          );
       } else {
          await notificationService.showInstantNotification(
            id: message.hashCode,
            title: data['title'] ?? "Alert",
             body: body,
          );
       }
     }
  }
}
