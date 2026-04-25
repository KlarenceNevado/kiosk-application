import 'dart:async';
import 'package:flutter/foundation.dart';
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
import '../hardware/models/hardware_config.dart';
import 'background_service_helper.dart';
import '../database/database_helper.dart';
import 'power_manager_service.dart';

import 'package:permission_handler/permission_handler.dart';
import 'log_manager_service.dart';
import '../hardware/hardware_watchdog_service.dart';

class InitializationService {
  static final InitializationService _instance =
      InitializationService._internal();
  factory InitializationService() => _instance;
  InitializationService._internal();

  /// PERFECTION: Split initialization into Fast/Critical and Slow/Deferred paths.
  /// This eliminates the 'White Screen' lag during fresh starts.

  /// Tier 1: Fast, local-only tasks that must happen before the first frame.
  Future<void> initializeCritical() async {
    final mode = AppEnvironment().mode;
    debugPrint(
        "🚀 [InitializationService] Tier 1: Critical Initialization ($mode)");

    // 1. Timezone (Instant)
    _initTimezone();

    // 2. Database Drivers (Instant)
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      _initDesktopDatabase();
    }

    // 3. Environment (Fast - Reduced timeout)
    await _initDotEnv(timeout: const Duration(seconds: 1));
    await HardwareConfig.load();
    await ConfigService().loadSettings();

    // 4. Security & Database Pre-Init (Ensures SQLite is ready for DAOs)
    ErrorHandler.init();
    await EncryptionService().init();
    await DatabaseHelper.instance.database; // Trigger non-blocking init/migration
    await LogManagerService().initialize();

    // 5. Diagnostics & Maintenance
    LogManagerService().startLogMaintenance();
    if (AppEnvironment().hasHardwareAccess) {
      HardwareWatchdogService().start();
    }

    // 6. Minimal UI Config (Colors/Layout)
    _configureUI(mode);

    debugPrint("⚡ [InitializationService] Tier 1 Complete.");
  }

  /// Tier 2: Heavy network, hardware, and windowing tasks that run in the background.
  Future<void> initializeDeferred() async {
    final mode = AppEnvironment().mode;
    debugPrint(
        "🔄 [InitializationService] Tier 2: Deferred Initialization Starting...");

    // 1. Firebase (Network dependent)
    _initFirebaseAsync();

    // 2. Supabase (Slow - Network dependent)
    // We await this in Tier 2 so that SyncService doesn't crash on uninitialized client
    try {
      await _initSupabase();
    } catch (e) {
      debugPrint("⚠️ [InitializationService] Supabase Initialization failed: $e");
    }

    // 3. Window Configuration (Hardware dependent)
    if (AppEnvironment().isDesktopAdmin ||
        AppEnvironment().mode == AppMode.kiosk) {
      _initDesktopWindowAsync();
    }

    // 4. Mode-specific Services
    if (AppEnvironment().isMobilePatient) {
      _initMobilePatientAsync();
    }

    // 5. Monitoring & Logs
    ConnectionManager().startMonitoring();
    SyncService().startSyncLoop();

    if (mode == AppMode.kiosk) {
      PowerManagerService().startMonitoring();
      // Deferred health log so it doesn't block startup
      Future.delayed(const Duration(seconds: 3), () => _logInitialHealth());
    }

    debugPrint("✅ [InitializationService] Tier 2 Dispatched.");
  }

  /// Legacy compatibility wrapper
  Future<void> initialize({bool awaitDeferred = false}) async {
    await initializeCritical();
    if (awaitDeferred) {
      await initializeDeferred();
    } else {
      unawaited(initializeDeferred());
    }
  }

  /// Non-blocking Firebase initialization
  void _initFirebaseAsync() {
    unawaited(() async {
      try {
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)) {
          await Firebase.initializeApp();
          FirebaseMessaging.onBackgroundMessage(
              _firebaseMessagingBackgroundHandler);
          debugPrint("🔥 [InitializationService] Firebase Initialized.");
        }
      } catch (e) {
        debugPrint("⚠️ [InitializationService] Firebase Init Error: $e");
      }
    }());
  }

  /// Non-blocking Desktop Window configuration
  void _initDesktopWindowAsync() {
    unawaited(_initDesktopWindow().catchError((e) {
      debugPrint("⚠️ [InitializationService] Deferred Window Error: $e");
    }));
  }

  /// Non-blocking Mobile Patient setup
  void _initMobilePatientAsync() {
    unawaited(() async {
      try {
        if (!DatabaseHelper.isBackground) {
          await _requestAppPermissions();
          await _initNotifications();
          await BackgroundServiceHelper.initializeService();
          FlutterBackgroundService().invoke('set_ui_active', {'active': true});
        }
      } catch (e) {
        debugPrint("⚠️ [InitializationService] Deferred Mobile Error: $e");
      }
    }());
  }

  /// Centralized permission request flow for Mobile Patient mode
  Future<void> _requestAppPermissions() async {
    if (kIsWeb) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      if (await Permission.notification.status.isDenied) {
        await Permission.notification.request();
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (await Permission.ignoreBatteryOptimizations.status.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }
    } catch (e) {
      debugPrint("⚠️ [InitializationService] Permission request error: $e");
    }
  }

  Future<void> _logInitialHealth() async {
    try {
      final sensorManager = SensorManager();
      await Future.delayed(const Duration(seconds: 2));

      final sensors = {
        'Weight':
            sensorManager.getSensor(SensorType.weight).currentStatus.toString(),
        'Oximeter': sensorManager
            .getSensor(SensorType.oximeter)
            .currentStatus
            .toString(),
        'Thermometer': sensorManager
            .getSensor(SensorType.thermometer)
            .currentStatus
            .toString(),
        'BP': sensorManager
            .getSensor(SensorType.bloodPressure)
            .currentStatus
            .toString(),
      };

      await SystemLogService().logUptimeHealth(availableSensors: sensors);
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

  Future<void> _initDotEnv(
      {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      await dotenv.load(fileName: "assets/.env").timeout(timeout);
      debugPrint("✅ InitializationService: Loaded assets/.env");
    } catch (e) {
      try {
        await dotenv.load(fileName: ".env");
        debugPrint("✅ InitializationService: Loaded root .env");
      } catch (_) {}
    }

    final pwaUrl = dotenv.env['PWA_URL'];
    if (pwaUrl != null && pwaUrl.isNotEmpty) {
      AppEnvironment().setPwaUrl(pwaUrl);
    }

    final currentMode = AppEnvironment().mode;
    final modeStr = dotenv.env['APP_MODE']?.toLowerCase();

    if (currentMode == AppMode.kiosk && modeStr != null) {
      if (modeStr == 'admin') {
        AppEnvironment().setMode(AppMode.desktopAdmin);
      } else if (modeStr == 'patient') {
        AppEnvironment().setMode(AppMode.mobilePatient);
      }
    }

    final simStr = dotenv.env['USE_SIMULATION']?.toLowerCase();
    if (simStr != null) {
      AppEnvironment().setSimulation(simStr == 'true');
    }

    final exitPass = dotenv.env['ADMIN_EXIT_PASSWORD'];
    if (exitPass != null) {
      AppEnvironment().setAdminExitPassword(exitPass);
    }
  }

  Future<void> _initSupabase() async {
    try {
      final supabaseUrl =
          const String.fromEnvironment('SUPABASE_URL').isNotEmpty
              ? const String.fromEnvironment('SUPABASE_URL')
              : dotenv.env['SUPABASE_URL'];

      final supabaseAnonKey =
          const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty
              ? const String.fromEnvironment('SUPABASE_ANON_KEY')
              : dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) return;

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey)
          .timeout(const Duration(seconds: 5));

      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        try {
          await client.auth
              .signInAnonymously()
              .timeout(const Duration(seconds: 15));
          debugPrint(
              "✅ [InitializationService] Supabase: Anonymous session established");
        } catch (e) {
          debugPrint("⚠️ [InitializationService] Supabase Auth Error: $e");
        }
      }
    } catch (e) {
      debugPrint("❌ InitializationService (Supabase Critical): $e");
    }
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint("⚠️ InitializationService (Notifications): $e");
    }
  }

  void _configureUI(AppMode mode) {
    try {
      if (mode == AppMode.kiosk) {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS)) {
          SystemChannels.mouseCursor
              .invokeMethod('setCursor', {'kind': 'none'});
        }
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (_) {}
  }

  Future<void> _initDesktopWindow() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        await windowManager.ensureInitialized();
        final isKiosk = AppEnvironment().mode == AppMode.kiosk;

        WindowOptions windowOptions = WindowOptions(
          size: const Size(1280, 720),
          minimumSize: const Size(1280, 720),
          center: true,
          backgroundColor: Colors.white,
          skipTaskbar: isKiosk,
          title:
              isKiosk ? "Isla Verde Kiosk" : "Isla Verde Admin Command Center",
          titleBarStyle: isKiosk ? TitleBarStyle.hidden : TitleBarStyle.normal,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
          if (isKiosk) {
            await windowManager.setFullScreen(true);
            await windowManager.setAlwaysOnTop(true);
            await windowManager.setResizable(false);
            await windowManager.setClosable(false);
          }
        });
      } catch (e) {
        debugPrint("⚠️ [InitializationService] WindowManager Error: $e");
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final String? type = data['type'];

  if (type == 'chat' || type == 'alert' || type == 'system_alert') {
    String? body = data['body'] ?? message.notification?.body;
    final notificationService = NotificationService();
    await notificationService.init(showPermissionRequest: false);
    await notificationService.showInstantNotification(
        id: message.hashCode,
        title: data['title'] ?? "Alert",
        body: body ?? "");
  }
}
